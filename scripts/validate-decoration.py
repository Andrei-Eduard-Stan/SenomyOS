#!/usr/bin/env python3
"""Actual light-client lifetime and readability policy, private offscreen Qt only."""
from pathlib import Path
import os,re,shutil,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='senomy-decoration-') as directory:
    work=Path(directory);shell=work/'shell/quickshell';shutil.copytree(root/'shell/quickshell',shell)
    for name in ('appearance','assets'):(work/name).symlink_to(root/name,target_is_directory=True)
    (shell/'decoration-test.qml').write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "config" as Config
Window {
 id:test;visible:true;width:360;height:200
 TestCase{id:input;when:false}
 MetalSheen{id:sheen;width:300;height:50}
 QtObject{id:runner;property bool running:false;property int calls:0;property var argv:[];function exec(args){calls++;argv=args;}}
 ProviderSetupView{id:setup;runner:runner;provider:"idle";label:"idle support";width:350;y:60}
 function check(value,message){if(!value){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
 Timer{interval:300;running:true;onTriggered:{
  test.check(Config.ReflectionLight.activeClients===1 && Config.ReflectionLight.running,"visible decoration acquires one shared light");
  Config.ReflectionLight.onBattery=true;test.check(Config.ReflectionLight.tickMs===250,"battery uses four ticks per second");
  Config.ReflectionLight.onBattery=false;test.check(Config.ReflectionLight.tickMs===125,"external power uses eight ticks per second");
  test.check(setup.requestSetup() && runner.calls===0,"setup request only enters review");setup.pending=false;
  test.check(!setup.confirmSetup() && runner.calls===0,"cancelled setup cannot execute");
  setup.requestSetup();setup.visible=false;test.check(!setup.confirmSetup() && runner.calls===0,"hidden setup expires review");setup.visible=true;
  setup.requestSetup();setup.provider="unknown";test.check(!setup.confirmSetup() && runner.calls===0,"provider drift cancels review");setup.provider="idle";
  setup.requestSetup();test.check(setup.confirmSetup() && runner.calls===1,"confirmed setup hands off once");test.check(runner.argv[runner.argv.length-2]==="idle" && runner.argv[runner.argv.length-1]==="--confirmed","setup argv is fixed to the reviewed provider");
  const phase=Config.ReflectionLight.phase;input.wait(180);test.check(Config.ReflectionLight.phase!==phase,"visible light progresses");
  sheen.visible=false;input.wait(20);test.check(Config.ReflectionLight.activeClients===0 && !Config.ReflectionLight.running,"hidden decoration stops the clock");
  const frozen=Config.ReflectionLight.phase;input.wait(180);test.check(Config.ReflectionLight.phase===frozen,"no hidden phase updates");
  sheen.visible=true;input.wait(20);test.check(Config.ReflectionLight.activeClients===1,"showing re-acquires exactly once");
  Config.Skin.registry=Object.assign({},Config.Skin.registry,{persona:Object.assign({},Config.Skin.registry.persona,{reducedMotion:true,uiTextScale:1.5,highContrast:true})});
  input.wait(20);test.check(!Config.ReflectionLight.running && Config.ReflectionLight.activeClients===0,"reduced motion releases decorative clock");
  test.check(Config.DirectoryStyle.bodySize>=21 && Config.DirectoryStyle.highContrast,"large text and stronger contrast project without writing preferences");
  Config.Skin.registry=Object.assign({},Config.Skin.registry,{persona:Object.assign({},Config.Skin.registry.persona,{reducedMotion:false})});input.wait(20);
  test.check(Config.ReflectionLight.activeClients===1,"normal motion restores a single registration");
  test.visible=false;input.wait(20);test.check(Config.ReflectionLight.activeClients===0,"unmapped window releases clock even when child visible stays true");
  console.log("PASS: visible-only light lifetime, bounded battery cadence, reduced motion and large-text/contrast projection; no preference writes");Qt.quit();
 }}
}
''')
    runtime=work/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'))
    for key in ('WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE'):env.pop(key,None)
    r=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/'decoration-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=10)
    log=r.stdout+r.stderr
    if r.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign',log):raise SystemExit(log)
    print(next(line for line in log.splitlines() if 'PASS:' in line))
