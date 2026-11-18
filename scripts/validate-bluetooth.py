#!/usr/bin/env python3
"""Bluetooth acceptance in isolation. Never runs a live device mutation."""
from pathlib import Path
import os,re,shutil,subprocess,sys,tempfile
repo=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
out=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else repo/'docs/qa/bluetooth-20261025/isolated'
out.mkdir(parents=True,exist_ok=True)
def run(name,argv,env=None,seconds=30):
    result=subprocess.run(argv,env=env,capture_output=True,text=True,timeout=seconds)
    log=result.stdout+result.stderr;(out/(name+'.log')).write_text(log)
    if result.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Unable to assign|Binding loop|Traceback',log):raise SystemExit(log)
    print(name+': PASS')
env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',PYTHONDONTWRITEBYTECODE='1')
for key in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(key,None)
run('transactions',[sys.executable,'-B','-m','unittest','discover','-s',str(source/'tests'),'-p','test_bluetooth_model.py','-v'],env)
run('private-dbus',['dbus-run-session','--',sys.executable,'-B',str(source/'tests/test_bluetooth_dbus.py'),'-v'],env)
run('review',['/usr/lib/qt6/bin/qmltestrunner','-input',str(source/'tests/tst_BluetoothActions.qml')],env)
with tempfile.TemporaryDirectory(prefix='senomy-bt-ui-') as directory:
    work=Path(directory);shell=work/'shell/quickshell';shutil.copytree(source,shell,symlinks=True)
    for name in ['assets','appearance']:(work/name).symlink_to(source.parents[1]/name,target_is_directory=True)
    p=shell/'components/BluetoothPopup.qml';actual=p.read_text()
    actual=actual.replace('Interaction.QuickPopoverWindow {', 'FocusScope {',1).replace('    id:root', '''    id:root
    property var targetScreen:({width:1920,height:1080})
    property bool cardShown:true
    readonly property real presentationProgress:cardShown?1:0
    property bool requestedOpen:visible
    property var focusTarget
    property bool keyboardPriority
    function handleEscape(){dismissRequested();}
    function dismiss(){dismissRequested();}
    signal dismissRequested()''',1).replace('    color:"transparent"','    property color color:"transparent"')
    actual='\n'.join(line for line in actual.splitlines() if not line.strip().startswith('anchor.'))
    p.write_text(actual)
    shutil.copy2(source/'tests/fixtures/bluetooth-quality.qml',shell/'bluetooth-quality.qml')
    runtime=work/'runtime';runtime.mkdir(mode=0o700)
    local=dict(env,XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),SENOMY_QA_OUT=str(out))
    run('quality',['dbus-run-session','--','qs','--path',str(shell/'bluetooth-quality.qml'),'--no-color'],local)
run('lint',['/usr/lib/qt6/bin/qmllint','-I',str(source)]+[str(source/p) for p in ['services/BluetoothService.qml','services/BluetoothActions.qml','components/BluetoothPopup.qml','components/control/ControlDevicesPage.qml']]+[str(p) for p in (source/'components/bluetooth').glob('*.qml')],env)
