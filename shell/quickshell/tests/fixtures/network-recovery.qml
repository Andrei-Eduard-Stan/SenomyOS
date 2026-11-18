import QtQuick
import Quickshell
import "services"
Scope {
 id:test
 property int phase:0
 property int ticks:0
 NetworkProfiles {id:profiles;active:true;context:"fixture";retryBaseMs:20;helper:Quickshell.shellDir+"/tests/fixtures/network-recovery-provider.py"}
 function check(ok,msg){if(!ok)throw new Error(msg);}
 Timer {interval:30;repeat:true;running:true;onTriggered:{try{
  if(++test.ticks>160)throw new Error("Fixture deadline phase "+test.phase+": "+profiles.error);
  if(test.phase===0){if(profiles.providerIdentity!=="first")return;check(profiles.actions.request("autoconnect",profiles.items[0]),"review");test.phase++;return;}
  if(test.phase===1){if(profiles.providerAvailable)return;check(profiles.items.length===0&&profiles.actions.actionState==="idle","provider loss clears inventory and pending review");test.phase++;return;}
  if(test.phase===2){if(profiles.providerIdentity!=="replacement"||profiles.failures!==1)return;check(!profiles.items[0].autoconnect,"replacement/external state reconciles without reopening");profiles.interpreter="/fixture-missing-python";check(profiles.openEditor("all",""),"inert missing-editor start");test.phase++;return;}
  if(test.phase===3){if(profiles.editorPending)return;check(profiles.message.indexOf("could not start")>=0,"editor failure feedback");check(profiles.actions.request("autoconnect",profiles.items[0]),"review after failure");check(profiles.actions.confirm(),"missing action process start");test.phase++;return;}
  if(test.phase===4){if(profiles.actions.actionState==="running")return;check(profiles.actions.actionState==="failed"&&!profiles.busy,"missing dependency unlocks actions");profiles.queryEnabled=false;test.phase++;return;}
  console.log("PASS: actual NetworkProfiles transport, late/replaced provider and external profiles, worker restart, editor/action startup errors and cleanup; inert observer only");Qt.quit();
 }catch(e){console.error("FAIL: "+e.message+" "+e.stack);Qt.exit(1);}}}
}
