import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "components"
import "services"
Window {
 id:test;visible:true;width:432;height:650;color:"#0a0c0f"
 TestCase {id:input;when:false}
 PowerService {id:service;helper:Quickshell.shellDir+"/tests/fixtures/session-fake-backend.py";active:true}
 PowerContents {id:contents;anchors.fill:parent;anchors.margins:24;service:service}
 function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
 function waitFor(fn,message){for(let i=0;i<150&&!fn();i++)input.wait(20);check(fn(),message);}
 Process {id:receiptWriter}
 Timer {interval:200;running:true;onTriggered:{
  test.waitFor(()=>service.available,"production provider consumes status JSON");
  service.available=false;test.check(!service.supported("lock")&&!service.request("lock"),"unavailable provider refuses actions even with cached capabilities");service.available=true;
  service.prepare({action:"lock",mode:"delay",seconds:"0"});test.waitFor(()=>service.state==="failed","failed helper reply mapped");test.check(service.fieldErrors.seconds==="Use a positive countdown.","field map transported");
  service.prepare({action:"lock",mode:"delay",seconds:"1800"});test.waitFor(()=>!!service.review,"review process reply consumed");test.check(service.state==="pending"&&!service.hasSchedule,"prepare never reports an armed timer");
  service.confirm();test.waitFor(()=>service.state==="succeeded"&&service.hasSchedule,"explicit commit transported");test.check(contents.mode==="now","successful schedule returns to concise status view");
  const factory=Qt.createComponent(Quickshell.shellDir+"/services/PowerService.qml");test.check(factory.status===Component.Ready,"provider component ready for UI reload");const reloaded=factory.createObject(test,{helper:service.helper});test.waitFor(()=>reloaded.available&&reloaded.hasSchedule,"recreated QML provider restores pending schedule");test.check(reloaded.schedule.id===service.schedule.id&&reloaded.remainingText===service.remainingText,"same-session UI recovery shares authoritative identity and time");reloaded.destroy();input.wait(30);
  const id=service.schedule.id;service.requestCancellation();test.check(service.state==="pending"&&service.hasSchedule,"cancellation is reviewed");service.cancel();test.check(service.hasSchedule,"Back preserves timer");
  service.requestCancellation();service.confirm();test.waitFor(()=>service.schedule.state==="cancelled","confirmed cancellation consumed");
  test.waitFor(()=>!service.busy,"cancellation worker finished");service.request("lock");service.cancel();input.wait(200);test.check(service.state==="idle"&&service.review===null,"late prepare reply cannot reopen cancelled review");
  service.refresh();test.waitFor(()=>service.schedule.state==="cancelled","refresh does not resurrect timer");
  service.active=false;receiptWriter.exec(["python3","-c","import json,os,pathlib; p=pathlib.Path(os.environ['XDG_RUNTIME_DIR'])/'senomyos/session-schedule.json'; tmp=p.with_suffix('.tmp'); tmp.write_text(json.dumps({'id':'external-result','state':'failed','message':'Private deadline failed'})); tmp.replace(p)"]);
  test.waitFor(()=>service.schedule.id==="external-result"&&service.schedule.state==="failed","atomic receipt changes observed without active polling");
  console.log("PASS: production provider typed subprocess protocol, field errors, explicit commits/cancellation, cancelled-review race and receipt refresh");Qt.quit();
 }}
}
