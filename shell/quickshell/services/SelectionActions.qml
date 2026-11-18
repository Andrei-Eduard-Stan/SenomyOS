import QtQuick

// Shared confirmation lifecycle for native audio routing and power profiles.
// Provider adapters own the finite kinds/options and the actual native write.
QtObject {
    id: root
    required property var provider
    property string context: ""
    property string actionState: "idle"
    property string kind: ""
    property string title: ""
    property string impact: ""
    property string message: ""
    property var target: null
    property var previous: null
    property var backend: null
    property double deadline: 0
    property int timeoutMs: 10000
    readonly property bool locked: actionState === "pending" || actionState === "running"

    function targetAvailable() {
        return provider.selectionAvailable(kind) && backend !== null && backend === provider.selectionBackend
            && provider.selectionOptions(kind).indexOf(target) >= 0;
    }
    function valid() {
        return context !== "" && targetAvailable()
            && provider.selectionCurrent(kind) === previous && target !== previous;
    }
    function request(selectionKind, value) {
        if (locked || !context || !provider.selectionAvailable(selectionKind)
                || provider.selectionOptions(selectionKind).indexOf(value) < 0
                || provider.selectionCurrent(selectionKind) === value)
            return false;
        kind = selectionKind;
        target = value;
        previous = provider.selectionCurrent(kind);
        backend = provider.selectionBackend;
        if (!valid()) return fail("The provider or target is unavailable. Select it again.");
        title = provider.selectionLabel(kind, previous) + " → " + provider.selectionLabel(kind, target);
        impact = provider.selectionImpact(kind);
        message = "";
        actionState = "pending";
        return true;
    }
    function release() { target = null; previous = null; backend = null; }
    function cancel() {
        if (actionState !== "pending") return false;
        actionState = "idle";
        message = "";
        release();
        return true;
    }
    function fail(reason) {
        actionState = "failed";
        message = reason;
        release();
        return false;
    }
    function confirm() {
        if (actionState !== "pending") return false;
        if (!valid()) return fail("The current selection, provider or target changed. Nothing was changed; review it again.");
        actionState = "running";
        message = "Waiting for the provider to report the requested selection…";
        deadline = Date.now() + timeoutMs;
        try {
            if (!provider.applySelection(kind, target))
                return fail("The provider rejected this request. Check the current selection before retrying.");
        } catch (error) {
            return fail("The request failed. Check the current selection before retrying.");
        }
        return true;
    }
    function observe() {
        if (actionState !== "running") return;
        if (!targetAvailable()) {
            fail("The provider or target became unavailable; completion could not be verified.");
        } else if (provider.selectionCurrent(kind) === target) {
            actionState = "succeeded";
            message = "The provider reports the requested selection. Applications may retain their own routing or policy overrides.";
            release();
        } else if (Date.now() >= deadline) {
            fail("The provider did not report the selection in time. The request may still finish; check current state before retrying.");
        }
    }
    onContextChanged: cancel()
    property Timer observer: Timer {
        interval: 250
        repeat: true
        running: root.actionState === "running"
        onTriggered: root.observe()
    }
}
