#!/usr/bin/env python3
"""Actual coordinator, Rail delegates and popup lifecycle with isolated input.

Only PopupWindow hosting and the native focus-grab transport are substituted.
QtTest sends real mouse/key events to the production Rail delegates. No system
providers, compositor commands, preference writers or notification owner run.
"""
from pathlib import Path
import os,re,shutil,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='senomy-interactions-') as directory:
    temp=Path(directory);shell=temp/'shell/quickshell';shutil.copytree(root/'shell/quickshell',shell)
    for name in ['assets','appearance']:(temp/name).symlink_to(root/name,target_is_directory=True)
    p=shell/'services/ShellState.qml';p.write_text(p.read_text().replace('import Quickshell','',1).replace('Scope {','QtObject {',1))
    runtime=temp/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/'config'),XDG_STATE_HOME=str(temp/'state'))
    for key in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(key,None)
    screens=subprocess.run(['dbus-run-session','--','/usr/lib/qt6/bin/qmltestrunner','-input',str(shell/'tests/tst_ScreenLifecycle.qml')],env=env,capture_output=True,text=True,timeout=5)
    if screens.returncode:raise SystemExit(screens.stdout+screens.stderr)
    print(next(line for line in screens.stdout.splitlines() if 'Totals:' in line))
    (shell/'popup-compile.qml').write_text('import QtQuick\nimport Quickshell\nimport "components"\nScope {SystemPopover {anchorItem:null;requestedOpen:false} Timer {interval:150;running:true;onTriggered:{console.log("PASS: native shared PopupWindow compiles without opening or providers");Qt.quit();}}}\n')
    compiled=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/'popup-compile.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=5)
    log=compiled.stdout+compiled.stderr
    if compiled.returncode or re.search(r'ERROR|TypeError|ReferenceError|Binding loop|Unable to assign',log):raise SystemExit(log)
    print(next(line for line in log.splitlines() if 'PASS:' in line))
    p=shell/'components/interaction/QuickPopoverWindow.qml';source=p.read_text().replace('PopupWindow {','FocusScope {\n    readonly property var contentItem: root',1).replace('    grabFocus: false','    property bool grabFocus: false').replace('    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Resize','    property var anchor: ({updateAnchor:function(){}})').replace('HyprlandFocusGrab {','TestFocusGrab {');source=re.sub(r'^    mask: Region.*\n','',source,flags=re.M)
    p.write_text(source)
    (shell/'components/interaction/TestFocusGrab.qml').write_text('''import QtQuick
QtObject {objectName:"test-focus-grab";property var windows:[];property bool active:false;property var initialWindows:[];onActiveChanged:if(active && !initialWindows.length)initialWindows=windows;signal cleared();function outside(){active=false;cleared();}}
''')
    shutil.copy2(shell/'tests/fixtures/interactions.qml',shell/'interaction-test.qml')
    result=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/'interaction-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=15)
    log=result.stdout+result.stderr
    if result.returncode or re.search(r'FAIL!|FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign',log):raise SystemExit(log)
    print(log)
