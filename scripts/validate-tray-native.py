#!/usr/bin/env python3
"""Exercise actual SystemTray/QsMenuOpener against a private native menu server."""
import argparse,os,re,shutil,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='senomy-tray-native-') as temporary:
 work=Path(temporary);shell=work/'shell/quickshell';shutil.copytree(a.root/'shell/quickshell',shell,symlinks=True)
 for name in ['appearance','assets']:(work/name).symlink_to(a.root/name,target_is_directory=True)
 shutil.copy2(shell/'tests/fixtures/tray-native.qml',shell/'tray-native-test.qml')
 runtime=work/'runtime';runtime.mkdir(mode=0o700)
 env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',SENOMY_QA_OUT=str(a.out.resolve()))
 env.pop('WAYLAND_DISPLAY',None)
 python=Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))/'senomyos/calendar/runtime/bin/python'
 result=subprocess.run(['dbus-run-session','--',str(python),str(a.root/'components/calendar/tests/tray_native_scenario.py'),str(shell/'tray-native-test.qml')],env=env,capture_output=True,text=True,timeout=25)
 log=result.stdout+result.stderr;(a.out/'tray-native.log').write_text(log)
 if result.returncode or re.search(r'FAIL:|ERROR|ReferenceError|TypeError|Binding loop|Unable to assign',log) or 'PASS:' not in log:print(log);raise SystemExit(1)
 print('PASS: real private D-Bus tray root/submenus and action delivery')
