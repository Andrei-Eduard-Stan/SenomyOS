#!/usr/bin/env python3
"""Actual Rail controls with fake live data: anchors survive status updates."""
from pathlib import Path
import os,re,shutil,subprocess,tempfile,sys
root=Path(__file__).resolve().parents[1]
reference=Path(sys.argv[1]) if len(sys.argv)>1 else None
with tempfile.TemporaryDirectory(prefix='senomy-control-anchors-') as directory:
    temp=Path(directory);shell=temp/'shell/quickshell';shutil.copytree(root/'shell/quickshell',shell)
    for name in ['assets','appearance']:(temp/name).symlink_to(root/name,target_is_directory=True)
    if reference:shutil.copy2(reference,shell/'components/SystemControlsIsland.qml')
    (shell/'anchor-test.qml').write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
Window {
 id:test;visible:true;width:420;height:100
 property int actions:0
 TestCase {id:input;when:false}
 QtObject {id:audio;property bool available:true;property bool muted:false;property real volume:0.3}
 QtObject {id:network;property bool available:true;property string connectivityName:"Full";property string detail:"Fixture network"}
 QtObject {id:battery;property bool available:true;property bool charging:false;property real percentage:0.6;property string detail:"Fixture battery"}
 SystemControlsIsland {id:bar;anchors.centerIn:parent;width:338;audio:audio;network:network;battery:battery;onToggleVolume:test.actions++;onOpenControl:section=>test.actions++}
 function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
 Timer {interval:100;running:true;onTriggered:{
  const before=bar.volumeAnchor;test.check(!!before,"audio anchor exists");
  network.detail="Updated signal";battery.detail="Updated charge";audio.volume=0.7;input.wait(70);
  const stable=bar.volumeAnchor===before;
  test.check(stable===EXPECTED_STABILITY,"live data must preserve anchor identity");
  if(EXPECTED_STABILITY){
   const audioButton=input.findChild(bar,"rail-control-audio");
   const tip=input.findChild(bar,"rail-tooltip-audio");test.check(tip && tip.status===Loader.Ready && tip.item.anchorItem===audioButton,"icon help loads with its stable owned anchor");
   test.check(!tip.item.visible && !tip.item.requested,"icon help does no work when idle");
   const networkTip=input.findChild(bar,"rail-tooltip-network");test.check(networkTip.item.text.includes("Updated signal"),"icon help follows provider state without replacing delegates");
   audioButton.forceActiveFocus();input.keyClick(Qt.Key_Space);input.wait(10);
   const controlButton=input.findChild(bar,"rail-control-control");controlButton.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(10);
   test.check(test.actions===2,"keyboard activates audio and dedicated Control Centre without system mutations");
  }
  console.log("PASS: ANCHOR_RESULT "+stable+"; fake providers and owned Qt only");Qt.quit();
 }}
}
'''.replace('EXPECTED_STABILITY','false' if reference else 'true'))
    runtime=temp/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/'config'),XDG_STATE_HOME=str(temp/'state'))
    for name in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(name,None)
    result=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/'anchor-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=8)
    log=result.stdout+result.stderr
    if result.returncode or re.search('FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Required property|Cannot assign',log):raise SystemExit(log)
    print(next(line for line in log.splitlines() if 'PASS:' in line))
