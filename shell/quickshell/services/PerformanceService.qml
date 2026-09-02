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
    property bool benchmarkPageActive: false
    property var benchmarkStatus: ({state: "idle", state_label: "READY", progress: 0,
        message: "No benchmark status loaded.", logs: []})
    property var benchmarkPlans: ({})
    property string pendingBenchmark: ""
    property string benchmarkActionState: "idle"
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

    function loadBenchmarks() {
        if (!benchmarkPageActive)
            return;
        if (!benchmarkStatusProcess.running)
            benchmarkStatusProcess.exec([sourceRoot + "/scripts/benchmark-status.sh"]);
        if (!benchmarkPlanProcess.running && !benchmarkPlans.quick) {
            benchmarkPlanProcess.profile = "quick";
            benchmarkPlanProcess.exec([sourceRoot + "/scripts/benchmark-action.sh", "plan", "quick"]);
        }
    }

    function requestBenchmark(profile) {
        if (["quick", "standard"].indexOf(profile) < 0 || benchmarkActionState === "running")
            return false;
        pendingBenchmark = profile;
        benchmarkActionState = "pending";
        return true;
    }

    function cancelBenchmarkRequest() {
        if (benchmarkActionState !== "pending")
            return false;
        pendingBenchmark = "";
        benchmarkActionState = "idle";
        return true;
    }

    function confirmBenchmark() {
        if (benchmarkActionState !== "pending" || !pendingBenchmark)
            return false;
        benchmarkActionState = "running";
        benchmarkActionProcess.mode = "start";
        benchmarkActionProcess.exec([sourceRoot + "/scripts/benchmark-action.sh", "start", pendingBenchmark]);
        pendingBenchmark = "";
        return true;
    }

    function stopBenchmark() {
        if (benchmarkStatus.state !== "running" || benchmarkActionProcess.running)
            return false;
        benchmarkActionState = "running";
        benchmarkActionProcess.mode = "cancel";
        benchmarkActionProcess.exec([sourceRoot + "/scripts/benchmark-action.sh", "cancel"]);
        return true;
    }

    onBenchmarkPageActiveChanged: {
        if (benchmarkPageActive)
            loadBenchmarks();
        else if (benchmarkActionState === "pending")
            cancelBenchmarkRequest();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.sample()
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active && root.benchmarkPageActive
        onTriggered: root.loadBenchmarks()
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

    Process {
        id: benchmarkStatusProcess
        stdout: StdioCollector { id: benchmarkStatusOutput }
        stderr: StdioCollector { id: benchmarkStatusError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.error = benchmarkStatusError.text.trim() || "Benchmark status failed";
                return;
            }
            try {
                const parsed = JSON.parse(benchmarkStatusOutput.text);
                if (parsed.ok && parsed.data)
                    root.benchmarkStatus = parsed.data;
            } catch (error) {
                root.error = "Benchmark status returned invalid JSON";
            }
        }
    }

    Process {
        id: benchmarkPlanProcess
        property string profile: ""
        stdout: StdioCollector { id: benchmarkPlanOutput }
        stderr: StdioCollector { id: benchmarkPlanError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                try {
                    const parsed = JSON.parse(benchmarkPlanOutput.text);
                    if (parsed.ok && parsed.data) {
                        const next = Object.assign({}, root.benchmarkPlans);
                        next[profile] = parsed.data;
                        root.benchmarkPlans = next;
                    }
                } catch (error) {
                    root.error = "Benchmark plan returned invalid JSON";
                }
            }
            if (profile === "quick" && root.benchmarkPageActive) {
                profile = "standard";
                exec([root.sourceRoot + "/scripts/benchmark-action.sh", "plan", "standard"]);
            }
        }
    }

    Process {
        id: benchmarkActionProcess
        property string mode: ""
        stderr: StdioCollector { id: benchmarkActionError }
        onExited: (exitCode, exitStatus) => {
            root.benchmarkActionState = exitCode === 0 ? "succeeded" : "failed";
            if (exitCode !== 0)
                root.error = benchmarkActionError.text.trim() || "Benchmark action failed";
            if (root.benchmarkPageActive)
                root.loadBenchmarks();
        }
    }
}
