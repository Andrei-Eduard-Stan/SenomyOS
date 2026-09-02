import QtQuick
import Quickshell
import Quickshell.Io

// Existing SenomyOS collectors remain bounded, source-owned adapters during
// the functional migration. They are invoked only while their Insights route
// is visible or after an explicit allowlisted action.
Scope {
    id: root

    property bool active: false
    property string section: "briefing"
    property var payloads: ({})
    property string error: ""
    property string actionState: "idle"
    property string actionDomain: ""
    readonly property string sourceRoot: String(Quickshell.env("SENOMY_SOURCE_ROOT") || "")

    function commandFor(route, readAfterAction) {
        switch (route) {
        case "briefing":
        case "updates": return [sourceRoot + "/scripts/update-status.sh", "read"];
        case "timeline": return [sourceRoot + "/scripts/timeline-status.sh", "activity"];
        case "diagnostics": return [sourceRoot + "/scripts/diagnostics-status.sh", readAfterAction ? "read" : "catalog"];
        case "console": return [sourceRoot + "/scripts/console-status.sh", readAfterAction ? "read" : "catalog"];
        case "reports": return [sourceRoot + "/scripts/performance-report.sh", "read-json"];
        case "wiki": return [sourceRoot + "/scripts/wiki-status.py", "catalog"];
        default: return [];
        }
    }

    function refresh(route, readAfterAction) {
        const target = route || section;
        if (!active || target === "notifications" || queryProcess.running)
            return false;
        const command = commandFor(target, Boolean(readAfterAction));
        if (command.length === 0)
            return false;
        queryProcess.route = target;
        queryProcess.storeKey = target + (readAfterAction ? "Result" : "");
        queryProcess.exec(command);
        return true;
    }

    function tasksFor(domain) {
        const payload = payloads[domain];
        return payload && payload.data && payload.data.tasks ? payload.data.tasks : [];
    }

    function runTask(domain, taskId) {
        if ((domain !== "diagnostics" && domain !== "console") || actionProcess.running)
            return false;
        if (!tasksFor(domain).some(task => task.id === taskId))
            return false;
        actionState = "running";
        actionDomain = domain;
        error = "";
        actionProcess.exec([sourceRoot + "/scripts/" + domain + "-status.sh", "run", taskId]);
        return true;
    }

    function runUpdate(kind) {
        if (actionProcess.running || ["official", "aur"].indexOf(kind) < 0)
            return false;
        actionState = "running";
        actionDomain = "updates";
        error = "";
        actionProcess.exec([sourceRoot + "/scripts/update-status.sh", "check-" + kind]);
        return true;
    }

    function generateReport(profile) {
        if (actionProcess.running || ["overview", "performance", "network", "power", "full"].indexOf(profile) < 0)
            return false;
        actionState = "running";
        actionDomain = "reports";
        error = "";
        actionProcess.exec([sourceRoot + "/scripts/performance-report.sh", "generate-json", profile]);
        return true;
    }

    function openLatestReport() {
        Quickshell.execDetached([sourceRoot + "/scripts/performance-report.sh", "open-latest"]);
    }

    onActiveChanged: if (active) refresh(section, false)
    onSectionChanged: if (active) refresh(section, false)

    Timer {
        interval: root.section === "timeline" ? 5000 : 15000
        repeat: true
        running: root.active && ["briefing", "timeline", "updates"].indexOf(root.section) >= 0
        onTriggered: root.refresh(root.section, false)
    }

    Process {
        id: queryProcess
        property string route: ""
        property string storeKey: ""
        stdout: StdioCollector { id: queryOutput }
        stderr: StdioCollector { id: queryError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.error = queryError.text.trim() || "Insights collector failed";
                return;
            }
            try {
                const parsed = JSON.parse(queryOutput.text);
                const next = Object.assign({}, root.payloads);
                next[storeKey] = parsed;
                root.payloads = next;
                root.error = parsed.ok === false && parsed.error ? parsed.error.message : "";
            } catch (error) {
                root.error = "Insights collector returned invalid JSON";
            }
        }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionError }
        onExited: (exitCode, exitStatus) => {
            root.actionState = exitCode === 0 ? "succeeded" : "failed";
            root.error = exitCode === 0 ? "" : actionError.text.trim() || "Insights action failed";
            const domain = root.actionDomain;
            root.actionDomain = "";
            if (root.active && domain.length > 0)
                root.refresh(domain, domain === "diagnostics" || domain === "console");
        }
    }
}
