#!/usr/bin/env python3
"""Additional current components, inert snapshots and offscreen hosts only."""
from pathlib import Path
import ast, json, re, shutil, tempfile
from capture import ROOT, SOURCE, ATLAS, prepared, run_qml, prefix


def copied(work):
    shell=work/'shell/quickshell';shutil.copytree(SOURCE,shell,symlinks=True)
    for name in ['appearance','assets']:(work/name).symlink_to(ROOT/name,target_is_directory=True)
    return shell


def lens():
 with tempfile.TemporaryDirectory(prefix='senomy-atlas-lens-') as d:
    work=Path(d);shell=copied(work)
    tree=ast.parse((ROOT/'scripts/validate-command-lens-quality.py').read_text())
    host=next(n.value for n in ast.walk(tree) if isinstance(n,ast.Constant) and isinstance(n.value,str) and n.value.startswith('import QtQuick\nimport Quickshell\nItem'))
    host=host.replace('property bool ownsEscape:true','property bool ownsEscape:true')
    (shell/'components/interaction/QuickPopoverWindow.qml').write_text(host)
    p=shell/'components/lens/CommandLensPopup.qml';p.write_text('\n'.join(line for line in p.read_text().splitlines() if not line.strip().startswith('anchor.')))
    text=prefix('command-lens-quality')+'''
 Timer {interval:400;running:true;onTriggered:{
  popup.actionsProvider.rows=[{kind:"actions",id:"actions:settings",info:"settings",label:"Settings",detail:"Open the full Settings window",icon:"preferences-system"}];
  popup.filesProvider.rows=[{kind:"files",id:"files:1",info:"/tmp/Design review.pdf",label:"Design review.pdf",detail:"~/Documents/Projects",icon:"application-pdf"}];
  keys.wait(100);test.capture("all");
  for(const scope of ["apps","files","windows","actions"]){popup.content.selectScope(scope);test.query("");keys.wait(80);test.capture(scope);}
  popup.content.selectScope("apps");test.query("zz-no-match");test.capture("no-results");
  test.query("fire");keys.wait(60);test.capture("search-focus");
  popup.targetScreen=({width:380,height:600});test.query("");keys.wait(80);test.capture("narrow");
  Config.DirectoryStyle.touchMode=true;popup.targetScreen=({width:720,height:800});keys.wait(80);test.capture("touch");
  Config.DirectoryStyle.touchMode=false;popup.filesProvider.error="File search unavailable. Other scopes still work.";popup.content.selectScope("all");test.query("fire");keys.wait(80);test.capture("provider-error");
  console.log("ATLAS_DONE");Qt.quit();
 }}
}
'''
    return run_qml(work,shell,'lens',text,ATLAS/'screenshots/full/lens')


