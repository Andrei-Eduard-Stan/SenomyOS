import QtQuick
import QtTest
import "../services"

TestCase {
    id: test
    name: "NetworkActions"
    width: 640
    height: 320
    QtObject { id: radio; property bool wifiEnabled: true }
    QtObject { id: replacementRadio; property bool wifiEnabled: true }
    QtObject { id: adapter }
    QtObject { id: replacementAdapter }
    QtObject {
        id: network
        property string name: "Fixture <b>network</b>"
        property bool connected: true
        property bool stateChanging: false
        property int calls: 0
        property bool reject: false
        function disconnect() { if (reject) throw new Error("fixture rejection"); calls++; }
    }
    QtObject { id: otherNetwork; property string name: "Other fixture"; property bool connected: true; property bool stateChanging: false }
    QtObject {
        id: provider
        property var radio: null
        property bool available: true
        property bool wifiHardwareEnabled: true
        property bool wifiEnabled: radio !== null && radio.wifiEnabled
        property var wifiDevices: []
        property var wifiNetworks: []
    }
    NetworkActions { id: guard; provider: provider }
    function init() {
        guard.actionState = "idle";
        guard.clearTargets();
        guard.context = "fixture-screen";
        guard.timeoutMs = 30000;
        radio.wifiEnabled = true;
        replacementRadio.wifiEnabled = true;
        provider.radio = radio;
        provider.available = true;
        provider.wifiHardwareEnabled = true;
        provider.wifiDevices = [adapter];
        provider.wifiNetworks = [network];
        network.connected = true;
        network.stateChanging = false;
        network.calls = 0;
        network.reject = false;
    }
    function test_request_cancel_no_mutation() {
        verify(guard.request("disable", null));
        compare(radio.wifiEnabled, true);
        verify(guard.cancel());
        verify(!guard.confirm());
        verify(guard.request("disconnect", network));
        verify(guard.cancel());
        compare(network.calls, 0);
    }
    function test_confirm_once_and_observed_result() {
        verify(guard.request("disconnect", network));
        verify(guard.confirm());
        verify(!guard.confirm());
        verify(!guard.request("disable", null));
        compare(network.calls, 1);
        guard.observe();
        compare(guard.actionState, "running");
        network.connected = false;
        network.stateChanging = true;
        guard.observe();
        compare(guard.actionState, "running");
        network.stateChanging = false;
        guard.observe();
        compare(guard.actionState, "succeeded");
    }
    function test_disable_confirm() {
        verify(guard.request("disable", null));
        verify(guard.confirm());
        compare(radio.wifiEnabled, false);
        guard.observe();
        compare(guard.actionState, "succeeded");
    }
    function test_disconnected_target_not_reconnected() {
        verify(guard.request("disconnect", network));
        network.connected = false;
        verify(!guard.confirm());
        compare(network.calls, 0);
    }
    function test_removed_network() {
        verify(guard.request("disconnect", network));
        provider.wifiNetworks = [];
        verify(!guard.confirm());
        compare(network.calls, 0);
    }
    function test_replaced_adapter() {
        verify(guard.request("disable", null));
        provider.wifiDevices = [replacementAdapter];
        verify(!guard.confirm());
        compare(radio.wifiEnabled, true);
    }
    function test_replaced_provider() {
        verify(guard.request("disable", null));
        provider.radio = replacementRadio;
        verify(!guard.confirm());
        compare(replacementRadio.wifiEnabled, true);
    }
    function test_disable_rejects_connection_changes() {
        verify(guard.request("disable", null));
        provider.wifiNetworks = [otherNetwork];
        verify(!guard.confirm());
        compare(radio.wifiEnabled, true);
    }
    function test_hardware_block() {
        verify(guard.request("disable", null));
        provider.wifiHardwareEnabled = false;
        verify(!guard.confirm());
        compare(radio.wifiEnabled, true);
    }
    function test_route_or_screen_change_cancels_pending() {
        verify(guard.request("disable", null));
        guard.context = "";
        compare(guard.actionState, "idle");
        verify(!guard.confirm());
        compare(radio.wifiEnabled, true);
        guard.context = "screen-a";
        verify(guard.request("disconnect", network));
        guard.context = "screen-b";
        verify(!guard.confirm());
        compare(network.calls, 0);
    }
    function test_running_survives_route_dismissal() {
        verify(guard.request("disconnect", network));
        verify(guard.confirm());
        guard.context = "";
        compare(guard.actionState, "running");
        network.connected = false;
        guard.observe();
        compare(guard.actionState, "succeeded");
    }
    function test_failure_timeout_and_provider_loss() {
        verify(guard.request("disconnect", network));
        network.reject = true;
        verify(!guard.confirm());
        compare(guard.actionState, "failed");
        network.reject = false;
        verify(guard.request("disconnect", network));
        verify(guard.confirm());
        guard.deadline = 0;
        guard.observe();
        compare(guard.actionState, "failed");
        verify(guard.request("disconnect", network));
        verify(guard.confirm());
        provider.available = false;
        guard.observe();
        compare(guard.actionState, "failed");
    }
    function test_invalid_and_changing_targets() {
        verify(!guard.request("anything", network));
        network.stateChanging = true;
        verify(!guard.request("disconnect", network));
        verify(!guard.request("disable", null));
        compare(network.calls, 0);
        compare(radio.wifiEnabled, true);
    }
}
