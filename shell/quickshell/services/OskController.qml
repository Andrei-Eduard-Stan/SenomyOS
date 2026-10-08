import QtQuick

// Adapter contract: start(name, serial), owns(serial), show(serial), hide(serial),
// stop(serial). It must address only its own child, return boolean acceptance,
// and report started/exited/failed asynchronously with the same serial.
// No production adapter is connected until reload/shutdown ownership is proved.
QtObject {
    id: root
    required property var provider
    property var capabilities: ({providerInstalled:false,protocolState:"unknown",manualCandidate:false,provider:""})
    property string state: "unavailable"
    property string message: "OSK capability is unavailable."
    property int serial: 0
    property bool startPending: false
    readonly property bool owned: serial > 0 && provider && provider.owns(serial)
    property string previousState: "stopped"
    signal releasePrimaryFocusRequested()

    function available() {
        return capabilities && capabilities.providerInstalled === true
            && capabilities.protocolState === "advertised" && capabilities.manualCandidate === true
            && ["wvkbd-mobintl", "wvkbd-deskintl"].indexOf(capabilities.provider) >= 0;
    }
    function refreshState() {
        if (!owned && !startPending && state !== "failed") {
            state = available() ? "stopped" : "unavailable";
            message = available() ? "Provider candidate detected; no keyboard is running." : "OSK capability is unavailable or unknown.";
        }
    }
    onCapabilitiesChanged: refreshState()

    function requestShow() {
        if (startPending || (state === "pending-stop" || state === "stop-requested")) return false;
        if (owned) {
            if (!provider.show(serial)) { state = "failed"; message = "OSK show request failed."; return false; }
            state = "show-requested";
            message = "Show requested; surface visibility and text entry are unverified.";
            releasePrimaryFocusRequested();
            return true;
        }
        if (!available()) { state = "unavailable"; message = "OSK capability is unavailable or unknown."; return false; }
        serial++;
        startPending = true;
        state = "starting";
        message = "Starting owned keyboard provider…";
        if (!provider.start(capabilities.provider, serial)) {
            startPending = false; state = "failed"; message = "Keyboard provider could not be started.";
            return false;
        }
        startupTimer.restart();
        return true;
    }
    function started(id) {
        if (id !== serial || !startPending) return;
        startupTimer.stop();
        startPending = false;
        if (!owned) { state = "failed"; message = "Provider did not establish child ownership."; return; }
        state = "running";
        requestShow();
    }
    function failed(id) {
        if (id !== serial) return;
        startupTimer.stop(); startPending = false;
        state = "failed"; message = "Keyboard provider failed.";
    }
    function exited(id, successful) {
        if (id !== serial) return;
        startupTimer.stop(); startPending = false;
        state = successful ? (available() ? "stopped" : "unavailable") : "failed";
        message = successful ? "Owned keyboard exited." : "Owned keyboard exited unexpectedly.";
    }
    function requestHide() {
        if (startPending || (state === "pending-stop" || state === "stop-requested") || !owned) return false;
        if (!provider.hide(serial)) { state = "failed"; message = "OSK hide request failed."; return false; }
        state = "hide-requested"; message = "Hide requested; surface visibility is unverified.";
        return true;
    }
    function requestStop() {
        if (startPending || (state === "pending-stop" || state === "stop-requested") || !owned) return false;
        previousState = state;
        state = "pending-stop";
        message = "Stop the keyboard instance started by SenomyOS?";
        return true;
    }
    function cancelStop() {
        if (state !== "pending-stop") return false;
        state = previousState; message = "Keyboard stop cancelled.";
        return true;
    }
    function confirmStop() {
        if (state !== "pending-stop") return false;
        if (!owned) { state = "failed"; message = "Owned keyboard is no longer available."; return false; }
        if (!provider.stop(serial)) { state = "failed"; message = "Owned keyboard stop request failed."; return false; }
        state = "stop-requested"; message = "Stop requested; waiting for owned provider exit.";
        return true;
    }
    property var startupTimer: Timer {
        interval: 8000
        onTriggered: {
            root.startPending = false;
            root.state = "failed";
            root.message = "Keyboard startup timed out; no readiness is claimed.";
        }
    }
    Component.onCompleted: refreshState()
}
