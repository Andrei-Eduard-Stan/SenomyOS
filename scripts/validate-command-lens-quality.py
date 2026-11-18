#!/usr/bin/env python3
"""Render and exercise actual Lens content using Qt input and fake activations.

Only the compositor host is replaced. Never starts a compositor or device action.
"""
from pathlib import Path
import os, re, shutil, subprocess, sys, tempfile, json
repo = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
out = Path(sys.argv[2]).resolve() if len(sys.argv)>2 else repo/'docs/qa/command-lens-20261023/isolated'
out.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='senomy-lens-quality-') as directory:
    work=Path(directory);shell=work/'shell/quickshell'
    shutil.copytree(source,shell,symlinks=True)
    for name in ['assets','appearance']:(work/name).symlink_to(source.parents[1]/name,target_is_directory=True)
    host=shell/'components/interaction/QuickPopoverWindow.qml'
    host.write_text('''import QtQuick
import Quickshell
Item {
 property var anchorItem:null
 property var targetScreen:null
 property var coordinator:null
 property bool requestedOpen:false
 property bool cardShown:true
 readonly property real presentationProgress:cardShown?1:0
 property string popupToken:""
 property var focusTarget:null
 property int openDuration:0
 property bool keyboardPriority:false
 property bool waitForFirstFrame:false
 property bool ownsEscape:true
 property color color:"transparent"
 property QtObject anchor:QtObject {
  property var item:null
  property int edges:0
  property int gravity:0
  property QtObject rect:QtObject {property real x:0;property real y:0;property real width:0;property real height:0}
 }
 signal dismissRequested()
 function dismiss(){if(coordinator)return coordinator.closePopups();dismissRequested();return true;}
 function handleEscape(){dismiss();}
}
''')
    popup=shell/'components/lens/CommandLensPopup.qml'
    popup.write_text('\n'.join(line for line in popup.read_text().split('\n') if not line.strip().startswith('anchor.')))
    shutil.copy2(source/'tests/fixtures/command-lens-quality.qml',shell/'command-lens-quality.qml')
    providers=work/'providers/components/launcher/rofi/scripts';providers.mkdir(parents=True)
    for name in ['senomy-rofi-files','senomy-rofi-actions']:
        helper=providers/name
        helper.write_text("#!/usr/bin/env python3\nimport os,time\nif os.environ.get('ROFI_RETV','0')=='0':\n time.sleep(.35)\n print('Fixture row\\0info\\x1f/tmp/fixture.txt'.encode().decode('unicode_escape'))\n")
        helper.chmod(0o755)
    usage=work/'state/senomyos/app-usage';usage.mkdir(parents=True)
    (usage/'history.json').write_text(json.dumps({'schemaVersion':1,'apps':{'firefox':{'count':9,'lastOpened':100},'files':{'count':2,'lastOpened':200}}}))
    runtime=work/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),SENOMY_QA_OUT=str(out),SENOMY_SOURCE_ROOT=str(work/'providers'))
    for key in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(key,None)
    result=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/'command-lens-quality.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=25)
    log=result.stdout+result.stderr;(out/'quality.log').write_text(log)
    if result.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Unable to assign|Binding loop',log) or 'PASS:' not in log:raise SystemExit(log)
    print(next(line for line in log.splitlines() if 'PASS:' in line))
