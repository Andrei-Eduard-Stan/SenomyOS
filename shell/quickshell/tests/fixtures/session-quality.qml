import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "components"
import "services"
import "config" as Config
Window {
 id:test;visible:true;width:640;height:740;color:Config.QuickPanelStyle.surface
 TestCase {id:input;when:false}
 PowerService {id:provider;helper:Quickshell.shellDir+"/tests/fixtures/session-fake-backend.py"}
 PowerContents {id:contents;anchors.fill:parent;anchors.margins:24;service:provider}
 Process {id:receiptWriter}
 function publish(record){
  waitFor(()=>!receiptWriter.running,"fixture writer ready");receiptWriter.exec(["python3","-c","import os,pathlib,sys; p=pathlib.Path(os.environ['XDG_RUNTIME_DIR'])/'senomyos/session-schedule.json'; t=p.with_suffix('.tmp'); t.write_text(sys.argv[1]); t.replace(p)",JSON.stringify(record)]);
  waitFor(()=>provider.schedule.id===record.id&&provider.schedule.state===record.state,"external schedule state observed");waitFor(()=>!receiptWriter.running,"fixture writer exited");
 }
 function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
 function waitFor(fn,message){for(let i=0;i<150&&!fn();i++)input.wait(20);check(fn(),message);}
 function capture(name){input.wait(180);let done=false;test.contentItem.grabToImage(result=>{check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture saved");done=true;});for(let i=0;i<150&&!done;i++)input.wait(10);check(done,"capture finished");}
 function click(name){const item=input.findChild(contents,name);check(!!item&&item.visible&&item.enabled,name+" available");item.forceActiveFocus();input.wait(70);input.keyClick(Qt.Key_Return);input.wait(70);}
 Timer {interval:300;running:true;onTriggered:{
  test.waitFor(()=>provider.available,"provider ready");test.check(!contents.selectedAction&&contents.mode==="now"&&!contents.stacked,"idle is unselected and dual chamber");test.check(!input.findChild(contents,"session-review-schedule").visible,"idle has no disabled action button");test.capture("idle-640");
  input.findChild(contents,"session-action-lock").forceActiveFocus();input.keyClick(Qt.Key_Down);test.check(input.findChild(contents,"session-action-suspend").activeFocus,"Down navigates stable commands without selecting");input.keyClick(Qt.Key_Up);test.check(input.findChild(contents,"session-action-lock").activeFocus&&!contents.selectedAction,"Up preserves unselected idle");
  let previousY=-1;const actionX=[];
  for(const action of ["lock","suspend","logout","reboot","poweroff"]){
   const row=input.findChild(contents,"session-action-"+action),pos=row.mapToItem(contents,0,0);test.check(pos.y>previousY,"stable vertical command order");previousY=pos.y;actionX.push(pos.x);test.click("session-action-"+action);test.check(contents.selectedAction===action&&provider.state==="idle","all commands update execution without dispatch");
  }
  test.check(actionX.every(x=>x===actionX[0]),"commands share one vertical chamber");test.click("session-action-reboot");test.capture("selected-now-640");
  const nav=input.findChild(contents,"session-action-chamber"),navHeight=nav.height;test.click("session-review-schedule");test.waitFor(()=>!!provider.review,"immediate review");test.check(input.findChild(contents,"powerCancel").activeFocus,"review defaults to Back");test.check(nav.visible&&nav.height===navHeight,"command chamber remains stable through review");test.capture("review-now-640");test.click("session-confirm");test.waitFor(()=>provider.state==="succeeded"&&!provider.busy,"Restart now confirm dry-run");
  test.click("session-action-reboot");test.click("session-mode-schedule");test.capture("countdown-640");test.check(input.findChild(contents,"session-execution-preview").text==="In 30 minutes","draft duration preview");test.click("session-review-schedule");test.waitFor(()=>!!provider.review,"countdown review");test.check(provider.review.form.seconds==="1800","HH MM SS one duration");test.capture("review-schedule-640");test.click("session-confirm");test.waitFor(()=>provider.hasSchedule&&provider.state==="succeeded"&&!provider.busy,"schedule committed");test.check(contents.monitoring&&!contents.editorOpen&&!input.findChild(contents,"session-mode-now").visible,"active monitor replaces editor");test.capture("scheduled-640");
  contents.surfaceOpen=false;contents.surfaceOpen=true;input.wait(100);test.check(provider.hasSchedule&&contents.monitoring,"reopen returns to schedule monitor");
  test.click("session-change");test.check(contents.mode==="schedule"&&contents.method==="delay"&&contents.selectedAction==="reboot"&&!contents.monitoring,"edit restores action and countdown");
  test.click("session-action-lock");test.check(provider.schedule.action==="reboot","selection preserves original commitment");test.click("session-review-schedule");test.waitFor(()=>!!provider.review,"replacement review");test.check(provider.review.replaces.length>0,"replacement explicit");test.capture("review-replace-640");test.click("powerCancel");test.check(provider.schedule.action==="reboot","Back preserves original");
  test.click("session-view-active");test.click("session-postpone-600");test.waitFor(()=>provider.remainingSeconds===2400&&!provider.busy,"postpone ten minutes");test.click("session-postpone-1800");test.waitFor(()=>provider.remainingSeconds===4200&&!provider.busy,"postpone thirty minutes");
  test.click("session-execute-now");test.waitFor(()=>!!provider.review,"Execute now reviews");test.click("powerCancel");test.check(provider.hasSchedule&&contents.monitoring,"Back returns to monitor");
  test.click("session-cancel-timer");test.waitFor(()=>!provider.hasSchedule&&!provider.busy,"direct cancellation");
  test.click("session-action-reboot");test.click("session-mode-schedule");input.findChild(contents,"session-hours").text="00";input.findChild(contents,"session-minutes").text="00";input.findChild(contents,"session-seconds").text="00";test.click("session-review-schedule");test.waitFor(()=>!!provider.fieldErrors.seconds,"zero duration rejected");test.capture("error-640");
  provider.clearFeedback();test.click("session-mode-at");test.check(input.findChild(contents,"session-execution-preview").text.indexOf("LOCAL")>=0,"date/time local context visible");test.capture("date-time-640");
  test.width=390;test.height=650;input.wait(40);test.check(contents.stacked,"narrow layout stacks chambers");test.capture("date-time-390");test.height=320;test.capture("short-390");
  test.height=650;provider.clearFeedback();input.findChild(contents,"session-date-editor").text="2026-11-02";input.findChild(contents,"session-time").text="18:30";test.click("session-review-schedule");test.waitFor(()=>!!provider.review,"absolute review");test.click("session-confirm");test.waitFor(()=>provider.schedule.mode==="at"&&!provider.busy,"absolute commit");test.click("session-change");test.check(contents.method==="at","edit preserves absolute type");test.click("session-view-active");test.click("session-execute-now");test.waitFor(()=>!!provider.review,"review current instruction now");test.click("session-confirm");test.waitFor(()=>provider.schedule.state==="succeeded"&&!provider.busy,"Execute now completes commitment");
  publish({id:"missed-fixture",state:"missed",action:"reboot",label:"Restart",mode:"at",dueLabel:"Yesterday, 18:30 GMT",message:"Missed while unavailable. Nothing was run."});contents.surfaceOpen=false;contents.surfaceOpen=true;input.wait(100);test.check(contents.monitoring,"missed instruction restores safe monitor");test.capture("missed-390");
  publish(Object.assign({},provider.schedule,{state:"failed",message:"System permission refused the request."}));test.capture("failed-390");
  publish({});provider.clearFeedback();contents.surfaceOpen=false;contents.surfaceOpen=true;input.wait(100);test.check(!contents.selectedAction&&contents.mode==="now","opening without pending instruction resets selection");
  Config.DirectoryStyle.touchMode=true;test.width=680;test.height=740;test.capture("touch-680");Config.DirectoryStyle.touchMode=false;
  provider.available=false;provider.schedulingAvailable=false;provider.unavailableReason="The session manager is unavailable.";test.capture("unavailable-680");provider.available=true;provider.schedulingAvailable=true;
  const registry=Config.Skin.registry;Config.Skin.registry=Object.assign({},registry,{persona:Object.assign({},registry.persona||{},{uiTextScale:1.5,reducedMotion:true})});test.width=390;test.height=540;test.capture("large-text-reduced-motion-390");Config.Skin.registry=registry;
  console.log("PASS: dual chambers, all five commands, exclusive execution states, confirmations, scheduling, management, local context, keyboard and responsive layouts");Qt.quit();
 }}
}
