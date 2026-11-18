import QtQuick
import Quickshell
import Quickshell.Io

// On-demand care state and explicit reviewed transactions. No continuous poll.
Scope {
    id: root
    property bool enabled: true
    property string context: ""
    property bool blocked: false
    property string interpreter: "python3"
    property string helper: Quickshell.shellDir + "/scripts/battery-care-client.py"
    property var snapshot: ({})
    property var lastReceipt: null
    property var drafts: ({})
    property bool persistentChoice: false
    property bool reading: false
    property bool readerStarted: false
    property bool fresh: false
    property string actionState: "idle"
    property string message: ""
    property string title: "BATTERY CHARGE THRESHOLDS"
    property string impact: ""
    property var proposed: null
    property string operation: "apply"
    property int generation: 0
    property bool processStarted: false
    readonly property bool locked: actionState === "pending" || actionState === "running"
    readonly property bool busy: locked || reading || reader.running || writer.running
    readonly property var packs: snapshot.packs || []
    readonly property bool installed: snapshot.installed === true
    function draft(pack) { return drafts[pack.name] || {identity:pack.identity,selected:false,start:pack.effective[0],stop:pack.effective[1]}; }
    function edit(pack, key, value) {
        if (locked) return;
        const next = Object.assign({}, drafts); const d = Object.assign({}, draft(pack));
        d[key] = value; next[pack.name] = d; drafts = next;
    }
    function adopt(payload) {
        if (!payload || payload.ok !== true || payload.schemaVersion !== 1 || !payload.token || !Array.isArray(payload.packs)) {
            fresh = false; message = payload && payload.message || "Battery-care state unavailable. Refresh before any operation."; return false;
        }
        const next = Object.assign({},drafts);
        for (const pack of payload.packs) {
            if (next[pack.name] && next[pack.name].identity !== pack.identity) {
                next[pack.name] = Object.assign({},next[pack.name],{identity:pack.identity,selected:false});
                message = "Battery identity changed; the old draft was deselected. Review the new pack before applying.";
            }
        }
        drafts = next; snapshot = payload; lastReceipt = payload.lastReceipt || null; fresh = true; return true;
    }
    function refresh() {
        if (!enabled || busy) return false;
        reading = true; readerStarted = false; fresh = false; reader.serial = generation; reader.exec([interpreter,helper,"get"]); return true;
    }
    function requestApply() {
        if (!enabled || !context || blocked || busy || !fresh || !installed || (persistentChoice && snapshot.persistentAvailable !== true)) return false;
        const changes = {}; let descriptions = [];
        for (const pack of packs) {
            const d = draft(pack);
            if (!d.selected) continue;
            if (d.identity !== pack.identity || !pack.supported || !Number.isInteger(d.start) || !Number.isInteger(d.stop) || d.start < pack.startRange[0] || d.start > pack.startRange[1] || d.stop < pack.stopRange[0] || d.stop > pack.stopRange[1] || d.start >= d.stop) {
                message = "Invalid or unsupported thresholds: start 0–99, stop 1–100 and start < stop."; actionState = "failed"; return false;
            }
            changes[pack.name] = [d.start,d.stop]; descriptions.push(pack.name + ": " + pack.effective.join("/") + " → " + d.start + "/" + d.stop);
        }
        if (!descriptions.length) { message = "Select at least one supported battery."; return false; }
        operation = "apply"; proposed = {token:snapshot.token,changes:changes,persistent:persistentChoice};
        title = "APPLY CHARGE THRESHOLDS";
        impact = descriptions.join("; ") + (persistentChoice ? ". Save to the managed TLP drop-in and apply now." : ". Runtime only; TLP may restore configured values at boot or a care reapplication.") + " Local authentication required. Charging behaviour is not verified by threshold readback. Recovery is explicit and refuses external changes.";
        message = ""; actionState = "pending"; return true;
    }
    function requestRestore() {
        if (!enabled || !context || blocked || busy || !fresh || !installed || !lastReceipt || !lastReceipt.restorableToken || snapshot.token !== lastReceipt.restorableToken) return false;
        operation = "restore"; proposed = {token:snapshot.token,receipt:lastReceipt.receipt};
        title = "RESTORE PREVIOUS CHARGE THRESHOLDS";
        impact = "Restore recorded pairs " + JSON.stringify(lastReceipt.previous) + (lastReceipt.persistent ? " and exact prior managed TLP file/absence." : "; runtime only.") + " Authentication and exact current-state checks are required. External changes cause refusal.";
        message = ""; actionState = "pending"; return true;
    }
    function requestHistory() {
        if (!enabled || !context || blocked || busy || !fresh || !installed) return false;
        operation = "history"; proposed = {token:snapshot.token};
        title = "READ RECOVERY RECORDS"; impact = "Authenticate to read this account's protected recovery summaries. No threshold or configuration changes. A later Restore requires its own review.";
        actionState = "pending"; return true;
    }
    function cancel() { if (actionState !== "pending") return false; actionState = "idle"; proposed = null; return true; }
    function confirm() {
        if (actionState !== "pending" || blocked || !proposed || !fresh || proposed.token !== snapshot.token) return false;
        generation++; actionState = "running"; message = "Waiting for local authentication and exact readback…"; processStarted = false;
        writer.exec(operation === "history" ? [interpreter,helper,"history"] : [interpreter,helper,operation,JSON.stringify(proposed)]); return true;
    }
    onContextChanged: { cancel(); if (context) refresh(); }
    Timer {
        interval: 200; running: root.actionState === "running" && !root.processStarted && !writer.running
        onTriggered: { root.actionState = "failed"; root.fresh = false; root.message = "Care adapter could not start. No success is assumed; check installation and refresh."; }
    }
    Timer {
        interval: 200; running: root.reading && !root.readerStarted && !reader.running
        onTriggered: { root.reading = false; root.fresh = false; root.message = "Care status adapter could not start. Check installation before retrying."; }
    }
    Process {
        id: reader
        property int serial: 0
        onStarted: root.readerStarted = true
        stdout: StdioCollector { id: readOutput }
        onExited: {
            root.reading = false;
            if (serial !== root.generation || root.locked) return;
            try { root.adopt(JSON.parse(readOutput.text)); }
            catch (_) { root.fresh = false; root.message = "Care status could not be read. No previous snapshot is treated as current."; }
        }
    }
    Process {
        id: writer
        onStarted: root.processStarted = true
        stdout: StdioCollector { id: writeOutput }
        onExited: (code, status) => {
            let p;
            try { p = JSON.parse(writeOutput.text); }
            catch (_) { p = {ok:false,state:"unverified",message:"Care operation ended without a receipt. It may have partially applied. Inspect current state before retrying."}; }
            if (p.snapshot) root.adopt(Object.assign({},p.snapshot,{installed:p.installed === true,lastReceipt:p.lastReceipt}));
            else root.fresh = false;
            if (p.lastReceipt !== undefined) root.lastReceipt = p.lastReceipt;
            root.actionState = code === 0 && p.ok === true && p.state === "verified" ? "succeeded" : p.state === "partially-applied" ? "partially-applied" : "failed";
            root.message = p.message || "Battery-care outcome could not be verified.";
            if (p.results) root.message += " " + Object.keys(p.results).map(b => {
                const result = p.results[b];
                return b + " requested " + result.requested.join("/") + ", readback " + (result.effective ? result.effective.join("/") : "unavailable") + (result.verified ? " verified" : " unverified");
            }).join("; "); root.proposed = null;
            if (root.actionState === "succeeded") root.drafts = ({});
        }
    }
}
