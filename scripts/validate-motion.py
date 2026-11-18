#!/usr/bin/env python3
"""Exercise actual popup animations with a private, in-memory skin registry."""
from pathlib import Path
import os,re,subprocess,tempfile
from qa_remaining_hosts import prepare_hosts
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="senomy-motion-") as directory:
    temp=Path(directory);shell=prepare_hosts(root/"shell/quickshell",temp)
    source=(root/"shell/quickshell/tests/fixtures/remaining-popup.qml").read_text().split(" Timer {interval:500",1)[0]
    source+='''
 function setReduced(value){const registry=JSON.parse(JSON.stringify(Config.Skin.registry));registry.persona=Object.assign({},registry.persona || {},{reducedMotion:value});Config.Skin.registry=registry;}
 Timer {interval:500;running:true;onTriggered:{
  test.setReduced(false);input.wait(30);
  test.check(Config.Motion.openMs>0 && Config.Motion.closeMs>0,"ordinary motion keeps authored durations");
  test.route="volume";input.wait(250);const normal=view.item.children[0];view.item.cardShown=false;input.wait(200);view.item.cardShown=true;input.wait(10);
  test.check(normal.opacity<1,"actual popup animates in normal mode");input.wait(230);test.check(normal.opacity===1,"normal animation reaches final state");
  test.setReduced(true);input.wait(30);
  test.check(Config.Motion.openMs===0 && Config.Motion.closeMs===0 && Config.Motion.duration(170)===0,"reduced motion applies to open, close and workspace/hover policy");
  for(const route of ["volume","notifications","calendar","power","tray"]){
   test.route=route;input.wait(80);const card=view.item.children[0];
   view.item.cardShown=false;input.wait(5);test.check(card.opacity===0,"actual "+route+" closes without fade");
   view.item.cardShown=true;input.wait(5);test.check(card.opacity===1 && card.scale===1,"actual "+route+" opens immediately at final scale");
  }
  test.setReduced(false);input.wait(30);test.check(Config.Motion.openMs>0 && Config.Motion.duration(170)===170,"ordinary motion can be restored without saving preferences");
  test.check(test.mutations===0 && test.invocations===0,"motion fixture does not invoke provider actions");
  console.log("PASS: five actual popup bodies respect live reduced-motion policy, normal animation restores, no preferences saved or device actions");Qt.quit();
 }}
}
'''
    (shell/"motion-test.qml").write_text(source)
    runtime=temp/"runtime";runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software",XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/"config"),XDG_STATE_HOME=str(temp/"state"))
    for key in ["WAYLAND_DISPLAY","HYPRLAND_INSTANCE_SIGNATURE"]:env.pop(key,None)
    result=subprocess.run(["dbus-run-session","--","qs","--path",str(shell/"motion-test.qml"),"--no-color"],env=env,capture_output=True,text=True,timeout=12)
    log=result.stdout+result.stderr
    if result.returncode or re.search(r"FAIL:|ERROR|TypeError|ReferenceError|Binding loop",log):raise SystemExit(log)
    print(next(line for line in log.splitlines() if "PASS:" in line))