def rail():
 with tempfile.TemporaryDirectory(prefix='senomy-atlas-rail-') as d:
    work=Path(d);shell=copied(work)
    source=(SOURCE/'components/RailWindow.qml').read_text()
    content=source[source.index('    WorkspaceRail {'):source.index('    Connections {\n        target: root.uiState',source.index('    WorkspaceRail {'))]
    content=content.replace('monitor: root.hyprlandMonitor','monitor: root.hyprlandMonitor\n        workspaceSource:root.fakeWorkspaces')
    text='''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services"
import "config" as Config
Window {
 id:root;visible:true;width:1920;height:80;color:"#08090b"
 TestCase {id:keys;when:false}
 property bool narrow:width<1700
 property bool veryNarrow:width<1240
 property bool ultraNarrow:width<820
 property bool microNarrow:width<680
 property int railInset:microNarrow?6:Config.Theme.screenInset
 property var deviceInventory:null
 QtObject {id:monitor;property string name:"fixture"}
 property var hyprlandMonitor:monitor
 property var fakeWorkspaces:Array.from({length:7},(_,i)=>({id:i+1,active:i===1,monitor:monitor,toplevels:{values:i===1?[{lastIpcObject:{class:"firefox"}},{lastIpcObject:{class:"code"}}]:[]},activate:()=>{}}))
 property var metrics:({ready:true,cpuPercent:17,memoryPercent:28,uptimeLabel:"3h 14m"})
 property var senomy:({state:"nominal",attentionState:"nominal",message:"System steady",systemHealth:"nominal"})
 property var audio:({label:"48%",available:true,volume:.48,muted:false,inputMuted:false,outputName:"Fixture speakers"})
 property var battery:({label:"76%",percentage:76,available:true,count:2,charging:false,onBattery:true,detail:"Two synthetic packs"})
 property var network:({label:"WI-FI",available:true,detail:"Synthetic network",wifiEnabled:true,icon:"wifi",signalStrength:.7,activeConnection:"Studio"})
 property var notifications:({unreadCount:3,activeCount:1,dnd:false,serverEnabled:true})
 property var power:({hasSchedule:false,available:true,schedule:{label:""},remainingText:"",remainingSeconds:0,progress:0})
 ShellState {id:state}
 property var uiState:state
 property string popupPrefix:"fixture"
 property string trayToken:"tray:fixture"
 property string volumeToken:"volume:fixture"
 property string networkToken:"network:fixture"
 property string batteryToken:"battery:fixture"
 property string calendarToken:"calendar:fixture"
 property string notificationsToken:"notifications:fixture"
 property string powerToken:"power:fixture"
 property bool machineHoverRequested:false
 property bool machineHoverSuppressed:false
 property bool machineKeyboardRequested:false
 function openSystemDashboard(){}
 Timer {id:machineHoverCloseTimer;interval:190}
 QtObject {id:machineStateOverlay;property bool hovered:false}
'''+content+'''
 function save(item,name){let done=false;item.grabToImage(r=>{r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)keys.wait(10);}
 Timer {interval:500;running:true;onTriggered:{
  for(const w of [1920,1366,800,390]){root.width=w;keys.wait(150);save(root.contentItem,"rail-"+w);}
  root.width=1920;keys.wait(100);
  save(workspaceRail,"workspaces");save(machineStateIsland,"machine-state");save(systemControlsIsland,"system-controls");save(clockIsland,"clock");save(powerIsland,"session-trigger");
  machineStateIsland.forceActiveFocus();keys.wait(50);save(machineStateIsland,"machine-focus");machineStateIsland.expanded=true;keys.wait(100);save(machineStateIsland,"machine-message");
  console.log("ATLAS_DONE");Qt.quit();
 }}
}
'''
    return run_qml(work,shell,'rail',text,ATLAS/'screenshots/full/rail')


def accounts():
 with tempfile.TemporaryDirectory(prefix='senomy-atlas-accounts-') as d:
    work=Path(d);shell=copied(work)
    text='''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components/control" as Control
Window {
 id:test;visible:true;width:800;height:700;color:"#08090b"
 TestCase {id:keys;when:false}
 QtObject {id:service
  property bool available:true
  property bool locked:false
  property bool loading:false
  property string message:""
  property string actionState:"idle"
  property string operation:""
  property var target:null
  property var proposed:null
  property var snapshot:({currentUid:2001,complete:true,message:"Synthetic account inventory",passwordAvailable:true,administrativePasswordAvailable:true,providerSetupAvailable:false})
  property var accounts:[{uid:2001,username:"fixture",name:"Fixture Account",avatar:"",current:true,signedIn:true,administrator:true,locked:false,managed:true},{uid:2002,username:"guest",name:"Guest Account",avatar:"",current:false,signedIn:false,administrator:false,locked:false,managed:true}]
  function cancel(){actionState="idle";}
  function request(operation,target,value){}
  function refresh(){}
 }
 Control.ControlAccountsPage {id:page;anchors.fill:parent;anchors.margins:20;service:service}
 function save(name){let done=false;page.grabToImage(r=>{r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)keys.wait(10);}
 Timer {interval:400;running:true;onTriggered:{
  save("profile");page.showAdministration=true;keys.wait(80);save("administration");page.contentY=Math.max(0,page.contentHeight-page.height);keys.wait(80);save("administration-lower");
  page.showProvider=true;keys.wait(80);save("provider");test.width=390;test.height=740;page.contentY=0;keys.wait(80);save("narrow");
  service.operation="name";service.target=service.accounts[0];service.proposed="Example name";service.actionState="pending";page.contentY=0;keys.wait(80);save("review");
  service.actionState="failed";service.message="Synthetic authorization failed. No account changed.";keys.wait(80);save("failed");
  console.log("ATLAS_DONE");Qt.quit();
 }}
}
'''
    return run_qml(work,shell,'accounts',text,ATLAS/'screenshots/full/accounts')


