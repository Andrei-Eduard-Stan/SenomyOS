import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components/notifications" as Notifications
import "config" as Config
Window {
 id:test;visible:true;width:560;height:900
 TestCase {id:input;when:false}
 QtObject {id:guard;property bool locked:false}
 QtObject {
  id:provider;property var clearActions:guard;property var history:[];property int dismissals:0;property int reads:0
  function markRead(record){reads++;history=history.map(r=>r.id===record.id?Object.assign({},r,{unread:false}):r);}
  function dismiss(record){dismissals++;history=history.filter(r=>r.id!==record.id);}
  function isLive(record){return false;}
 }
 Notifications.NotificationQuickList {id:list;width:520;x:20;y:20;notifications:provider}
 function record(id){return {id:id,receivedAt:id,appName:"Inert fixture",summary:"Message "+id,body:"Synthetic retained record",unread:true,actions:[]};}
 function named(name){return input.findChild(list,name);}
 function check(ok,why){if(!ok)throw Error(why);}
 Timer {interval:300;running:true;onTriggered:{try{
  provider.history=[test.record(3),test.record(2),test.record(1)];input.wait(250);
  const first=test.named("notification-open-0"),second=test.named("notification-open-1");
  input.mouseClick(first);input.wait(100);
  test.check(test.named("notification-open-0")===first && provider.reads===1,"read status preserves record delegate and exact read");
  list.back();input.wait(30);second.forceActiveFocus();provider.history=provider.history.slice(1);input.wait(250);
  test.check(test.named("notification-open-0")===second && second.activeFocus,"removing another record preserves delegate and keyboard focus");
  provider.history=[test.record(4)].concat(provider.history);input.wait(250);
  test.check(test.named("notification-open-1")===second && second.activeFocus,"arrival preserves existing record and focus");
  input.mouseClick(second);input.wait(80);input.mouseClick(test.named("notification-dismiss-1"));input.wait(250);
  test.check(provider.dismissals===1 && !provider.history.some(r=>r.id===2),"dismiss targets only selected version");
  list.filterMode="unread";list.search="Message 1";input.wait(250);
  test.check(list.filteredHistory.length===1 && list.filteredHistory[0].id===1,"search and unread filters remain coherent");
  const saved=Config.Skin.registry;Config.Skin.registry=Object.assign({},saved,{persona:Object.assign({},saved.persona || {},{reducedMotion:true})});provider.history=[test.record(1),test.record(5)];input.wait(40);
  test.check(test.named("notification-open-0").opacity===1,"reduced disclosure is immediately visible");
  Config.Skin.registry=saved;
  console.log("PASS: actual inbox read/dismiss identity, unaffected delegate and keyboard-focus retention on removal/arrival, search/unread and reduced motion; fake records only");Qt.quit();
 }catch(e){console.error("FAIL:",e);Qt.exit(1);}}}
}
