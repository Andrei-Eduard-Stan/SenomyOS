import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Wayland
import "components"
import "services"
Scope {
 id:shell
 TestCase {id:input;when:false}
 ShellState {id:shellState}
 QtObject {id:rails;property var instances:[({screen:Quickshell.screens[0],controlAnchorX:Quickshell.screens[0].width-300})]}
    // INSERT_PLACEMENT_BINDINGS

 property bool baseline:Quickshell.env("SENOMY_CLOSE_BASELINE")==="1"
 DashboardWindow {
  id:host
  targetScreen:shell.baseline?(Quickshell.screens.find(screen=>screen.name===shellState.primaryScreen)||null):shell.controlScreen
  anchorCenterX:shell.baseline?(shell.controlRail?shell.controlRail.controlAnchorX:(targetScreen?targetScreen.width/2:0)):shell.controlCenterX
  requestedOpen:shellState.activePrimary==="control" && shellState.primaryScreen===(targetScreen?targetScreen.name:"")
  preferredWidth:1120;preferredHeight:820;title:"CONTROL CENTRE CLOSING QA"
  onCloseRequested:shellState.closePrimary()
 }
 property var openingRect:null
 property var openingScreen:null
 property int opening:0
 property int exitSamples:0
 property bool requireAnimatedSamples:true
 function rectangle(){return {x:host.fitted.x,y:host.fitted.y,width:host.width,height:host.height,left:host.margins.left,bottom:host.margins.bottom};}
 function check(ok,msg){if(!ok){console.error("FAIL:",msg);Qt.exit(1);throw Error(msg);}}
 function closeButton(item){if((item.objectName==="control-close" || item.text==="×") && typeof item.clicked==="function")return item;for(const child of item.children || []){const found=closeButton(child);if(found)return found;}return null;}
 function open(){shellState.showPrimary("control",Quickshell.screens[0].name,"overview");settle.start();}
 Timer {interval:500;running:true;onTriggered:shell.open()}
 Timer {id:settle;interval:250;onTriggered:{
  shell.openingRect=shell.rectangle();shell.openingScreen=host.targetScreen;
  console.log("OPEN",shell.opening,JSON.stringify(shell.openingRect));
  const button=shell.closeButton(host.captureItem);shell.check(!!button,"real close button exists");input.mouseClick(button);
  shell.check(shellState.activePrimary==="" && shellState.primaryScreen==="","close immediately clears coordinator ownership");
  console.log("CLOSE",JSON.stringify(shell.rectangle()));
  shell.check(host.targetScreen===shell.openingScreen,"closing keeps owning native output");
  shell.check(JSON.stringify(shell.rectangle())===JSON.stringify(shell.openingRect),"closing keeps all placement and dimensions");
  shell.exitSamples=0;exitProbe.start();
 }}
 Timer {id:exitProbe;interval:8;repeat:true;onTriggered:{
  if(host.visible){shell.exitSamples++;shell.check(JSON.stringify(shell.rectangle())===JSON.stringify(shell.openingRect),"no geometry movement during exit");return;}
  stop();console.log("EXIT",shell.opening,shell.exitSamples);shell.check(!shell.requireAnimatedSamples || shell.exitSamples>0,"observed closing animation");
  if(++shell.opening===3){console.log("PASS: three close-button exits retain screen, size and margins through dismissal");Qt.quit();return;}
  rails.instances=[({screen:Quickshell.screens[0],controlAnchorX:Quickshell.screens[0].width-(shell.opening===1?900:1200)})];shell.open();
 }}
 Timer {interval:6000;running:true;onTriggered:shell.check(false,"close test deadline")}
}