def network_power():
 with tempfile.TemporaryDirectory(prefix='senomy-atlas-quick-') as d:
    work=Path(d);shell=prepared(work)
    # SystemPopover retains its complete authored content with an inert Item host.
    p=shell/'components/SystemPopover.qml';s=p.read_text().replace('Interaction.QuickPopoverWindow {','FocusScope {',1).replace('    id: root','''    id: root
    property var targetScreen:null
    property var anchorItem:null
    property var focusTarget
    property bool cardShown:true
    property bool requestedOpen:true
    function handleEscape(){}
    function dismiss(){}
''',1).replace('    color: "transparent"','')
    s='\n'.join(line for line in s.splitlines() if not line.strip().startswith('anchor.'));p.write_text(s)
    # Reuse complete current network and energy services with inert native objects.
    text=prefix('control-directory')
    text=text[:text.index('    ControlCentre {')]+'''
    property var net:({profiles:{busy:false,error:"",status:{devices:[],connectivity:"full"},items:[],actions:actions},connectionAttempt:{message:"",actionState:"idle",busy:false},actions:actions,activeConnection:"Studio Wi-Fi",available:true,connectivityName:"Full",detail:"Synthetic network · 70%",label:"WI-FI",managedDevices:[],primaryDevice:"wlan-fixture",scanning:false,sortedWifiNetworks:test.fakeWifi.slice(0,4),wifiEnabled:true,wifiHardwareEnabled:true})
    NetworkPopup {id:network;x:8;y:8;width:460;height:600;network:test.net}
    property var batteryPreview:({care:{snapshot:{},packs:[],actionState:"idle",persistentChoice:false,locked:false,busy:false,fresh:false,installed:false,message:"Care provider not connected in this preview"},available:true,label:"76%",detail:"Two synthetic packs",percentage:76,count:2,charging:false,onBattery:true,timeLabel:"2h 40m",batteries:[],powerProfileAvailable:true,powerProfile:0,powerProfileName:"Balanced",selectionActions:actions,selectionOptions:function(){return [];}})
    BatteryPopup {id:batteryPopup;visible:false;x:8;y:8;width:460;height:590;battery:test.batteryPreview}
    function save(item,name){let done=false;item.grabToImage(r=>{r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)input.wait(10);}
    Timer {interval:400;running:true;onTriggered:{
      save(network,"network");actions.actionState="pending";input.wait(80);save(network,"network-review");actions.actionState="idle";
      test.net=Object.assign({},test.net,{available:false,wifiHardwareEnabled:false,sortedWifiNetworks:[],detail:"Synthetic provider unavailable"});input.wait(80);save(network,"network-unavailable");
      network.visible=false;batteryPopup.visible=true;input.wait(100);save(batteryPopup,"battery");
      console.log("ATLAS_DONE");Qt.quit();
    }}
}
'''
    return run_qml(work,shell,'network',text,ATLAS/'screenshots/full/network')


