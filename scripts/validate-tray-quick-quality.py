#!/usr/bin/env python3
"""Native tray composition and Qt input using inert status items on a private bus."""
from pathlib import Path
import os,re,shutil,subprocess,sys,tempfile
from qa_remaining_hosts import prepare_hosts
repo=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
out=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else repo/'docs/qa/tray-design-20261025/isolated'
out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='senomy-tray-quality-') as directory:
    work=Path(directory);shell=prepare_hosts(source,work)
    original=(source/'components/TrayPopup.qml').read_text()
    sizes='\n'.join(line for line in original.splitlines() if line.strip().startswith(('implicitWidth:','implicitHeight:')))
    host=shell/'components/TrayPopup.qml'
    host.write_text(host.read_text().replace('    FocusScope {\n        id: card',sizes+'\n    FocusScope {\n        id: card'))
    shutil.copy2(source/'tests/fixtures/tray-quick-quality.qml',shell/'tray-quality.qml')
    runtime=work/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_STATE_HOME=str(work/'state'),XDG_CONFIG_HOME=str(work/'config'),SENOMY_QA_OUT=str(out))
    for key in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(key,None)
    def run(path,logname):
        result=subprocess.run(['dbus-run-session','--','qs','--path',str(path),'--no-color'],env=env,capture_output=True,text=True,timeout=25)
        log=result.stdout+result.stderr;(out/logname).write_text(log)
        if result.returncode or re.search(r'FAIL:|ERROR|ReferenceError|TypeError|Binding loop|Unable to assign',log) or 'PASS:' not in log:raise SystemExit(log)
        print(next(line for line in log.splitlines() if 'PASS:' in line))
    run(shell/'tray-quality.qml','quality.log')
    native=work/'native/shell/quickshell';shutil.copytree(source,native)
    for name in ['assets','appearance']:(work/'native'/name).symlink_to(source.parents[1]/name,target_is_directory=True)
    (native/'tray-compile.qml').write_text('''import QtQuick
import Quickshell
import "components"
Scope { TrayPopup {anchorItem:null;requestedOpen:false} Timer {interval:150;running:true;onTriggered:{console.log("PASS: native TrayPopup compiles");Qt.quit();}} }
''')
    run(native/'tray-compile.qml','native-compile.log')
    shutil.copy2(source/'tests/fixtures/tray-quick-native.qml',shell/'tray-quick-native.qml')
    interpreter=Path(os.environ.get('SENOMY_TRAY_TEST_PYTHON',str(Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))/'senomyos/calendar/runtime/bin/python')))
    if not interpreter.is_file():raise SystemExit('Private D-Bus fixture requires Python with dbus-next; set SENOMY_TRAY_TEST_PYTHON. This is a test dependency only.')
    result=subprocess.run(['dbus-run-session','--',str(interpreter),str(source/'tests/fixtures/tray-quality-server.py'),str(shell/'tray-quick-native.qml')],env=env,capture_output=True,text=True,timeout=30)
    log=result.stdout+result.stderr;(out/'private-native.log').write_text(log)
    if result.returncode or re.search(r'FAIL:|ERROR|ReferenceError|TypeError|Binding loop|Unable to assign',log) or 'PASS:' not in log:raise SystemExit(log)
    print('PASS: private native status actions and three-level D-Bus menu delivery')
