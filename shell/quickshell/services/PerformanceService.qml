import QtQuick
import Quickshell
import Quickshell.Io

// Level 2 telemetry. Nothing in this service runs while the Performance
// Dashboard is closed. History arrays are capped at 60 samples.
Scope {
    id: root

    required property var metrics
    property bool active: false
    property var cpuHistory: []
    property var memoryHistory: []
    property var rxHistory: []
    property var txHistory: []
    property var details: ({})
    property var processes: []
    property string error: ""
    property int tick: 0
    readonly property string sourceRoot: String(Quickshell.env("SENOMY_SOURCE_ROOT") || "")

    function boundedAppend(values, value) {
        const next = values.slice();
        next.push(value);
        if (next.length > 60)
            next.splice(0, next.length - 60);
        return next;
    }

    function sample() {
        cpuHistory = boundedAppend(cpuHistory, metrics.cpuPercent);
        memoryHistory = boundedAppend(memoryHistory, metrics.memoryPercent);
        rxHistory = boundedAppend(rxHistory, metrics.networkRxKib);
        txHistory = boundedAppend(txHistory, metrics.networkTxKib);
        tick += 1;
        if ((tick === 1 || tick % 3 === 0) && !detailProcess.running)
            detailProcess.exec([sourceRoot + "/scripts/performance-status.sh"]);
        if ((tick === 1 || tick % 5 === 0) && !processProcess.running)
            processProcess.exec([sourceRoot + "/scripts/performance-processes.sh"]);
    }

    onActiveChanged: {
        if (active) {
            tick = 0;
            sample();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.sample()
    }

    Process {
        id: detailProcess
        stdout: StdioCollector { id: detailOutput }
        stderr: StdioCollector { id: detailError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.error = detailError.text.trim() || "Detailed telemetry failed";
                return;
            }
            try {
                const parsed = JSON.parse(detailOutput.text);
                if (parsed.ok && parsed.data) {
                    root.details = parsed.data;
                    root.error = "";
                }
            } catch (error) {
                root.error = "Detailed telemetry returned invalid JSON";
            }
        }
    }

    Process {
        id: processProcess
        stdout: StdioCollector { id: processOutput }
        stderr: StdioCollector { id: processError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.error = processError.text.trim() || "Process telemetry failed";
                return;
            }
            try {
                const parsed = JSON.parse(processOutput.text);
                if (parsed.ok && parsed.data)
                    root.processes = parsed.data.processes || [];
            } catch (error) {
                root.error = "Process telemetry returned invalid JSON";
            }
        }
    }
}
