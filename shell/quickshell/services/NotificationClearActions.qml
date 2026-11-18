import QtQuick

QtObject {
    id: root
    required property var provider
    property string context: ""
    property string requestedContext: ""
    property string actionState: "idle"
    property string message: ""
    property var requestedHistory: null
    property var requestedActive: []
    property int retainedCount: 0
    property int activeCount: 0
    readonly property bool locked: actionState === "pending" || actionState === "running"
    readonly property string impact: "Permanently delete " + retainedCount + " retained notification(s) and dismiss "
        + activeCount + " active notification(s), including active transient notifications. This cannot be undone."

    function valid() {
        const current = provider.activeNotifications;
        return provider.clearAvailable && context !== "" && context === requestedContext
            && provider.history === requestedHistory
            && current.length === requestedActive.length
            && requestedActive.every(item => current.indexOf(item) >= 0);
    }

    function request(ownerContext) {
        if (locked || !ownerContext || ownerContext !== context || !provider.clearAvailable
                || (provider.history.length === 0 && provider.activeNotifications.length === 0))
            return false;
        requestedContext = context;
        requestedHistory = provider.history;
        requestedActive = provider.activeNotifications.slice();
        retainedCount = requestedHistory.length;
        activeCount = requestedActive.length;
        message = "";
        actionState = "pending";
        return true;
    }

    function release() {
        requestedHistory = null;
        requestedActive = [];
    }

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

    function confirm(ownerContext) {
        if (actionState !== "pending" || ownerContext !== requestedContext) return false;
        if (!valid()) return fail("Notifications or ownership changed. Nothing was cleared; review the current list again.");
        actionState = "running";
        message = "Clearing notifications and saving the history…";
        try {
            if (!provider.clearConfirmed(requestedHistory, requestedActive))
                return fail("The clear request was rejected. Check the current list before retrying.");
        } catch (error) {
            return fail("Clearing failed. Some active notifications may already be dismissed; check the current list before retrying.");
        }
        return true;
    }

    function saved() {
        if (actionState !== "running") return;
        actionState = "succeeded";
        message = "Notification history was cleared and saved. New notifications are retained normally.";
        release();
    }

    onContextChanged: cancel()
    property Timer timeout: Timer {
        interval: 5000
        running: root.actionState === "running"
        onTriggered: root.fail("History saving was not confirmed. Some notifications may already be cleared; check storage before retrying.")
    }
}
