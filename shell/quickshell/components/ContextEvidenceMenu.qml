pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Only the caller's bounded evidence is serialized. No collectors or shell text.
ContextActionMenu {
    id: root
    property string componentKey: "context"
    property var report: ({})
    property bool evidenceAvailable: true
    property string unavailableReason: "No collected evidence yet"
    property bool allowText: true
    property string copyLabel: "Copy diagnostic details"
    property string textLabel: "Save diagnostic details as text"
    property var extraActions: []
    property bool clipboardAvailable: false
    property bool clipboardChecking: true
    property int pendingRevision: 0
    property string pendingContext: ""
    signal extraActionRequested(string action)
    actions: [{id:"copy", label:copyLabel, enabled:evidenceAvailable && clipboardAvailable, reason:!evidenceAvailable ? unavailableReason : clipboardChecking ? "Checking clipboard capability" : "Clipboard unavailable: wl-copy is not installed"}]
        .concat(allowText ? [{id:"text", label:textLabel, enabled:evidenceAvailable, reason:unavailableReason}] : [])
        .concat(extraActions)
    onActionRequested: action => {
        if (action !== "copy" && action !== "text") { extraActionRequested(action); return; }
        if (!evidenceAvailable || (action === "text" && !allowText)) return;
        busy = true; pendingContext = contextKey; pendingRevision = contextRevision;
        runner.exec(["python3", Quickshell.shellDir + "/scripts/component-report.py", action, componentKey, JSON.stringify(report)]);
    }
    Process {
        command: ["python3", "-c", "import shutil,sys;sys.exit(0 if shutil.which('wl-copy') else 1)"]
        running: root.clipboardChecking && root.actions.some(action => action.id === "copy")
        onExited: code => { root.clipboardChecking = false; root.clipboardAvailable = code === 0; }
    }
    Process {
        id: runner
        stdout: StdioCollector { id: output }
        onExited: (code, exitStatus) => {
            let message = "Evidence action failed";
            try {
                const result = JSON.parse(output.text);
                message = result.ok && code === 0 ? result.message : result.message || message;
            } catch (error) {}
            root.busy = false;
            if (root.pendingContext === root.contextKey && root.pendingRevision === root.contextRevision) root.showStatus(message);
        }
    }
}
