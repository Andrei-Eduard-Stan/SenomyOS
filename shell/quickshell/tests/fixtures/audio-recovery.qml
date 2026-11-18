import QtQuick
import Quickshell
import "services"
Scope {
 id: test
 property int phase: 0
 property int ticks: 0
 QtObject {id:pipe;property bool ready:true;property var nodes:({values:[]});property var linkGroups:({values:[]});property var defaultAudioSink:null;property var defaultAudioSource:null}
 AudioService {id:audio;pipewire:pipe;nativeProvider:false;persistenceEnabled:false;active:true;actionContext:"fixture";graphHelper:Quickshell.shellDir+"/tests/fixtures/audio-recovery-provider.py";graphRetryBaseMs:25;graphRetryLimit:2}
 function check(ok,why){if(!ok)throw new Error(why);}
 Timer {interval:50;repeat:true;running:true;onTriggered:{try{
  if(++test.ticks>160)throw new Error("Recovery fixture deadline phase "+test.phase+": "+audio.graphSnapshot.error);
  if(test.phase===0){if(!audio.graphSnapshot.available || audio.graphFailures!==1)return;check(audio.graphSnapshot.cards.length===1,"retry restores graph without closing view");test.phase++;return;}
  if(test.phase===1){check(audio.graphActions.request("profile",audio.graphSnapshot.cards[0],1,"Fixture profile"),"review");check(audio.graphActions.confirm(),"confirm");check(!audio.graphActions.confirm(),"single-flight");test.phase++;return;}
  if(test.phase===2){if(audio.graphActions.actionState==="running")return;check(audio.graphActions.actionState==="failed","nonzero worker cannot claim success");audio.active=false;test.phase++;return;}
  if(test.phase===3){if(audio.graphSnapshot.available)return;audio.graphInterpreter="/fixture-no-python";audio.active=true;test.phase++;return;}
  if(test.phase===4){if(audio.graphFailures<=audio.graphRetryLimit || audio.graphRetryScheduled)return;check(!audio.graphStarting && !audio.graphSnapshot.available,"missing interpreter settles and retries exhaust");audio.graphInterpreter="python3";check(audio.retryGraph(),"manual Retry without leaving page");test.phase++;return;}
  if(test.phase===5){if(!audio.graphSnapshot.available)return;check(audio.graphActions.request("profile",audio.graphSnapshot.cards[0],1,"Fixture"),"review after recovery");audio.graphInterpreter="/fixture-no-python";check(audio.graphActions.confirm(),"missing writer fixture");test.phase++;return;}
  if(test.phase===6){if(audio.graphActions.actionState==="running")return;check(audio.graphActions.actionState==="failed"&&!audio.graphWritePending,"missing writer releases busy state honestly");audio.active=false;test.phase++;return;}
  check(!audio.graphRetryScheduled,"no restart while inactive");console.log("PASS: actual AudioService watcher recovery, bounded retries/manual retry, nonzero result, missing interpreter, single-flight and inactive cleanup; inert provider only");Qt.quit();
 }catch(e){console.error("FAIL: "+e.message+" "+e.stack);Qt.exit(1);}}}
}
