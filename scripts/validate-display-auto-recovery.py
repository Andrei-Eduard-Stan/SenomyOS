#!/usr/bin/env python3
"""Actual inventory coordinator, inert Python adapter, private IPC and D-Bus.

No compositor is started and no real device operation can reach an adapter.
"""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile

root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='sar-') as directory:
    base=Path(directory);shell=base/'shell';shutil.copytree(root/'shell/quickshell',shell,symlinks=True)
    bindir=base/'bin';bindir.mkdir();runtime=base/'r';runtime.mkdir(mode=0o700)
    adapter=bindir/'python3'
    adapter.write_text('#!'+sys.executable+'\n'+'''import json, os, sys
from pathlib import Path
base=Path(os.environ['SENOMY_RECOVERY_FIXTURE'])
script=Path(sys.argv[1]).name
count=int((base/'count').read_text()) if (base/'count').exists() else 0
if script=='device-inventory.py':
 m=dict(name='FIXTURE',key='fixture',number=1,internal=True,friendlyName='Fixture',width=1920,height=1080,refreshRate=60,scale=1,transform=0,x=0,y=0,disabled=False,mirrorOf='none',availableModes=['1920x1080@60.00Hz'])
 print(json.dumps(dict(displays=dict(available=True,items=[m]),inputs=dict(available=True,items=[]),policy=dict(workspaceMode='independent',workspaces={},primary='',rail={},autoRecovery=True),recovery=dict(enabled=True,needed=count<2,canAttempt=count<2,state='fallback-detected' if count<2 else 'healthy',message='Fixture health'),workspaces=[],windows=[],digest='fixture',transaction=dict(state='idle'))))
elif script=='display-action.py' and sys.argv[2]=='restore-policy':print(json.dumps(dict(ok=True,state='policy-restored')))
elif script=='display-action.py' and sys.argv[2]=='draft-save':print(json.dumps(dict(ok=True,state='draft-saved')))
elif script=='display-action.py' and sys.argv[2]=='auto-recover':
 (base/'count').write_text(str(count+1))
 print(json.dumps(dict(ok=True,state='recovery-observing' if count==0 else 'auto-recovered',message='observing fixture' if count==0 else 'fixture restored')))
else:
 print('Unexpected adapter operation blocked',file=sys.stderr);sys.exit(1)
''');adapter.chmod(0o755)
    fixture=shell/'auto-recovery-fixture.qml'
    fixture.write_text('''//@ pragma UseQApplication
import QtQuick
import Quickshell
import "services" as Services
ShellRoot {
 Services.DeviceInventory {id:inventory;active:false;actionContext:"fixture"}
 Component.onCompleted:inventory.displayActions.requestOperation("workspace",{},"Fixture pending review")
 Timer {interval:3000;running:true;onTriggered:{
   if(inventory.recoveryMessage!=="")throw new Error("Recovery ran during a pending review");
   inventory.draft.patch("fixture",{x:37});
   inventory.displayActions.cancel();inventory.refresh(true);
 }}
 Timer {interval:11000;running:true;onTriggered:{
   if(inventory.active||inventory.recoveryMessage!=="fixture restored"||!inventory.draft.dirty||inventory.draft.edits.fixture.x!==37||inventory.displayBusy)throw new Error("Closed-settings recovery or draft preservation failed");
   console.log("PASS actual inventory auto recovery pauses for review, runs while closed and preserves edits");Qt.quit();
 }}
}
''')
    env=dict(os.environ,PATH=str(bindir)+os.pathsep+os.environ.get('PATH',''),XDG_RUNTIME_DIR=str(runtime),
             XDG_CONFIG_HOME=str(base/'config'),XDG_STATE_HOME=str(base/'state'),
             HYPRLAND_INSTANCE_SIGNATURE='senomy-fixture-no-instance',SENOMY_RECOVERY_FIXTURE=str(base),
             QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
    env.pop('WAYLAND_DISPLAY',None);env.pop('DISPLAY',None)
    result=subprocess.run(['dbus-run-session','--','qs','--path',str(fixture),'--no-color'],env=env,capture_output=True,text=True,timeout=18)
    output=result.stdout+result.stderr
    if result.returncode or 'PASS actual inventory auto recovery' not in output:
        print(output);raise SystemExit(1)
    assert int((base/'count').read_text())==2,output
    print('PASS: actual inventory recovery coordinator; two fake adapter checks, no real compositor/device calls')
