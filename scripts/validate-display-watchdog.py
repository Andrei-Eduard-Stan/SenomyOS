#!/usr/bin/env python3
"""Real user-service watchdog lifetime test with an entirely fake compositor."""
import importlib.util
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
import time
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='sdw-') as directory:
    base=Path(directory);runtime=base/'r';state_dir=runtime/'senomyos';state_dir.mkdir(parents=True,mode=0o700)
    before=dict(name='FAKE-A',mode='1280x720@60',enabled=True,x=0,y=0,scale=1,transform=0,mirrorOf='')
    state=dict(state='preview',token='fixture',instance='fixture',deadline=int((time.time()+15)*1000),
               bootDeadline=time.clock_gettime(time.CLOCK_BOOTTIME)+15,before=[before],proposed=[dict(before,x=200)],workspaces=[])
    (state_dir/'display-change.json').write_text(json.dumps(state));(state_dir/'display-change.json').chmod(0o600)
    wrapper=base/'fake_watchdog.py'
    wrapper.write_text('''import importlib.util, json, os, sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('fixture_core',sys.argv[1]);c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
item=dict(name='FAKE-A',id=0,width=1280,height=720,refreshRate=60,x=200,y=0,scale=1,transform=0,disabled=False,dpmsStatus=True,mirrorOf='none')
def query(*args):
    if args[0]=='monitors':return [item]
    if args[0]=='workspaces':return []
    raise AssertionError(args)
def apply(out):
    item.update(x=out['x'],y=out['y'])
    (Path(os.environ['XDG_CONFIG_HOME'])/'restored.json').write_text(json.dumps(item))
c.query=query;c.apply_output=apply
c.subprocess.run=lambda *a,**k:(_ for _ in ()).throw(AssertionError('No real command allowed'))
c.watchdog('fixture')
''')
    args=['systemd-run','--user','--quiet','--collect','--property=Type=exec','--unit=senomy-display-watchdog-test-'+secrets.token_hex(4),
          '--setenv=XDG_RUNTIME_DIR='+str(runtime),'--setenv=XDG_CONFIG_HOME='+str(base),'--setenv=HYPRLAND_INSTANCE_SIGNATURE=fixture',
          sys.executable,str(wrapper),str(root/'shell/quickshell/scripts/display_core.py')]
    started=time.monotonic();subprocess.run(args,check=True,capture_output=True,text=True)
    print('Independent fixture recovery service armed; parent launch command exited.',flush=True)
    while time.monotonic()-started<21:
        final=json.loads((state_dir/'display-change.json').read_text())
        if final['state']=='reverted':break
        time.sleep(.1)
    assert final['state']=='reverted',final
    restored=json.loads((base/'restored.json').read_text());assert restored['x']==0
    print(json.dumps(dict(ok=True,elapsedSeconds=round(time.monotonic()-started,2),independentUserService=True,realCompositorCalls=0)))
