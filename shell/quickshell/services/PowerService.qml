import Quickshell
import Quickshell.Io

// UI may request an allowlisted action, but execution remains a separate,
// explicit confirmation step. Tests use the script's check/dry-run paths only.
Scope {
    id: root

    readonly property var allowedActions: ["lock", "suspend", "logout", "reboot", "poweroff"]
    readonly property string actionTool: String(Quickshell.env("SENOMY_SESSION_ACTION") || "")
    readonly property bool available: actionTool.length > 0
    property string pendingAction: ""
    property string state: "idle"
    property string error: ""

    function request(action) {
        if (!available || allowedActions.indexOf(action) < 0 || actionProcess.running)
            return false;
        pendingAction = action;
        state = "pending";
        error = "";
        return true;
    }

    function cancel() {
        if (state !== "pending")
            return false;
        pendingAction = "";
        state = "idle";
        return true;
    }

    function confirm() {
        if (state !== "pending" || pendingAction.length === 0 || actionProcess.running)
            return false;
        state = "running";
        actionProcess.exec([actionTool, "run", pendingAction, "--confirm", pendingAction]);
        return true;
    }

    Process {
        id: actionProcess
        stderr: StdioCollector { id: actionError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.state = "succeeded";
                root.error = "";
            } else {
                root.state = "failed";
                root.error = actionError.text.trim();
            }
            root.pendingAction = "";
        }
    }
}
