import QtQuick
import Quickshell
import "services"
Scope {
 id:test
 property int phase:0
 property int ticks:0
 AccountService {id:accounts;active:true;context:"fixture";retryBaseMs:20;helper:Quickshell.shellDir+"/tests/fixtures/account-service-fake.py"}
 function check(ok,msg){if(!ok)throw new Error(msg);}
 Timer {interval:30;repeat:true;running:true;onTriggered:{try{
  if(++test.ticks>160)throw new Error("Account fixture deadline phase "+test.phase+": "+accounts.message);
  if(test.phase===0){if(!accounts.available||accounts.loading)return;check(accounts.request("name",accounts.accounts[0],"Typed"),"review");test.phase++;return;}
  if(test.phase===1){if(accounts.actionState!=="failed"||accounts.failures!==1||!accounts.available||accounts.loading)return;check(accounts.accounts[0].name==="External","external state/restart reconciled without overwriting edits");check(!accounts.confirm(),"stale review refuses");check(accounts.request("create",null,"new_fixture")&&accounts.confirm(),"inert nonzero worker request");test.phase++;return;}
  if(test.phase===2){if(accounts.actionState==="running"||accounts.loading)return;check(accounts.actionState==="unverified"&&accounts.accounts[0].name==="External","nonzero success/stale readback refused");check(accounts.request("lock",accounts.accounts[1],"true")&&accounts.confirm(),"inert cancelled authorization");test.phase++;return;}
  if(test.phase===3){if(accounts.actionState==="running"||accounts.loading)return;check(accounts.actionState==="cancelled","cancellation retained as distinct status");accounts.interpreter="/fixture-missing-python";check(accounts.request("name",accounts.accounts[0],"Typed")&&accounts.confirm(),"missing worker start");test.phase++;return;}
  if(test.phase===4){if(accounts.actionState==="running")return;check(accounts.actionState==="failed"&&!accounts.locked,"failed start releases busy");accounts.active=false;accounts.interpreter="python3";test.phase++;return;}
  if(test.phase===5){accounts.active=true;test.phase++;return;}
  if(test.phase===6){if(!accounts.available||accounts.loading)return;const old=Object.assign({},accounts.snapshot,{observedAtMs:accounts.observedAt-1,accounts:[]});accounts.adopt(old);check(accounts.accounts.length===2,"old response cannot replace current state");accounts.active=false;test.phase++;return;}
  console.log("PASS: actual AccountService provider/external updates, stale review/readback, worker recovery, cancellation, nonzero exit, missing dependency and inactive cleanup; inert account transport only");Qt.quit();
 }catch(e){console.error("FAIL: "+e.message+" "+e.stack);Qt.exit(1);}}}
}