def bluetooth_quick():
 with tempfile.TemporaryDirectory(prefix='senomy-atlas-bt-quick-') as d:
    work=Path(d);shell=copied(work)
    p=shell/'components/BluetoothPopup.qml';s=p.read_text().replace('Interaction.QuickPopoverWindow {','FocusScope {',1).replace('    id:root','''    id:root
    property var targetScreen:({width:1920,height:1080})
    property bool cardShown:true
    property bool requestedOpen:visible
    property var focusTarget
    property bool keyboardPriority
    function handleEscape(){}
    function dismiss(){}
    signal dismissRequested()
''',1).replace('    color:"transparent"','    property color color:"transparent"')
    p.write_text('\n'.join(line for line in s.splitlines() if not line.strip().startswith('anchor.')))
    text=prefix('bluetooth-quality')+'''
 function take(item,name){let done=false;item.grabToImage(r=>{r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)keys.wait(10);}
 function inspector(item){if(String(item).startsWith("BluetoothInspector_"))return item;for(const c of item.children){const hit=inspector(c);if(hit)return hit;}return null;}
 Timer {interval:400;running:true;onTriggered:{
   test.setup(null);page.visible=false;popup.visible=true;keys.wait(150);take(popup,"quick");popup.visible=false;page.visible=true;service.selectDevice(test.earbuds);keys.wait(100);
   const inspected=inspector(page);if(inspected)take(inspected,"inspector-crop");
   test.setup({id:"inert",path:test.earbuds.id,token:"d1",action:"connect",phase:"failed",message:"Synthetic device did not answer.",errorName:"org.bluez.Error.Failed",errorDetail:"fixture-timeout"});keys.wait(100);if(inspected)take(inspected,"inspector-error-crop");
   console.log("ATLAS_DONE");Qt.quit();
 }}
}
'''
    return run_qml(work,shell,'bluetooth-quick',text,ATLAS/'screenshots/full/bluetooth-quick')


def energy():
 with tempfile.TemporaryDirectory(prefix='senomy-atlas-energy-') as d:
    work=Path(d);shell=copied(work)
    text=(SOURCE/'energy-page-test.qml').read_text();text=text[:text.index('    Timer {')]
    text=text.replace('property var backend:', 'property var snapshot:({tlp:{version:"fixture",mode:"balanced"}})\n        property var backend:')
    # Supply a deliberately unavailable care provider, not a fabricated hardware result.
    text=text.replace('energyEnabled:false; actionContext:', 'energyEnabled:false; care:care; actionContext:')
    text=text.replace('    ControlPowerPage {','''    QtObject {id:care;property var snapshot:({});property var packs:[];property string actionState:"idle";property bool persistentChoice:false;property bool locked:false;property bool busy:false;property bool fresh:false;property bool installed:false;property string message:"Care not connected in this preview"}
    ControlPowerPage {''')
    text+='''
 function save(name){let done=false;page.grabToImage(r=>{r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)input.wait(10);}
 Timer {interval:400;running:true;onTriggered:{
  suite.width=800;suite.height=700;
  for(const part of ["overview","profiles","batteries"]){page.part=part;input.wait(100);save(part);}
  page.part="profiles";battery.setPowerProfile(0);input.wait(80);save("profile-review");battery.selectionActions.cancel();
  suite.width=390;page.part="profiles";input.wait(100);save("narrow");
  console.log("ATLAS_DONE");Qt.quit();
 }}
}
'''
    return run_qml(work,shell,'energy',text,ATLAS/'screenshots/full/energy')


