#!/usr/bin/env python3
"""Real user-manager supervision, using only a private dry-run dispatcher."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import time
import uuid

parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
fixture=args.root/'shell/quickshell/tests/fixtures/session-worker-dry-run.py'
spec=importlib.util.spec_from_file_location('session_worker_qa',fixture);adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
results=[]
for case in ('dispatch','cancel','unavailable'):
    with tempfile.TemporaryDirectory(prefix='senomy-private-worker-') as directory:
        rt=adapter.InertRuntime(directory);scheduler=adapter.engine.Scheduler(rt)
        review=scheduler.prepare({'action':'reboot','mode':'delay','seconds':'2'})['review'];plan=scheduler.commit(review['id'])['schedule']
        if case=='unavailable':time.sleep(3.2)
        unit='senomy-session-qa-'+uuid.uuid4().hex
        command=['systemd-run','--user','--quiet','--collect','--unit='+unit,'--property=Type=exec','--property=PartOf=graphical-session.target','/usr/bin/python3',str(fixture),directory,plan['id']]
        started=subprocess.run(command,capture_output=True,text=True,timeout=10)
        if started.returncode:raise SystemExit('Private worker supervision unavailable: '+started.stderr)
        if case=='cancel':scheduler.cancel(plan['id'])
        limit=time.monotonic()+10
        while time.monotonic()<limit and scheduler.state()['state']=='scheduled':time.sleep(.1)
        state=scheduler.state()['state'];ledger=rt.root/'dry-run-executions.jsonl';calls=[json.loads(line) for line in ledger.read_text().splitlines()] if ledger.exists() else []
        expected={'dispatch':'succeeded','cancel':'cancelled','unavailable':'missed'}[case]
        assert state==expected,(case,state)
        assert len(calls)==(1 if case=='dispatch' else 0),(case,calls)
        if calls:assert calls[0]['action']=='reboot' and calls[0]['command']==['/usr/bin/systemctl','reboot']
        # Wait for automatic worker exit, including cancellation and missed paths.
        limit=time.monotonic()+5
        while time.monotonic()<limit:
            active=subprocess.run(['systemctl','--user','is-active',unit+'.service'],capture_output=True,text=True)
            if active.returncode:break
            time.sleep(.1)
        assert active.returncode,'Private worker did not exit after its terminal receipt.'
        results.append({'case':case,'state':state,'dryRunCalls':len(calls),'supervisor':'systemd user transient service','unit':unit,'workerExited':True})
args.out.mkdir(parents=True,exist_ok=True);(args.out/'worker-systemd.json').write_text(json.dumps(results,indent=2)+'\n')
print('PASS: real systemd-supervised private worker dispatch (dry-run only), cancel and downtime/missed; all fixture services exited')
