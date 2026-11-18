import QtQuick
import QtTest
import "../services"
TestCase {
    id:test;name:"ConnectionAttempt";when:true
    QtObject {id:network;property string name:"Fixture";property bool connected:false;property bool stateChanging:false;signal connectionFailed(int reason)}
    QtObject {id:provider;property string providerIdentity:"owner1";property bool available:true;property bool wifiEnabled:true;property bool wifiHardwareEnabled:true;property var wifiNetworks:[network];function failureMessage(reason){return reason===1?"Authentication rejected":"Network failed";}}
    ConnectionAttempt {id:attempt;provider:provider}
    function init(){attempt.target=null;attempt.actionState="idle";attempt.message="";provider.available=true;provider.wifiEnabled=true;provider.wifiHardwareEnabled=true;provider.wifiNetworks=[network];network.name="Fixture";network.connected=false;network.stateChanging=false;}
    function test_single_attempt_and_reported_connection(){verify(attempt.start(network));verify(!attempt.start(network));network.connected=true;tryCompare(attempt,"actionState","succeeded");verify(attempt.message.indexOf("Internet reachability")>=0);}
    function test_signal_failure_and_stale_signal_ignored(){verify(attempt.start(network));network.connectionFailed(1);compare(attempt.actionState,"failed");compare(attempt.message,"Authentication rejected");network.connectionFailed(2);compare(attempt.message,"Authentication rejected");}
    function test_timeout_is_unverified_never_success(){verify(attempt.start(network));attempt.deadline=Date.now()-1;attempt.observe();compare(attempt.actionState,"unverified");network.connected=true;compare(attempt.actionState,"unverified");}
    function test_provider_membership_and_name_changes(){
        verify(attempt.start(network));provider.wifiNetworks=[];attempt.observe();compare(attempt.actionState,"failed");
        provider.wifiNetworks=[network];verify(attempt.start(network));network.name="Changed";tryCompare(attempt,"actionState","failed");
    }
    function test_unavailable_connected_and_changing_rejected(){provider.available=false;verify(!attempt.start(network));provider.available=true;network.connected=true;verify(!attempt.start(network));network.connected=false;network.stateChanging=true;verify(!attempt.start(network));}    function test_provider_replacement_refuses_completion(){provider.providerIdentity="owner1";verify(attempt.start(network));provider.providerIdentity="owner2";attempt.observe();compare(attempt.actionState,"failed");}

}
