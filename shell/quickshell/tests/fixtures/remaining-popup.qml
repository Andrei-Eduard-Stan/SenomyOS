import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "config" as Config
Window {
 id:test;visible:true;width:470;height:610;color:"#20242a"
 property string route:"notifications"
 property int invocations:0
 property int dismissals:0
 property int mutations:0
 property var selection:({canGoPrevious:true,canGoNext:true,canTogglePlaying:true})
 TestCase {id:input;when:false}
 QtObject {
  id:clearGuard
  property string actionState:"idle"
  property bool locked:false
  property string requestedContext:"notifications:fixture"
  property string impact:"Clear all retained records and active notifications? This is a fake provider."
  property string message:""
  function cancel(){actionState="idle";}
  function confirm(context){if(context!==requestedContext)throw new Error("context");test.mutations++;actionState="succeeded";}
 }
 QtObject {
  id:notificationProvider
  property var sessionService:powerProvider
  property bool serverEnabled:true
  property bool dnd:false
  property int activeCount:4
  readonly property int unreadCount:history.filter(r=>r.unread).length
  property bool clearAvailable:true
  property var clearActions:clearGuard
  property var history:Array.from({length:14},(_,i)=>({id:i,receivedAt:Date.now()-i*60000,appName:"Fixture application "+i,summary:"Notification "+i+" · bounded local state",body:"Readable content with a long description to exercise wrapping and preserve every client action.",urgency:i===0?"Critical":"Normal",unread:i===0,actions:Array.from({length:7},(_,a)=>({text:"Action "+a,identifier:"a"+a}))}))
  property var latest:history[0]
  property int toastGeneration:0
  function markRead(record){history=history.map(r=>Object.assign({},r,{unread:record?r.id===record.id?false:r.unread:false}));}
  function setDnd(value){dnd=value;}
  function clearAll(context){clearGuard.requestedContext=context;clearGuard.actionState="pending";}
  function invoke(record,action){test.invocations++;}
  function dismiss(record){test.dismissals++;}
 }
 QtObject {
  id:powerProvider
  property bool available:true
  property string state:"idle"
  property string pendingAction:"reboot"
  property string error:""
  property bool schedulingAvailable:true
  property bool busy:false
  property bool hasSchedule:false
  property int remainingSeconds:0
  property string remainingText:""
  property real progress:0
  property string unavailableReason:""
  property string pendingKind:"action"
  property string message:""
  property var schedule:({})
  property var review:null
  property var fieldErrors:({})
  signal prepared()
  function supported(action){return true;}
  function clearFeedback(){state="idle";error="";}
  function request(action){pendingAction=action;review={id:"fake",label:"Restart",mode:"now",dueLabel:"Now"};state="pending";prepared();}
  function cancel(){state="idle";}
  function confirm(){test.mutations++;state="running";}
 }
 Loader {
  id:view;anchors.fill:parent
  sourceComponent:test.route==="notifications"?archive:test.route==="toast"?toast:test.route==="calendar"?calendar:test.route==="power"?powerView:test.route==="volume"?volume:test.route==="tray"?tray:null
 }
 Component {id:archive;NotificationCenter {notifications:notificationProvider;clearContext:"notifications:fixture"}}
 Component {id:toast;NotificationToast {targetScreen:({name:"fixture",width:test.width+32,height:800});notifications:notificationProvider;placementEnabled:true;shown:true}}
 Component {id:calendar;CalendarPopup {}}
 Component {id:powerView;PowerPopup {powerService:powerProvider}}
 Component {id:volume;VolumePopup {audio:({ready:true,volumeLimit:1,sink:null,source:null,available:true,inputAvailable:false,inputVolume:0,inputMuted:false,inputName:"Unavailable",outputNodes:[],inputNodes:[],selectionActions:({actionState:"idle",title:"",impact:"",message:""}),volume:.5,muted:false,label:"50%",outputName:"Fixture output",setVolume:function(v){test.invocations++;},toggleMuted:function(){test.invocations++;}})}}
 Component {id:tray;TrayPopup {}}
 function capture(name){let done=false;view.item.grabToImage(function(result){result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)input.wait(20);}
 function findText(item,text){if(item.text===text && item.clicked)return item;for(const child of item.children){const found=findText(child,text);if(found)return found;}return null;}
 function check(value,message){if(!value){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
 Timer {interval:500;running:true;onTriggered:{
  for(const size of [470,320]){
   test.width=size;
   for(const route of ["notifications","toast","calendar","power","volume","tray"]){
    test.route=route;test.height=route==="notifications"?610:route==="calendar"?520:route==="toast"?320:route==="power"?(size<400?320:280):route==="volume"?(size<400?530:480):154;input.wait(180);test.capture(route+"-"+size);
    if(route==="notifications"){
     const clear=test.findText(view.item,"CLEAR");test.check(clear,"archive clear exists");input.mouseClick(clear);input.wait(80);test.capture("archive-review-"+size);const cancel=test.findText(view.item,"CANCEL");test.check(cancel,"archive cancel exists");input.mouseClick(cancel);test.check(test.mutations===0,"clear preview/cancel must not mutate provider");
     const list=input.findChild(view.item,"archive-list");
     const open=input.findChild(view.item,"notification-open-0");input.mouseClick(open);input.wait(80);
     const action=test.findText(view.item,"Action 0");const before=test.invocations;input.mouseClick(action);test.check(test.invocations===before+1,"archive invokes client action once");
     const dismiss=test.findText(view.item,"DISMISS");const prior=test.dismissals;dismiss.forceActiveFocus();input.wait(40);input.mouseClick(dismiss);test.check(test.dismissals===prior+1,"individual archive dismissal");
     const dnd=test.findText(view.item,"DND OFF");input.mouseClick(dnd);test.check(notificationProvider.dnd,"DND toggle");notificationProvider.dnd=false;

    }
    if(route==="toast"){
     const scroll=input.findChild(view.item,"toast-content");scroll.contentY=Math.max(0,scroll.contentHeight-scroll.height);input.wait(40);
     const action=test.findText(view.item,"Action 6");const before=test.invocations;input.mouseClick(action);test.check(test.invocations===before+1 && !view.item.shown,"toast final wrapped action invokes and hides once");
    }
    if(route==="calendar"){
     const next=test.findText(view.item,"›");const browser=input.findChild(view.item,"popup-calendar-browser");const before=browser.navigation.selectedKey;next.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(30);test.check(browser.navigation.selectedKey!==before,"calendar keyboard next period");
    }
    if(route==="power"){
     const reboot=input.findChild(view.item,"session-action-reboot");input.mouseClick(reboot);input.wait(80);test.height=350;input.wait(40);test.capture("power-review-"+size);const cancel=input.findChild(view.item,"powerCancel");test.check(cancel && cancel.activeFocus,"session review defaults to Back");input.mouseClick(cancel);test.check(test.mutations===0,"power cancel no mutation");
    }
   }
  }
  console.log("PASS: actual flyout/notification layouts and non-destructive actions at wide/narrow sizes; fake providers only");Qt.quit();
 }}
}
