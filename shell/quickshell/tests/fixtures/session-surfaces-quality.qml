import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services"
import "config" as Config
Window {
 id:test;visible:true;width:1144;height:740;color:"#141618"
 property int opens:0
 TestCase {id:input;when:false}
 PowerService {id:service;helper:Quickshell.shellDir+"/tests/fixtures/session-fake-backend.py"}
 NotificationService {id:notice;sessionService:service;onOpenSessionRequested:test.opens++}
 CathedralPopupFrame {
  x:8;y:8;width:640;height:700;frameKey:"power";tier:"standard";motif:"power";animate:false
  PowerContents {id:contents;anchors.fill:parent;service:service}
 }
 NotificationCenter {id:center;x:680;y:8;width:432;height:630;notifications:notice}
 PowerIsland {id:rail;x:860;y:665;powerService:service}
 NotificationToast {id:toast;x:680;y:8;width:432;height:350;targetScreen:({width:1144,height:740});notifications:notice;placementEnabled:true;visible:showCommitment}
 function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
 function waitFor(fn,message){for(let i=0;i<150&&!fn();i++)input.wait(20);check(fn(),message);}
 function capture(name){input.wait(60);let done=false;test.contentItem.grabToImage(result=>{check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture");done=true;});for(let i=0;i<150&&!done;i++)input.wait(10);check(done,"capture complete");}
 Timer {interval:300;running:true;onTriggered:{
  test.waitFor(()=>service.available,"provider ready");service.prepare({action:"reboot",mode:"delay",seconds:"1800"});test.waitFor(()=>!!service.review,"review");service.confirm();test.waitFor(()=>service.hasSchedule&&!service.busy,"commit");
  const pinned=input.findChild(center,"system-commitment");test.check(!!pinned&&pinned.visible&&notice.commitment.id===service.schedule.id,"one pinned system commitment in existing notification renderer");
  test.check(input.findChild(rail,"rail-session-countdown").text===service.remainingText,"Rail reads shared remaining time");test.check(input.findChild(contents,"session-countdown").text==="T−"+service.remainingText,"Session reads shared remaining time");
  notice.dnd=true;test.check(pinned.visible&&!toast.showCommitment,"DND preserves pin without overlay");notice.dnd=false;test.capture("shared-session-notification-rail");
  pinned.openSessionRequested();test.check(test.opens===1,"pinned record opens authoritative session interface");
  center.requestedOpen=false;center.requestedOpen=true;test.check(notice.commitment.id===service.schedule.id,"notification reopen never duplicates commitment");
  for(const remaining of [600,300,60,10]){
   service.schedule=Object.assign({},service.schedule,{remainingSeconds:remaining,progress:remaining/1800,urgency:remaining<=10?"final":remaining<=60?"critical":remaining<=300?"warning":"approaching"});input.wait(30);
   test.check(service.remainingText===input.findChild(rail,"rail-session-countdown").text,"all urgency thresholds share remaining time");
   if(remaining===60){test.check(toast.showCommitment,"critical warning appears");test.capture("critical-warning");notice.dnd=true;test.check(!toast.showCommitment,"DND suppresses critical overlay; pin remains");}
  }
  test.check(toast.showCommitment,"final ten-second safety countdown accessible through DND");test.capture("final-warning");toast.height=200;input.wait(30);const shortCancel=input.findChild(toast,"final-session-cancel");test.check(shortCancel.mapToItem(toast,0,0).y+shortCancel.height<=toast.height,"final Cancel remains visible in short work area");test.capture("final-warning-short");
  const cancel=input.findChild(toast,"final-session-cancel");input.mouseClick(cancel);test.waitFor(()=>!service.hasSchedule,"one-click final cancellation");test.check(notice.commitment===null&&!toast.showCommitment&&!pinned.visible,"all representations clear immediately");test.capture("cancelled-surfaces");
  console.log("PASS: shared Session, pinned notification, Rail, open/reopen, urgency thresholds, DND and final-warning one-click cancellation");Qt.quit();
 }}
}
