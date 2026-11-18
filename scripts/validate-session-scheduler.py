#!/usr/bin/env python3
"""Inert scheduling engine and production session UI; never arm real timers."""
from pathlib import Path
import argparse,os,re,shutil,subprocess,tempfile
from qa_remaining_hosts import prepare_hosts
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--out',type=Path,required=True);a=p.parse_args();root=a.root.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
unit=subprocess.run(['python3','-m','unittest','discover','-s',str(root/'shell/quickshell/tests'),'-p','test_session_scheduler.py','-v'],capture_output=True,text=True);(out/'backend.log').write_text(unit.stdout+unit.stderr)
if unit.returncode:raise SystemExit(unit.stdout+unit.stderr)
with tempfile.TemporaryDirectory(prefix='senomy-session-ui-qa-') as directory:
 work=Path(directory);shell=work/'shell/quickshell';shutil.copytree(root/'shell/quickshell',shell,symlinks=True)
 for name in ['assets','appearance']:(work/name).symlink_to(root/name,target_is_directory=True)
 shutil.copy2(shell/'tests/fixtures/session-quality.qml',shell/'session-quality.qml')
 runtime=work/'runtime';runtime.mkdir(mode=0o700)
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_STATE_HOME=str(work/'state'),XDG_CONFIG_HOME=str(work/'config'),SENOMY_QA_OUT=str(out))
 for key in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(key,None)
 def run(path,name,platform="offscreen"):
  phase_runtime=work/('runtime-'+Path(name).stem);phase_runtime.mkdir(mode=0o700)
  phase_env=dict(env,XDG_RUNTIME_DIR=str(phase_runtime),SENOMY_NOTIFICATION_STORE=str(phase_runtime/"notifications.json"),SENOMY_NOTIFICATION_OWNER="quickshell")
  if platform=="wayland":
   phase_env["QT_QPA_PLATFORM"]="wayland"
   phase_env["WAYLAND_DISPLAY"]=str(Path(os.environ["XDG_RUNTIME_DIR"])/os.environ["WAYLAND_DISPLAY"])
  result=subprocess.run(['dbus-run-session','--','qs','--path',str(path),'--no-color'],env=phase_env,capture_output=True,text=True,timeout=30);log=result.stdout+result.stderr;(out/name).write_text(log)
  if result.returncode or re.search(r'FAIL:|ERROR|ReferenceError|TypeError|Binding loop|Unable to assign|Cannot assign|WARN scene:.*Error:',log) or 'PASS:' not in log:raise SystemExit(log)
  print(next(line for line in log.splitlines() if 'PASS:' in line))
 run(shell/'session-quality.qml','ui.log')
 shutil.copy2(shell/'tests/fixtures/session-service.qml',shell/'session-service.qml')
 run(shell/'session-service.qml','service.log')
 (shell/'session-native-compile.qml').write_text('''import QtQuick
import Quickshell
import "components"
import "services"
Scope {
 PowerService {id:provider;helper:"/nonexistent/inert-scheduler"}
 NotificationService {id:notifications;sessionService:provider}
 PowerPopup {anchorItem:null;requestedOpen:false;powerService:provider}
 NotificationCenter {anchorItem:null;requestedOpen:false;notifications:notifications;clearContext:"test"}
 NotificationToast {targetScreen:null;notifications:notifications;placementEnabled:false}
 PowerIsland {powerService:provider}
 Timer {interval:250;running:true;onTriggered:{console.log("PASS: native PowerPopup and provider compile");Qt.quit();}}
}
''')
 run(shell/'session-native-compile.qml','native-compile.log',"wayland")
 hostroot=work/'host';hostroot.mkdir();host=prepare_hosts(root/'shell/quickshell',hostroot)
 original=(root/'shell/quickshell/components/PowerPopup.qml').read_text();sizes='\n'.join(line for line in original.splitlines() if line.strip().startswith(('implicitWidth:','implicitHeight:')))
 hostfile=host/'components/PowerPopup.qml';hostfile.write_text(hostfile.read_text().replace('    FocusScope {\n        id: card',sizes+'\n    FocusScope {\n        id: card'))
 shutil.copy2(host/'tests/fixtures/session-popup-quality.qml',host/'session-popup-quality.qml')
 run(host/'session-popup-quality.qml','popup.log')
 shutil.copy2(host/'tests/fixtures/session-surfaces-quality.qml',host/'session-surfaces-quality.qml')
 run(host/'session-surfaces-quality.qml','surfaces.log')
print('PASS: isolated scheduler and UI suite; no real timer or session mutation')
