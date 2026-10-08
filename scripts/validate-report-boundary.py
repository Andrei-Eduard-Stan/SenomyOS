#!/usr/bin/env python3
"""Report profiles, redaction, deadlines and malformed private manifests."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
repo=Path(__file__).resolve().parents[1]
script=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'scripts/performance-report.sh'
with tempfile.TemporaryDirectory(prefix='senomy-reports-') as directory:
    root=Path(directory);reports=root/'reports';commands=root/'bin';commands.mkdir()
    for name in ['systemctl','uname','ip','upower','powerprofilesctl','free','df','lsblk','uptime','groups']:
        path=commands/name
        path.write_text('#!/usr/bin/env bash\nprintf "Fixture data\\nPASSWORD=must-be-redacted\\ncookie=must-be-redacted\\n"\n')
        path.chmod(0o755)
    env=dict(os.environ,PATH=str(commands)+os.pathsep+os.environ['PATH'],SENOMY_REPORT_ROOT=str(reports))
    def run(action,profile='overview',check=True):
        return subprocess.run(['bash',str(script),action,profile],env=env,capture_output=True,text=True,check=check,timeout=25)
    for profile in ['overview','performance','network','power','full']:
        payload=json.loads(run('generate-json',profile).stdout)
        assert payload['ok'] and payload['data']['exists']
        latest=payload['data']['latest'];path=Path(latest['path']);manifest=reports/('report-'+latest['id']+'.json')
        assert latest['profile']==profile and path.stat().st_mode&0o777==0o600 and manifest.stat().st_mode&0o777==0o600
        assert reports.stat().st_mode&0o777==0o700
        output=path.read_text();assert 'must-be-redacted' not in output and '[redacted potentially sensitive line]' in output
        assert json.loads(run('read-json').stdout)['ok']
        run('delete-latest',profile);assert not path.exists() and not manifest.exists()
    # A real timeout kills only this fixture's hung subprocess group.
    (commands/'systemctl').write_text('#!/usr/bin/env bash\n/bin/sleep 5\n')
    env['SENOMY_REPORT_TIMEOUT']='1'
    payload=json.loads(run('generate-json').stdout)
    assert 'failed or timed out' in Path(payload['data']['latest']['path']).read_text()
    # Escalation is restricted to the timeout-owned fixture subprocess group.
    (commands/'systemctl').write_text('#!/usr/bin/env bash\ntrap "" TERM\n/bin/sleep 30\n')
    started=time.monotonic()
    payload=json.loads(run('generate-json').stdout)
    assert time.monotonic()-started < 12, 'TERM-ignoring collector exceeded forced deadline'
    assert 'failed or timed out' in Path(payload['data']['latest']['path']).read_text()
    outside=root/'private.txt' ;outside.write_text('never expose fixture secret')
    latest=reports/'latest.json';saved=json.loads(latest.read_text())
    for mutate in ['outside','malformed','symlink','permissions','missing']:
        latest.write_text(json.dumps(saved));latest.chmod(0o600)
        report=Path(saved['path'])
        if report.is_symlink():report.unlink();report.write_text('safe restored fixture');report.chmod(0o600)
        if mutate=='outside':changed=dict(saved,path=str(outside));latest.write_text(json.dumps(changed))
        elif mutate=='malformed':latest.write_text('invalid JSON')
        elif mutate=='symlink':report.unlink();report.symlink_to(outside)
        elif mutate=='permissions':latest.chmod(0o644)
        elif mutate=='missing':changed=dict(saved,id='20000101-000000-overview',path=str(reports/'report-20000101-000000-overview.txt'));latest.write_text(json.dumps(changed))
        payload=json.loads(run('read-json').stdout)
        assert not payload['ok'] and not payload['data']['exists'] and not payload['data']['preview']
        assert 'never expose' not in json.dumps(payload)
        assert run('delete-latest',check=False).returncode!=0
        assert outside.read_text()=='never expose fixture secret'
    env['SENOMY_REPORT_TIMEOUT']='99';assert run('generate-json',check=False).returncode==2
print('PASS: five report profiles, private modes, redaction, collector timeout and invalid/outside/symlink manifest boundaries; fixture providers only')
