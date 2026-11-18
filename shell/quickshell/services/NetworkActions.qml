import QtQuick

// Provider-injected: fixture tests never load NetworkManager or native radios.
QtObject {
    id: root
    required property var provider
    property string context: ""
    property string actionState: "idle"
    property string action: ""
    property string targetName: ""
    property string message: ""
    property var target: null
    property string requestedProviderIdentity:""
    property var requestedRadio: null
    property var requestedDevices: []
    property var requestedConnections: []
    property double deadline: 0
    property int timeoutMs: 30000
    readonly property bool busy: actionState === "running"
    readonly property bool locked: busy || actionState === "pending"
    readonly property string impact: action === "disable"
        ? "Disable Wi-Fi on all adapters. Wireless calls, downloads and remote sessions may stop. Re-enable Wi-Fi to reconnect."
        : "Disconnect this Wi-Fi network. Calls, downloads and remote sessions using it may stop. You can reconnect from this page."

    function sameObjects(left, right) {
        return left.length === right.length && left.every(item => right.indexOf(item) >= 0);
    }

    function currentConnections() {
        return provider.wifiNetworks.filter(network => network.connected);
    }

    function valid() {
        if (!context || !provider.available || !provider.wifiEnabled || !provider.wifiHardwareEnabled
                || (provider.providerIdentity || "") !== requestedProviderIdentity || provider.radio !== requestedRadio || requestedDevices.length === 0
                || !sameObjects(requestedDevices, provider.wifiDevices))
            return false;
        if (action === "disable")
            return sameObjects(requestedConnections, currentConnections())
                && !provider.wifiNetworks.some(network => network.stateChanging);
        return action === "disconnect" && target && provider.wifiNetworks.indexOf(target) >= 0
            && target.connected && !target.stateChanging;
    }

    function request(verb, network) {
        if (locked || provider.profileActionsLocked || provider.connectionAttemptBusy || ["disable", "disconnect"].indexOf(verb) < 0) return false;
        action = verb;
        target = verb === "disconnect" ? network : null;
        requestedProviderIdentity = provider.providerIdentity || "";
        requestedRadio = provider.radio;
        requestedDevices = provider.wifiDevices.slice();
        requestedConnections = currentConnections();
        targetName = target ? target.name || "Wi-Fi network"
            : "All Wi-Fi adapters" + (requestedConnections.length
                ? " · " + requestedConnections.map(item => item.name || "Wi-Fi network").join(", ") : "");
        if (!valid()) return fail("The network or adapter is unavailable or changing. Select it again.");
        actionState = "pending";
        message = "Review the target and impact before confirming.";
        return true;
    }

    function clearTargets() {
        target = null;
        requestedRadio = null;
        requestedDevices = [];
        requestedConnections = [];
    }

    function cancel() {
        if (actionState !== "pending") return false;
        actionState = "idle";
        action = "";
        message = "";
        clearTargets();
        return true;
    }

    function fail(reason) {
        actionState = "failed";
        message = reason;
        clearTargets();
        return false;
    }

    function confirm() {
        if (actionState !== "pending") return false;
        if (!valid()) return fail("The target changed since the preview. Nothing was changed; select it again.");
        actionState = "running";
        message = "Waiting for NetworkManager to report the result…";
        deadline = Date.now() + timeoutMs;
        try {
            if (action === "disable") requestedRadio.wifiEnabled = false;
            else target.disconnect();
        } catch (error) {
            return fail("NetworkManager rejected the request. Check current network state before retrying.");
        }
        return true;
    }

    function observe() {
        if (!busy) return;
        if (!provider.available || (provider.providerIdentity || "") !== requestedProviderIdentity || provider.radio !== requestedRadio
                || !sameObjects(requestedDevices, provider.wifiDevices)) {
            fail("The network provider or adapter changed; completion could not be verified.");
            return;
        }
        if (action === "disconnect" && (!target || provider.wifiNetworks.indexOf(target) < 0)) {
            fail("The network disappeared; completion could not be verified.");
            return;
        }
        const complete = action === "disable" ? !provider.wifiEnabled
            : !target.connected && !target.stateChanging;
        if (complete) {
            actionState = "succeeded";
            message = "NetworkManager reported the requested state.";
            clearTargets();
        } else if (Date.now() >= deadline) {
            fail("NetworkManager did not report completion in time. The request may still finish; check current state before retrying.");
        }
    }

    onContextChanged: cancel()
    property Timer observer: Timer {
        interval: 250
        repeat: true
        running: root.busy
        onTriggered: root.observe()
    }
}
