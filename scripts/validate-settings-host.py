#!/usr/bin/env python3
from pathlib import Path
import tempfile,shutil,os,subprocess,re
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='senomy-settings-native-') as d:
 temp=Path(d);shell=temp/'shell/quickshell';shutil.copytree(root/'shell/quickshell',shell)
 for n in ['assets','appearance']:(temp/n).symlink_to(root/n,target_is_directory=True)
 p=shell/'components/DashboardWindow.qml';s=p.read_text().replace('PanelWindow {','Window {',1).replace('    screen: targetScreen\n','').replace('    implicitWidth: fitted.width','    width: fitted.width').replace('    implicitHeight: fitted.height','    height: fitted.height').replace('    exclusiveZone: 0\n','').replace('    focusable: true\n','')
 a=s.index('    anchors {\n        left:');b=s.index('    onRequestedOpenChanged:',a);s=s[:a]+s[b:]
 p.write_text(s)
 f=shell/'settings-host-test.qml'
 f.write_text('''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
Scope {
    id:test
    property int closes:0
    TestCase {id:input;when:false}
    DashboardWindow {
        id:host;targetScreen:null;fullSettings:true;requestedOpen:true;title:"SENOMYOS SETTINGS"
        activeNode:"network/wifi"
        navigationNodes:[{id:"network",label:"NETWORK",route:"network",children:[{id:"network/wifi",label:"WI-FI",route:"network/wifi",children:[]}]}]
        onCloseRequested:{test.closes++;requestedOpen=false;}
        Text {id:content;text:"One shared page tree";color:"white";font.pixelSize:18}
    }
    function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
    Timer {interval:400;running:true;onTriggered:{
        const original=content;const nativeWindow=content.Window.window;
        test.check(host.navigation.selectedNode==="network/wifi","full Settings retains the current nested route in its shared tree");
        const width=host.contentArea.width;
        test.check(content.Window.window!==null,"page is in native toplevel");

        content.Window.window.width=640;content.Window.window.height=520;input.wait(200);test.check(host.nativeSettingsWindow.width===640 && host.contentArea.width>0 && host.contentArea.width!==width,"native resize reallocates content");
        host.captureItem.grabToImage(result=>result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/settings-native-640.png"));input.wait(150);
        host.fullSettings=false;input.wait(100);
        test.check(content===original,"mode switch retains shared page identity");
        test.check(content.Window.window!==nativeWindow,"compact mode owns same page");
        test.check(host.navigation.selectedNode==="network/wifi","compact navigation retains exact nested selection");
        host.fullSettings=true;input.wait(250);test.check(content===original,"returning full retains page identity");
        test.check(host.nativeSettingsWindow.width===640 && host.nativeSettingsWindow.height===520,"reopen retains user resized dimensions");
        host.nativeSettingsWindow.closed();input.wait(50);test.check(test.closes===1 && !host.requestedOpen,"native close follows shared state");
        console.log("PASS: actual FloatingWindow hosting, resize, shared page identity through both modes, native close");Qt.quit();
    }}
}
''')
 runtime=temp/'runtime';runtime.mkdir(mode=0o700)
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/'config'),XDG_STATE_HOME=str(temp/'state'),SENOMY_SOURCE_ROOT=str(root),SENOMY_QA_OUT=os.environ.get("SENOMY_QA_OUT",str(temp)))
 for k in ['HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY']:env.pop(k,None)
 r=subprocess.run(['dbus-run-session','--','qs','--path',str(f),'--no-color'],env=env,capture_output=True,text=True,timeout=5)
 log=r.stdout+r.stderr
 if r.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Cannot specify',log):raise SystemExit(log)
 print(next(line for line in log.splitlines() if 'PASS:' in line))
