#!/usr/bin/env python3
"""Focused care acceptance with temporary files, private buses and inert writes."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--out',type=Path,required=True);a=p.parse_args();root=a.root.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True);results={}
with tempfile.TemporaryDirectory(prefix='senomy-care-qa-')as tmp:
 w=Path(tmp);shutil.copytree(root/'shell/quickshell',w/'shell/quickshell',ignore=shutil.ignore_patterns('__pycache__'));shutil.copytree(root/'components/power',w/'components/power')
 (w/'scripts').mkdir();shutil.copy2(root/'scripts/senomy-system-deploy.sh',w/'scripts/senomy-system-deploy.sh')
 for name in ('assets','appearance'):
  if (root/name).exists():(w/name).symlink_to(root/name,target_is_directory=True)
 (w/'runtime').mkdir(mode=0o700);(w/'fixture').mkdir()
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',PYTHONDONTWRITEBYTECODE='1',XDG_RUNTIME_DIR=str(w/'runtime'),XDG_CONFIG_HOME=str(w/'config'),XDG_STATE_HOME=str(w/'state'),SENOMY_PRIVATE_CARE_FIXTURE=str(w/'fixture'))
 for k in ('WAYLAND_DISPLAY','DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS','DBUS_SYSTEM_BUS_ADDRESS'):env.pop(k,None)
 shell=w/'shell/quickshell'
 commands=[('system-deployment',['python3','-B',str(shell/'tests/test_system_deploy.py')]),('care-backend',['python3','-B',str(shell/'tests/test_battery_care.py')]),('installed-tlp-lifecycle',['python3','-B',str(shell/'tests/test_tlp_lifecycle.py')]),('care-native',['dbus-run-session','--','qs','--path',str(shell/'battery-care-test.qml'),'--no-color']),('care-lint',['/usr/lib/qt6/bin/qmllint','-I',str(shell),str(shell/'services/BatteryCare.qml'),str(shell/'components/control/BatteryCareEditor.qml'),str(shell/'components/control/ControlPowerPage.qml')])]
 for name,argv in commands:
  r=subprocess.run(argv,capture_output=True,text=True,env=env,timeout=30);(out/(name+'.log')).write_text(r.stdout+r.stderr);results[name]={'exitCode':r.returncode}
  if r.returncode:raise SystemExit((out/(name+'.log')).read_text())
(out/'results.json').write_text(json.dumps({'isolated':True,'hardwareWrites':0,'phases':results},indent=2)+'\n');print('PASS: care validation/transactions/filesystem/provenance, installed TLP decision functions with inert I/O, native Process/review/readback/restore, narrow/wide keyboard UI and lint. No live mutations.')
