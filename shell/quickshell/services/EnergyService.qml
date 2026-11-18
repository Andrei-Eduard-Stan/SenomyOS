import QtQuick
import Quickshell
import Quickshell.Io

// One shell-owned watcher, shared by every battery/power surface. Diagnostics
// are on demand; closing Settings does not spawn a second observer.
Scope {
    id: root
    property bool enabled: true
    property bool active: false
    property string helper: Quickshell.shellDir + "/scripts/energy-provider.py"
    property string interpreter: "python3"
    property var snapshot: ({})
    property var diagnostics: ({})
    property string error: ""
    property bool fresh: false
    readonly property var backend: fresh && snapshot.backend ? snapshot.backend : ({})
    readonly property bool available: backend.available === true
    readonly property string profile: backend.active || ""
    readonly property string identity: backend.identity || ""
    readonly property var profiles: backend.profiles || []
    readonly property bool busy: writer.running || runningAction
    property bool actionVerified: false
    property bool runningAction: false
    property bool actionFailed: false
    property bool writerStarted: false
    property string actionError: ""
    property int detailGeneration: 0
    property int stateGeneration: 0
    property int failures: 0
    property double latestObservation: 0
    function adopt(payload) {
        if (!payload || payload.schemaVersion !== 1 || payload.ok !== true || !payload.backend) {
            fresh = false;
            error = payload && payload.message ? payload.message : "Power-profile status could not be verified.";
            return false;
        }
        snapshot = payload;
        latestObservation = Date.now();
        fresh = true;
        error = "";
        failures = 0;
        return true;
    }
    function details() {
        if (enabled && !detailReader.running) {
            detailReader.serial = ++detailGeneration;
            detailReader.exec([interpreter, helper, "details"]);
        }
    }
    function refresh() {
        if (enabled && !reader.running && !writer.running) {
            reader.serial = stateGeneration;
            reader.exec([interpreter, helper, "get"]);
        }
        if (active) details();
    }
    function submit(profileName, reviewToken) {
        if (!available || busy || profiles.indexOf(profileName) < 0 || !backend.token || reviewToken !== backend.token) return false;
        actionVerified = false; actionFailed = false; actionError = ""; runningAction = true;
        writerStarted = false;
        stateGeneration++;
        writer.exec([interpreter, helper, "set", JSON.stringify({profile:profileName, token:reviewToken})]);
        return true;
    }
    onActiveChanged: if (active) refresh()
    Process {
        id: watcher
        command: [root.interpreter, root.helper, "watch"]
        running: root.enabled
        stdout: SplitParser {
            onRead: data => {
                try { root.adopt(JSON.parse(data)); }
                catch (_) { root.fresh = false; root.error = "Invalid power-provider observation. Refresh before retrying."; }
            }
        }
        onExited: {
            root.fresh = false;
            root.error = "Power-profile observer stopped; battery reporting is independent.";
            if (root.enabled) { root.failures++; retry.start(); }
        }
    }
    Timer {
        id: retry
        interval: Math.min(60000, 1000 * Math.pow(2, Math.min(root.failures, 6)))
        onTriggered: if (root.enabled) watcher.running = true
    }
    Timer {
        interval: 200
        running: root.enabled && !watcher.running && !retry.running && !root.fresh
        onTriggered: {
            root.error = "Power observer could not start. Check Python and the adapter installation; battery reporting remains independent.";
            root.failures++; retry.start();
        }
    }
    Timer {
        interval: 150
        running: root.runningAction && !root.writerStarted && !writer.running
        onTriggered: {
            root.runningAction = false;
            root.actionError = "The profile adapter could not start. No request was submitted; check Python and the helper installation.";
            root.actionFailed = true;
        }
    }
    Timer {
        interval: 15000; repeat: true; running: root.enabled
        onTriggered: if (root.fresh && Date.now() - root.latestObservation > 90000) {
            root.fresh = false; root.error = "Power-profile observation is stale. Refresh before retrying.";
        }
    }
    Process {
        id: reader
        property int serial: 0
        stdout: StdioCollector { id: readOutput }
        onExited: (code, status) => {
            // A writer may finish before an older explicit refresh does.
            if (root.runningAction || serial !== root.stateGeneration) return;
            try { root.adopt(JSON.parse(readOutput.text)); }
            catch (_) { root.fresh = false; root.error = "Power-profile refresh failed."; }
        }
    }
    Process {
        id: detailReader
        property int serial: 0
        stdout: StdioCollector { id: detailOutput }
        onExited: (code, status) => {
            if (serial !== root.detailGeneration) return;
            try {
                const payload = JSON.parse(detailOutput.text);
                root.diagnostics = code === 0 && payload.ok === true ? payload : ({error:payload.message || "Power diagnostics unavailable."});
            } catch (_) { root.diagnostics = ({error:"Power diagnostics unavailable. Previous values are not current evidence."}); }
        }
    }
    Process {
        id: writer
        onStarted: root.writerStarted = true
        stdout: StdioCollector { id: writeOutput }
        onExited: (code, status) => {
            let payload;
            try { payload = JSON.parse(writeOutput.text); }
            catch (_) { payload = {ok:false,message:"Power request ended without a verifiable result. Refresh before retrying."}; }
            if (payload.backend) root.adopt(payload.ok === false ? Object.assign({}, payload, {ok:true}) : payload);
            root.runningAction = false;
            root.actionVerified = code === 0 && payload.ok === true && payload.state === "verified";
            root.actionError = !root.actionVerified ? payload.message || "The requested profile could not be verified." : "";
            root.actionFailed = !root.actionVerified;
        }
    }
}
