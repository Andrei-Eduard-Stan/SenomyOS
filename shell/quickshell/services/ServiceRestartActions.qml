import QtQuick

QtObject {
    id: root
    property bool active: false
    property bool blocked: false
    property string context: ""
    property var items: []
    signal refreshRequested()
    property string actionState: "idle"
    property string title: ""
    property string impact: ""
    property string message: ""
    property var pending: null
    readonly property bool locked: actionState === "pending" || actionState === "running"
    required property var runner
    required property string helper

    function request(item) {
        if (!active || blocked || !context || locked || !item || !item.restartAllowed
                || !items.some(current => current.unit === item.unit && current.token === item.token)) return false;
        pending = {unit:item.unit,token:item.token,context:context};
        title = "Restart " + item.unit + "?";
        impact = item.impact + " Only this user service will be requested to restart.";
        message = "";
        actionState = "pending";
        return true;
    }
    function cancel() {
        if (actionState === "running") return false;
        pending = null; actionState = "idle"; message = "";
        return true;
    }
    function confirm() {
        if (actionState !== "pending" || !pending || !active || blocked || !context
                || pending.context !== context || runner.running) return false;
        if (!items.some(item => item.restartAllowed && item.unit === pending.unit && item.token === pending.token)) {
            pending = null; actionState = "failed"; message = "Service changed. Review it again; nothing was restarted.";
            return false;
        }
        actionState = "running"; message = "Requesting restart and checking the resulting service instance…";
        runner.exec(["python3", helper, "restart-confirmed", pending.unit, pending.token]);
        return true;
    }
    function completed(code, output) {
        pending = null;
        try {
            const parsed = JSON.parse(output);
            actionState = code === 0 && parsed.ok ? parsed.data.state : "failed";
            message = parsed.ok ? parsed.data.message : (parsed.error || {}).message || "Service restart failed.";
        } catch (_) { actionState = "failed"; message = "Service restart returned invalid data. Verify state before retrying."; }
        refreshRequested();
    }
    onContextChanged: if (actionState === "pending") cancel()
    onActiveChanged: if (!active && actionState === "pending") cancel()
}
