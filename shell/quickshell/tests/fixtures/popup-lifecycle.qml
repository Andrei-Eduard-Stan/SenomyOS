//@ pragma UseQApplication
//@ pragma ShellId senomy-lifecycle-fixture
import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Wayland
import "components" as UI
import "components/lens" as Lens
import "services" as Services
import "config" as Config
ShellRoot {
 id:test
 property int checks:0
 property int cancellations:0
 property var openings:[]
 property int badFrames:0
 property double startupRequestAt:0
 property var startupPoint:null
 property string screenName:Quickshell.screens[0].name || "fixture"
 Services.ShellState {
  id:state;availableScreens:[test.screenName]
  onModalCancelRequested:{++test.cancellations;externalModalActive=false;}
 }
 PanelWindow {
  id:rail;screen:Quickshell.screens[0];implicitHeight:72;exclusiveZone:0;color:"#08121b"
  anchors {left:true;right:true;bottom:true}
  WlrLayershell.namespace:"senomy-lifecycle-fixture"
  WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
  Text {anchors.centerIn:parent;text:"ISOLATED LIFECYCLE TEST · NO SYSTEM ACTIONS";color:"white"}
  Item {id:origin;x:rail.width-160;y:2;width:100;height:60;Item {id:trigger;width:44;height:60}}
 }
 Lens.CommandLensPopup {
  id:lens;coordinator:state;targetScreen:rail.screen;anchorItem:trigger
  popupToken:"lens:"+test.screenName;requestedOpen:state.activePopup===popupToken
  providersReady:false;applicationRows:[];windowRows:[]
 }
 UI.SystemPopover {
  id:network;coordinator:state;targetScreen:rail.screen;anchorItem:trigger
  popupToken:"network:"+test.screenName;requestedOpen:state.activePopup===popupToken;title:"INERT NETWORK"

 }
 UI.SystemPopover {
  id:audio;coordinator:state;targetScreen:rail.screen;anchorItem:trigger
  popupToken:"volume:"+test.screenName;requestedOpen:state.activePopup===popupToken;title:"INERT AUDIO"
 }
 TestCase {id:input;when:false;parent:lens.content}
 TestCase {id:networkInput;when:false;parent:network.contentItem}
 Connections {
  target:lens.contentItem.Window.window
  function onFrameSwapped(){
   if(lens.requestedOpen && lens.visible && (lens.width!==lens.implicitWidth || lens.height!==lens.implicitHeight))++test.badFrames;
   if(lens.lease===1 && !test.startupPoint){const w=lens.contentItem.Window.window;test.startupPoint={x:w.x,y:w.y};}
  }
 }
 function check(ok,message){++checks;if(!ok)throw new Error(message);}
 function until(predicate,message){for(let n=0;n<200 && !predicate();++n)input.wait(10);check(predicate(),message);}
 function capture(item,name){
  const out=Quickshell.env("SENOMY_QA_OUT");if(!out)return;
  let saved=false;check(item.grabToImage(result=>{saved=result.saveToFile(out+"/"+name+".png");}),"capture requested");until(()=>saved,"capture saved");
 }
 function openLens(){const start=Date.now();check(state.togglePopup("lens",test.screenName),"request accepted");until(()=>lens.cardShown,"Lens Open");if(Quickshell.env("SENOMY_NATIVE_FIXTURE")==="1")until(()=>lens.ownsEscape,"Lens native keyboard focus");openings.push({lease:lens.lease,readyMs:Date.now()-start,width:lens.width,height:lens.height});}
 function run(){
  until(()=>lens.cardShown,"immediate startup request reaches Open");
  until(()=>lens.content.opacity===1,"startup internal opening settles");
  const desiredY=trigger.mapToGlobal(0,0).y-12-lens.height;
  console.log("STARTUP_GEOMETRY "+JSON.stringify({first:startupPoint,settled:{x:lens.contentItem.Window.window.x,y:lens.contentItem.Window.window.y},expectedY:desiredY}));
  if(Quickshell.env("SENOMY_NATIVE_FIXTURE")==="1")check(startupPoint && Math.abs(startupPoint.y-desiredY)<=2,"startup first-frame anchor is correct");
  check(startupPoint && startupPoint.x===lens.contentItem.Window.window.x && startupPoint.y===lens.contentItem.Window.window.y,"startup first-frame placement matches settled placement");
  openings.push({origin:"startup",readyByObservationMs:Date.now()-startupRequestAt,width:lens.width,height:lens.height});
  lens.handleEscape();openLens();
  const w=lens.width,h=lens.height;until(()=>lens.content.searchInput.activeFocus,"Qt search focus");
  until(()=>lens.content.opacity===1,"internal opening motion settles");capture(lens.content,"lens");
  input.keyClick(Qt.Key_Escape);check(!lens.visible && state.activePrimary==="control","Qt Escape closes Lens only");
  for(let n=0;n<12;n++){
   openLens();const generation=lens.localGeneration,lease=lens.lease;
   state.togglePopup("network",test.screenName);lens.reveal(generation,lease);
   check(!lens.visible && !lens.cardShown,"replaced completion inert");state.closePopups();
  }
  for(let n=0;n<20;n++){state.togglePopup("lens",test.screenName);state.togglePopup("lens",test.screenName);}
  openLens();const oldGeneration=lens.localGeneration,oldLease=lens.lease;
  state.closePopups();state.togglePopup("lens",test.screenName);lens.reveal(oldGeneration,oldLease);
  check(!lens.cardShown,"old same-token completion inert");until(()=>lens.cardShown,"latest opening survives");
  const localX=trigger.x,nativeX=lens.contentItem.Window.window.x;origin.x-=500;input.wait(120);
  if(Quickshell.env("SENOMY_NATIVE_FIXTURE")==="1")until(()=>lens.contentItem.Window.window.x!==nativeX,"native popup follows ancestor movement");
  check(trigger.x===localX && lens.width===w && lens.height===h,"ancestor movement preserves size and local x");
  lens.filesProvider.rows=[{kind:"files",id:"fixture",label:"Late fixture",info:"/fixture/never-open",detail:"Fake data",icon:""}];lens.content.searchText="fixture";
  for(const mode of ["apps","files","windows","actions","all"]){state.lensMode=mode;input.wait(20);check(lens.width===w && lens.height===h,"scope/query/data keep geometry");}
  state.lensMode="files";
  const list=input.findChild(lens.content,"lensResults");until(()=>!!list.currentItem,"file result delegate ready");
  input.mouseClick(list.currentItem,40,20,Qt.RightButton);
  const fileMenu=input.findChild(list.currentItem,"lensContextMenu");until(()=>fileMenu.opened,"Lens file child opens");
  input.keyClick(Qt.Key_Escape);until(()=>!fileMenu.visible,"Lens Escape closes file menu");check(lens.requestedOpen,"file-menu Escape preserves Lens");
  state.externalModalActive=true;check(!state.togglePopup("volume",test.screenName),"review refuses conflict");
  lens.handleEscape();check(cancellations===1 && lens.requestedOpen,"Escape cancels review before owner");lens.handleEscape();check(!lens.visible,"next Escape closes owner");
  const owner=trigger.parent;trigger.parent=null;state.togglePopup("lens",test.screenName);input.wait(30);
  check(!lens.visible && lens.lifecycle==="preparing","detached item stays Preparing");trigger.parent=owner;
  until(()=>lens.cardShown,"parent readiness resumes opening");
  state.externalModalActive=true;trigger.parent=null;until(()=>!state.activePopup,"lost anchor closes owner");
  check(!lens.visible && cancellations===2,"lost-anchor review cancels");trigger.parent=owner;
  state.togglePopup("network",test.screenName);until(()=>network.cardShown,"Network Open");state.togglePopup("volume",test.screenName);
  check(!network.visible && audio.visible,"Network to Audio exclusive");state.showPrimary("control",test.screenName,"audio");
  check(!audio.visible && !state.activePopup,"primary entry closes quick popup");
  trigger.parent=null;state.togglePopup("lens",test.screenName);state.closePopups();trigger.parent=owner;
  input.wait(80);check(!lens.visible && !network.visible && !audio.visible && !state.activePopup,"no stale interactive hosts");
  input.wait(1000);openLens();rail.visible=false;until(()=>!state.activePopup,"hidden native parent closes popup");
  rail.visible=true;openLens();lens.handleEscape();check(badFrames===0,"all initial and later native frame dimensions match intent");
  Config.RenderMetrics.stop();console.log("METRICS "+JSON.stringify(Config.RenderMetrics.snapshot()));console.log("OPENINGS "+JSON.stringify(openings));
  console.log("PASS: "+checks+" lifecycle/frame checks; Qt Escape, 12 replacements, 20 rapid toggles, stale completions, readiness/loss, modal owner and file-menu input");Qt.quit();
 }
 Component.onCompleted:{Config.RenderMetrics.start();state.showPrimary("control",test.screenName,"overview");startupRequestAt=Date.now();state.togglePopup("lens",test.screenName);}
 Timer {interval:60;running:true;onTriggered:{try{test.run();}catch(error){console.log("METRICS "+JSON.stringify(Config.RenderMetrics.snapshot()));console.error("FAIL: "+error.message+"\n"+error.stack);Qt.exit(1);}}}
}
