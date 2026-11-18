import QtQuick
import QtTest
import "../services"

TestCase {
    name:"DisplayActions"
    QtObject {id:provider;property int calls:0;property var last:null;property bool accept:true;function runDisplayOperation(op,arg){if(!accept)return false;calls++;last={operation:op,argument:arg};return true;}}
    DisplayActions {id:actions;provider:provider}
    function init(){actions.reset();actions.context="display-screen";provider.calls=0;provider.accept=true;}
    function test_request_cancel_never_writes(){verify(actions.requestTopology([{name:"A"}],"digest",""));compare(provider.calls,0);verify(actions.cancel());compare(provider.calls,0);}
    function test_confirm_exactly_once(){actions.requestTopology([{name:"A"}],"digest","");verify(actions.confirm());verify(!actions.confirm());compare(provider.calls,1);compare(provider.last.operation,"apply-topology");}
    function test_keep_and_new_request(){actions.requestTopology([],"digest","");actions.confirm();actions.applied("token",Date.now()+15000);verify(actions.keep());compare(provider.last.operation,"keep");actions.completed("committed","saved");verify(actions.requestTopology([],"next",""));}
    function test_revert_and_watchdog_result(){actions.applied("token",Date.now()+15000);verify(actions.revert());compare(provider.last.operation,"revert");actions.observe({state:"reverted",token:"token",message:"restored"});compare(actions.actionState,"reverted");compare(actions.token,"");}
    function test_pending_context_loss_cancels(){actions.requestTopology([],"digest","");actions.context="";compare(actions.actionState,"idle");compare(provider.calls,0);}
    function test_preview_context_loss_keeps_recovery_reachable(){actions.applied("token",Date.now()+15000);actions.context="";compare(actions.actionState,"revert-pending");compare(actions.token,"token");}
    function test_operation_review_and_error(){actions.requestOperation("workspace",{action:"move",id:4,monitor:"B"},"Move");compare(provider.calls,0);verify(actions.confirm());compare(provider.last.operation,"workspace");actions.fail("rejected");compare(actions.actionState,"failed");verify(actions.requestOperation("profile-delete",{id:"x"},"Delete"));}
    function test_busy_provider_fails_honestly(){provider.accept=false;actions.requestTopology([],"digest","");verify(!actions.confirm());compare(actions.actionState,"failed");}
    function test_recover_preview_after_shell_recreation(){actions.observe({state:"preview",token:"survives",deadline:Date.now()+5000});compare(actions.actionState,"revert-pending");compare(actions.token,"survives");}
    function test_acknowledge_visible_fallback_is_explicit_and_clears_failure(){verify(!actions.acceptRecovery());compare(provider.calls,0);actions.observe({state:"recovery-failed",token:"failed-token",message:"Original mode unavailable"});verify(actions.acceptRecovery());compare(provider.last.operation,"accept-recovery");actions.observe({state:"recovered-safe",token:"failed-token",message:"Session only; nothing saved"});compare(actions.actionState,"recovered-safe");compare(actions.token,"");}
    function test_late_terminal_state_cannot_clear_current_recovery(){actions.applied("new-token",Date.now()+15000);actions.observe({state:"committed",token:"old-token"});compare(actions.actionState,"revert-pending");compare(actions.token,"new-token");actions.observe({state:"committed",token:"new-token"});compare(actions.actionState,"committed");compare(actions.token,"");}
    function test_failed_recovery_keeps_token_until_resolved(){actions.observe({state:"recovery-failed",token:"repair",message:"Retry recovery"});verify(!actions.requestTopology([],"digest",""));verify(!actions.requestOperation("workspace",{action:"move"},"Move"));compare(actions.token,"repair");verify(actions.revert());compare(provider.last.operation,"revert");}
    function test_previous_session_abandonment_releases_token(){actions.applied("previous-session",Date.now()+15000);actions.observe({state:"abandoned",message:"Compositor session changed"});compare(actions.actionState,"abandoned");compare(actions.token,"");}
}