def expanded():
 with tempfile.TemporaryDirectory(prefix='senomy-atlas-expanded-') as d:
    work=Path(d);shell=copied(work)
    text='''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services"
Window {
 id:test;visible:true;width:900;height:420;color:"#08090b"
 TestCase {id:keys;when:false}
 property var metrics:({ready:true,cpuPercent:17,memoryPercent:28,memoryTotalKib:32000000,memoryUsedKib:8960000,kernelRelease:"fixture-kernel",hostName:"Fixture",hostModel:"Reference laptop",cpuModel:"Synthetic 8-core processor",temperatureAvailable:true,temperatureCelsius:42,uptimeDetailedLabel:"03:14:00",history:history})
 TelemetryHistory {id:history;metrics:test.metrics}
 ExpandedSenomyPanel {id:panel;anchors.fill:parent;metrics:test.metrics;active:true}
 function save(name){let done=false;panel.grabToImage(r=>{r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)keys.wait(10);}
 Timer {interval:500;running:true;onTriggered:{save("wide");test.width=390;test.height=760;keys.wait(100);save("narrow");console.log("ATLAS_DONE");Qt.quit();}}
}
'''
    return run_qml(work,shell,'expanded',text,ATLAS/'screenshots/full/expanded')


def safety():
 with tempfile.TemporaryDirectory(prefix='senomy-atlas-safety-') as d:
    work=Path(d);shell=copied(work)
    p=shell/'components/DisplayRecovery.qml'
    actual=p.read_text().replace('PanelWindow {','Rectangle {',1)
    actual='\n'.join(line for line in actual.splitlines() if not line.strip().startswith(('screen:','anchors.top:','margins.top:','exclusionMode:','exclusiveZone:','WlrLayershell.')))
    p.write_text(actual)
    text='''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services"
Window {
 id:test;visible:true;width:700;height:340;color:"#08090b"
 TestCase {id:keys;when:false}
 QtObject {id:provider;function runDisplayOperation(op,arg){return false;}}
 DisplayActions {id:actions;provider:provider;context:"atlas"}
 DisplayRecovery {id:review;width:parent.width-40;height:implicitHeight;x:20;y:20;targetScreen:null;inventory:({displayActions:actions})}
 function save(name){keys.wait(100);let done=false;review.grabToImage(r=>{r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)keys.wait(10);}
 Timer {interval:400;running:true;onTriggered:{
  actions.applied("inert-preview",Date.now()+30000);save("keep-revert");actions.fail("Synthetic recovery failed. No display operation was attempted.");save("recovery-failed");
  console.log("ATLAS_DONE");Qt.quit();
 }}
}
'''
    return run_qml(work,shell,'safety',text,ATLAS/'screenshots/full/safety')


def care():
 with tempfile.TemporaryDirectory(prefix='senomy-atlas-care-') as d:
    work=Path(d);shell=copied(work)
    text=(SOURCE/'battery-care-test.qml').read_text();text=text[:text.index('    Timer {')]
    # Use the current controller with the pre-existing inert transport. No apply.
    fixture=work/'care';fixture.mkdir()
    text=text.replace('BatteryCare { id:care;', 'BatteryCare { id:care;')
    text+='''
 function save(name){let done=false;editor.grabToImage(r=>{r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;},Qt.size(editor.width,editor.height));while(!done)input.wait(10);}
 Timer {interval:400;running:true;onTriggered:{
  for(let i=0;i<100&&!care.fresh;i++)input.wait(20);
  if(!care.fresh){console.log("CARE_UNAVAILABLE");Qt.quit();return;}
  suite.width=800;suite.height=editor.implicitHeight;input.wait(100);save("dual-packs");
  console.log("ATLAS_DONE");Qt.quit();
 }}
}
'''
    # Explicit private directory goes into the isolated environment only.
    import capture as cap
    original=cap.isolated_env
    def env(w,o):
        e=original(w,o);e['SENOMY_PRIVATE_CARE_FIXTURE']=str(fixture);return e
    cap.isolated_env=env
    try:return run_qml(work,shell,'care',text,ATLAS/'screenshots/full/care')
    finally:cap.isolated_env=original


if __name__=='__main__':
    results=[]
    for fun in [rail,lens,accounts,network_power,energy,expanded,safety,care,bluetooth_quick]:
      try:results.append(fun())
      except Exception as e:results.append({'job':fun.__name__,'error':str(e)});print(json.dumps(results[-1]),flush=True)
    (ATLAS/'capture-extra-results.json').write_text(json.dumps(results,indent=2)+'\n')
