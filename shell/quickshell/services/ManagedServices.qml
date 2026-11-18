import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property bool active: false
    property bool blocked: false
    property bool queryEnabled: true
    property string context: ""
    property int processPid: 0
    property var items: []
    property var processService: null
    property bool available: false
    property string error: ""
    property alias actions: restartActions
    readonly property string helper: Qt.resolvedUrl("../scripts/managed-services.py").toString().replace("file://", "")
    ServiceRestartActions {
        id: restartActions
        active: root.active; blocked: root.blocked; context: root.context; items: root.items
        helper: root.helper; runner: actionProcess
        onRefreshRequested: { root.refresh(); root.findProcessService(); }
    }
    function refresh() {
        if (active && queryEnabled && !query.running) query.exec(["python3",helper,"catalog"]);
    }
    function findProcessService() {
        processService = null;
        if (active && queryEnabled && processPid > 0 && !association.running) {
            association.pid = processPid;
            association.exec(["python3",helper,"process",String(processPid)]);
        }
    }
    onActiveChanged: {
        if (active) { refresh(); findProcessService(); }
        else { processService = null; }
    }
    onProcessPidChanged: findProcessService()
    Timer { interval: 5000; repeat: true; running: root.active; onTriggered: root.refresh() }
    Process {
        id: query
        stdout: StdioCollector { id: queryOutput }
        onExited: code => {
            try {
                const parsed = JSON.parse(queryOutput.text);
                root.items = code === 0 && parsed.ok ? parsed.data.items : [];
                root.available = code === 0 && parsed.ok && parsed.data.available;
                root.error = parsed.ok ? "" : (parsed.error || {}).message || "User-service inventory unavailable.";
            } catch (_) { root.items = []; root.available = false; root.error = "User-service inventory returned invalid data."; }
        }
    }
    Process {
        id: association
        property int pid: 0
        stdout: StdioCollector { id: associationOutput }
        onExited: code => {
            if (pid !== root.processPid) { root.findProcessService(); return; }
            if (!root.active) return;
            try {
                const parsed = JSON.parse(associationOutput.text);
                root.processService = code === 0 && parsed.ok && parsed.data.supported ? parsed.data.service : null;
            } catch (_) { root.processService = null; }
        }
    }
    Process {
        id: actionProcess
        stdout: StdioCollector { id: actionOutput }
        onExited: code => restartActions.completed(code,actionOutput.text)
    }
}
