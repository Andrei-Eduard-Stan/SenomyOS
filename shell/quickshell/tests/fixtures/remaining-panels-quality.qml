import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtTest
import Quickshell
import "components"
import "services"
import "config" as Config
Window {
 id:test;visible:true;width:432;height:700;color:"#12161a"
 property bool baseline:Quickshell.env("SENOMY_REMAINING_VARIANT")==="baseline"
 property string scene:"bluetooth"
 property var calls:[]
 property bool liveAction:true
 TestCase {id:keys;when:false}
 BluetoothService {id:btData;transportEnabled:false;actionContext:"fixture";onTestRequest:request=>test.calls=test.calls.concat([request])}
 property var adapter:({id:"/org/bluez/hci0",token:"adapter",name:"Bluetooth adapter",powered:true,powerState:"on",discovering:false,discoverable:false,pairable:false,expected:{Powered:true}})
 property var devices:Array.from({length:8},(_,i)=>({id:"/org/bluez/hci0/dev_fixture_"+i,token:"device-"+i,adapter:"/org/bluez/hci0",address:"AA:BB:CC:DD:EE:"+String(i).padStart(2,"0"),name:i===0?"Studio headphones":i===1?"Mechanical keyboard":"Saved device "+i,deviceName:i===0?"Studio headphones":"Device "+i,icon:i===0?"audio-headset":"input-keyboard",paired:i<6,bonded:i<6,trusted:i<6,blocked:false,connected:i===0,battery:i===0?72:null,recent:true,group:i===0?"connected":i<6?"paired":"nearby",uuids:[],interfaces:[],expected:{Powered:true,Connected:i===0,Paired:i<6}}))
 function setupBluetooth(){btData.snapshot={available:true,error:"",adapters:[adapter],devices:devices,operations:{},scan:{state:"idle",owned:false,message:""},prompt:null};}
 QtObject {id:session;property bool busy:false;property string error:"";property int remainingSeconds:45;property string remainingText:"45s";property real progress:.4;property var schedule:({});function cancelSchedule(){test.calls=test.calls.concat(["cancel-schedule"]);schedule={};}}
 QtObject {id:notificationData
  property bool serverEnabled:true
  property bool dnd:false
  property int toastGeneration:0
  property var sessionService:session
  property var latest:({id:1,receivedAt:Date.now(),appName:"Studio",urgency:"Critical",summary:"Export completed",body:"Your render is ready. This synthetic message stays readable while its actions remain reachable below.",actions:Array.from({length:7},(_,i)=>({identifier:"a"+i,text:"Action "+i}))})
  function isLive(record){return test.liveAction && record===latest;}
  function invoke(record,action){if(!isLive(record))throw new Error("stale action");test.calls=test.calls.concat([{kind:"notification",id:record.id,action:action.identifier}]);}
  function dismiss(record){throw new Error("Hide may not dismiss history");}
  function markRead(record){throw new Error("Toast may not mark history read");}
  function openSessionRequested(){test.calls=test.calls.concat(["open-session"]);}
 }
 QtObject {id:player;property bool canGoPrevious:true;property bool canGoNext:true;property bool canTogglePlaying:true;property bool canSeek:false;property bool positionSupported:false;property bool lengthSupported:false;property string uniqueId:"fixture-player"}
 QtObject {id:mediaData
  property bool available:true;property bool playing:false;property var selectedPlayer:player;property var players:[player];property string identity:"Fixture media";property string title:"Synthetic track title with enough context to show the inline player";property string artist:"Fixture artist";property string artwork:"";property real duration:240;property real position:45
  function previous(){test.calls=test.calls.concat(["previous"]);}function next(){test.calls=test.calls.concat(["next"]);}function toggle(){test.calls=test.calls.concat(["play"]);playing=!playing;}
 }
 QtObject {id:keyboardProvider
  property bool running:false;property int currentSerial:0;property bool visible:false;property bool visibilityKnown:true;property bool modeSupported:true;property bool signalReady:true;property bool floating:true;property string lockMessage:"Private fixture keyboard"
  function owns(serial){return running && serial===currentSerial;}
  function start(name,serial,automatic){test.calls=test.calls.concat(["keyboard-start"]);currentSerial=serial;running=true;Qt.callLater(()=>keyboard.started(serial));return true;}
  function show(serial){if(!owns(serial))return false;visible=true;test.calls=test.calls.concat(["keyboard-show"]);return true;}
  function hide(serial){if(!owns(serial))return false;visible=false;test.calls=test.calls.concat(["keyboard-hide"]);return true;}
  function stop(serial){if(!owns(serial))return false;test.calls=test.calls.concat(["keyboard-stop"]);Qt.callLater(()=>{running=false;keyboard.exited(serial,true);});return true;}
  function toggleMode(serial){if(!owns(serial))return false;floating=!floating;test.calls=test.calls.concat(["keyboard-mode"]);return true;}
 }
 OskController {id:keyboard;provider:keyboardProvider;capabilities:({providerInstalled:true,protocolState:"advertised",manualCandidate:true,provider:"wvkbd-mobintl"})}
 QtObject {id:automatic;property string mode:"manual";property bool settingMode:false;property bool available:true;property string status:"Manual opening · synthetic provider";function setMode(value){mode=value;test.calls=test.calls.concat(["opening-mode"]);}}
 QtObject {id:inputSettings;property bool editorAvailable:true;property bool engineInstalled:true;property bool nativeToolsBusy:false;property string nativeToolsMessage:"";property var oskAutomatic:automatic;property var oskController:keyboard;property var oskCapabilities:({providerInstalled:true,manualCandidate:true,protocolState:"advertised",message:"Synthetic provider available; no real process is started."});function openInputMethodSettings(){test.calls=test.calls.concat(["input-editor"]);}}
 QtObject {id:monitorData;property string name:"fixture"}
 property var workspaces:Array.from({length:7},(_,i)=>({id:i+1,active:i===0,urgent:false,monitor:monitorData,toplevels:{values:[]},activate:function(){test.calls=test.calls.concat(["workspace-activate-"+i]);}}))
 Loader {id:loader;anchors.fill:parent;sourceComponent:scene==="bluetooth"?bluetoothView:scene==="toast"?toastView:scene==="workspace"?workspaceView:keyboardView}
 Component {id:bluetoothView;BluetoothPopup {bluetooth:btData;targetScreen:({name:"fixture",width:test.width+48,height:900});width:test.width;height:test.height;onOpenSettingsRequested:test.calls=test.calls.concat(["bluetooth-settings"])}}
 Component {id:toastView;NotificationToast {targetScreen:({name:"fixture",width:test.width+48,height:900});notifications:notificationData;placementEnabled:true}}
 Component {id:keyboardView;Item {IslandPopupFrame {anchors.fill:parent;frameKey:"control";active:true;animate:false;contentInset:Config.QuickPanelStyle.inset;FocusScrollArea {anchors.fill:parent;contentHeight:tools.implicitHeight;ScrollBar.vertical:ShellScrollBar {}NativeInputToolsView {id:tools;width:parent.width-12;settings:inputSettings}}}}}
 Component {id:workspaceView;Item {WorkspaceRail {id:rail;objectName:"workspace-rail";width:implicitWidth;height:72;anchors.centerIn:parent;monitor:monitorData;workspaceSource:test.workspaces}}}
 function check(ok,message){if(!ok)throw new Error(message);}
 function waitFor(fn,message){for(let i=0;i<100&&!fn();i++)keys.wait(20);check(fn(),message);}
 function named(name){const item=keys.findChild(loader.item,name);check(!!item,"exists: "+name);return item;}
 function enter(name){const item=named(name);check(item.visible&&item.enabled,"available: "+name);item.forceActiveFocus(Qt.TabFocusReason);keys.keyClick(Qt.Key_Return);keys.wait(70);}
 function show(which,w,h){scene=which;width=w;height=h;keys.wait(100);if(which==="toast"){notificationData.dnd=false;notificationData.toastGeneration++;keys.wait(40);}}
 function capture(name){if(scene==="toast"){const frame=keys.findChild(loader.item,"toast-frame");if(frame)waitFor(()=>frame.opacity>.99,"toast capture settles");else keys.wait(300);}let done=false;loader.item.grabToImage(result=>{check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture "+name);done=true;});while(!done)keys.wait(20);}
 Timer {interval:400;running:true;onTriggered:{try{
  setupBluetooth();
  for(const which of ["bluetooth","toast","keyboard","workspace"]){show(which,which==="workspace"?380:432,which==="toast"?460:which==="workspace"?120:740);capture(which+"-wide");}
  check(calls.length===0,"opening panels never dispatches");
  if(baseline){console.log("PASS: actual baseline remaining panels with synthetic providers");Qt.quit();return;}
  show("bluetooth",432,740);enter("bluetoothFilter:nearby");check(calls.length===0,"nearby filter never scans");capture("bluetooth-nearby");const search=named("bluetoothSearch");search.text="keyboard";keys.wait(40);capture("bluetooth-search");search.text="";enter("bluetoothFilter:saved");enter("bluetoothDetails:"+devices[0].id);check(calls.length===0,"inline quick details never pair or leave popup");check(named("bluetoothInlineInspector").visible,"quick inline inspector");capture("bluetooth-inline");enter("bluetoothInspectorClose");check(!btData.selectedDevice,"Back returns to list");
  show("toast",432,460);capture("toast-actions");enter("toast-action-a6");check(calls.length===1 && calls[0].action==="a6" && !loader.item.shown,"exact final app action invoked once");calls=[];const standardRecord=notificationData.latest;notificationData.latest=Object.assign({},standardRecord,{actions:Array.from({length:12},(_,i)=>({identifier:"long"+i,text:"Open the synthetic destination for action "+i}))});notificationData.toastGeneration++;keys.wait(250);capture("toast-long-actions");const finalAction=named("toast-action-long11"),actionViewport=named("toast-actions-viewport");finalAction.forceActiveFocus(Qt.TabFocusReason);keys.wait(70);const actionPoint=finalAction.mapToItem(actionViewport,0,0);check(actionPoint.y>=-1&&actionPoint.y+finalAction.height<=actionViewport.height+1,"long final action remains fully visible after keyboard scrolling");keys.keyClick(Qt.Key_Return);keys.wait(70);check(calls.length===1&&calls[0].action==="long11","long footer exact action once");calls=[];notificationData.latest=standardRecord;notificationData.toastGeneration++;keys.wait(50);enter("toast-hide");check(calls.length===0,"hide never dismisses or reads history");notificationData.toastGeneration++;keys.wait(30);const admitted=loader.item.presentedNotification;notificationData.dnd=true;notificationData.latest=Object.assign({},notificationData.latest,{id:2,summary:"Suppressed synthetic replacement"});notificationData.toastGeneration++;keys.wait(30);check(loader.item.presentedNotification===admitted,"DND cannot replace presented generation");test.liveAction=false;keys.wait(30);check(keys.findChild(loader.item,"toast-action-a6")===null,"stale actions unavailable");test.liveAction=true;notificationData.dnd=false;notificationData.toastGeneration++;keys.wait(30);
  session.schedule={state:"scheduled",action:"reboot",label:"Restart",dueLabel:"Synthetic deadline",statusDetail:"Fixture only"};session.remainingSeconds=8;session.remainingText="8s";notificationData.dnd=true;keys.wait(50);check(loader.item.showCommitment,"final warning bypasses DND independently of history");capture("toast-commitment");enter("final-session-cancel");check(calls.length===1 && calls[0]==="cancel-schedule","pinned cancel routes exact scheduled request");calls=[];notificationData.dnd=false;
  show("keyboard",432,740);enter("oskShow");check(keyboard.state==="pending-start"&&calls.length===0,"start requires original review");check(activeFocusItem.objectName==="oskCancel","keyboard Cancel default");capture("keyboard-start-review");enter("oskCancel");check(!keyboard.owned&&calls.length===0,"cancel does not start provider");enter("oskShow");enter("oskConfirm");waitFor(()=>keyboard.owned&&!keyboard.startPending,"inert owned keyboard starts");check(calls.join(",")==="keyboard-start,keyboard-show","owned start/show exactly once");calls=[];enter("oskHide");capture("keyboard-hidden");check(!keyboardProvider.visible,"observed hidden state");enter("oskStop");check(keyboard.state==="pending-stop","stop retains review");capture("keyboard-stop-review");enter("oskCancel");check(keyboard.owned,"cancel retains owned child");enter("oskStop");enter("oskConfirm");waitFor(()=>!keyboard.owned,"confirmed private stop");calls=[];
  show("workspace",380,120);const rail=named("workspace-rail");rail.focusIndex(0);keys.wait(50);keys.keyClick(Qt.Key_End);keys.wait(200);check(rail.offset===4,"End reveals final workspace page");keys.keyClick(Qt.Key_Home);keys.wait(200);check(rail.offset===0&&calls.length===0,"workspace focus never activates");capture("workspace-focus");keys.keyClick(Qt.Key_Return);check(calls.length===1,"only Enter activates exact workspace");calls=[];
  for(const which of ["bluetooth","toast","keyboard"]){show(which,320,which==="toast"?500:700);capture(which+"-narrow");}
  const registry=JSON.parse(JSON.stringify(Config.Skin.registry));Config.Skin.registry=Object.assign({},registry,{persona:Object.assign({},registry.persona||{},{uiTextScale:1.4,highContrast:true,reducedMotion:true})});Config.DirectoryStyle.touchMode=true;
  for(const which of ["bluetooth","toast","keyboard"]){show(which,460,760);capture(which+"-large-touch");}Config.DirectoryStyle.touchMode=false;Config.Skin.registry=registry;
  console.log("PASS: native Bluetooth quick filter/inline details, toast admission/exact actions/session priority, real OSK owned review and workspace focus; inert providers only");Qt.quit();
 }catch(error){console.error("FAIL: "+error.message);Qt.exit(1);}}}
}
