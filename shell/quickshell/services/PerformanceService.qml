import QtQuick
import Quickshell
import Quickshell.Io

// Shared history is owned by SystemMetrics for the entire session. Only
// inventory, process enumeration and explicit diagnostics are view-scoped.
Scope {
    id: root

    required property var metrics
    property bool active: false
    property string actionContext: ""
    property alias managedServices: serviceControls
    ManagedServices { id: serviceControls; active: root.active && (root.processPageActive || root.actionContext.startsWith("performance:services:")); context: root.actionContext; processPid: root.selectedProcessPid; blocked: root.processActionState === "pending" || root.processActionState === "running" }
    property int historySeconds: 60
    readonly property var historySamples: metrics.history ? metrics.history.window(historySeconds, metrics.observedAt) : []
    readonly property var cpuHistory: historySamples.map(p => p.cpu)
    readonly property var temperatureHistory: historySamples.map(p => p.temperature)
    readonly property var frequencyHistory: historySamples.map(p => Number.isFinite(p.frequency) ? p.frequency/1000 : null)
    readonly property var diskBusyHistory: historySamples.map(p => p.disk)
    function coreHistory(id) {
        return historySamples.map(p=>{const core=(p.cores || []).find(c=>c.id===id);return core && Number.isFinite(core.percent)?core.percent:null;});
    }
    readonly property var sampleTimes: historySamples.map(p => p.at)
    property double detailsObservedAt: 0
    property double processesObservedAt: 0
    readonly property var memoryHistory: historySamples.map(p => p.ram)
    readonly property var rxHistory: historySamples.map(p => p.rx)
    readonly property var txHistory: historySamples.map(p => p.tx)
    property var details: ({})
    property var processes: []
    property var processSummary: ({})
    property bool processPageActive: false
    property bool summaryPageActive: false
    readonly property var telemetry: metrics
    onSummaryPageActiveChanged: if(summaryPageActive) refreshProcesses()
    property int processViewGeneration: 0
    property string processSort: "cpu"
    property string processFilter: "all"
    property int selectedProcessPid: 0
    property string selectedProcessName: ""
    property var selectedProcess: ({})
    property string processDetailError: ""
    property string pendingProcessAction: ""
    property string pendingProcessContext: ""
    property int pendingProcessPid: 0
    property string pendingProcessName: ""
    property string pendingProcessStartTicks: ""
    property string processActionState: "idle"
    property string processActionMessage: ""
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
        tick += 1;
        if ((tick === 1 || tick % 15 === 0) && !detailProcess.running)
            detailProcess.exec([sourceRoot + "/scripts/performance-status.sh"]);
        if ((processPageActive || summaryPageActive) && (tick === 1 || tick % 5 === 0) && !processProcess.running)
            refreshProcesses();
    }

    function refreshProcesses() {
        if (!processProcess.running && !processPreferenceProcess.running) {
            processProcess.requestedGeneration = processViewGeneration;
            processProcess.exec(["env", "SENOMY_PROCESS_LIMIT=" + (processPageActive ? "512" : "12"), sourceRoot + "/scripts/performance-processes.sh", processSort]);
        }
    }

    function configureProcesses(kind, value) {
        const allowed = kind === "sort" ? ["cpu", "memory", "name"]
            : kind === "filter" ? ["all", "user", "active", "heavy"] : [];
        if (allowed.indexOf(value) < 0 || processPreferenceProcess.running)
            return false;
        processViewGeneration += 1;
        processPreferenceProcess.kind = kind;
        processPreferenceProcess.value = value;
        processPreferenceProcess.exec([sourceRoot + "/scripts/performance-action.sh", "set-" + kind, value]);
        return true;
    }

    function selectProcess(pid, name) {
        if (processActionState === "running" || managedServices.actions.actionState === "running") return false;
        if (managedServices.actions.actionState === "pending") managedServices.actions.cancel();
        cancelProcessAction();
        selectedProcessPid = Number(pid) || 0;
        selectedProcessName = String(name || "");
        selectedProcess = ({});
        processDetailError = "";
        if (selectedProcessPid > 0 && !processDetailProcess.running)
            processDetailProcess.exec([sourceRoot + "/scripts/performance-process-detail.sh", String(selectedProcessPid)]);
    }

    function requestProcessTermination() { return requestProcessSignal("terminate"); }

    function requestProcessSignal(action) {
        if (["terminate","kill","stop","continue"].indexOf(action)<0) return false;
        if (!active || !actionContext || managedServices.actions.locked
                || processActionState === "running" || processActionState === "pending"
                || selectedProcessPid < 1 || !selectedProcess.action_allowed)
            return false;
        pendingProcessContext = actionContext;
        pendingProcessAction = action;
        pendingProcessPid = selectedProcessPid;
        pendingProcessName = selectedProcessName;
        pendingProcessStartTicks = String(selectedProcess.start_ticks || "");
        processActionState = "pending";
        processActionMessage = "Review " + selectedProcessName + " · PID " + selectedProcessPid + " before " + action.toUpperCase() + ".";
        return true;
    }

    function cancelProcessAction() {
        if (processActionState === "running")
            return false;
        pendingProcessAction = "";
        pendingProcessPid = 0;
        pendingProcessName = "";
        pendingProcessStartTicks = "";
        processActionState = "idle";
        processActionMessage = "";
        return true;
    }

    function confirmProcessAction() {
        if (!active || !actionContext || pendingProcessContext !== actionContext
                || managedServices.actions.locked || processActionProcess.running
                || processActionState !== "pending" || ["terminate","kill","stop","continue"].indexOf(pendingProcessAction)<0)
            return false;
        const current = processes.find(item => Number(item.pid) === pendingProcessPid);
        if (!current || String(current.name) !== pendingProcessName) {
            processActionState = "failed";
            processActionMessage = "The process changed or exited. Nothing was signalled; select it again.";
            return false;
        }
        if (String(selectedProcess.start_ticks || "") !== pendingProcessStartTicks) {
            processActionState = "failed";
            processActionMessage = "The process identity changed. Nothing was signalled; select it again.";
            return false;
        }
        processActionState = "running";
        processActionMessage = "Sending " + pendingProcessAction.toUpperCase() + " to the ownership-checked process…";
        processActionProcess.exec([sourceRoot + "/scripts/performance-action.sh", pendingProcessAction + "-exact",
            String(pendingProcessPid), pendingProcessStartTicks]);
        return true;
    }

    onProcessPageActiveChanged: {
        if (processPageActive) {
            refreshProcesses();
        } else {
            selectedProcessPid = 0;
            selectedProcessName = "";
            selectedProcess = ({});
            processDetailError = "";
            if (processActionState === "pending")
                cancelProcessAction();
        }
    }

    onActionContextChanged: if (processActionState === "pending") cancelProcessAction()
    onActiveChanged: {
        if (!active && processActionState === "pending") cancelProcessAction();
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
                    root.detailsObservedAt = Date.now();
                    root.error = "";
                }
            } catch (error) {
                root.error = "Detailed telemetry returned invalid JSON";
            }
        }
    }

    Process {
        id: processProcess
        property int requestedGeneration: 0
        stdout: StdioCollector { id: processOutput }
        stderr: StdioCollector { id: processError }
        onExited: (exitCode, exitStatus) => {
            if (requestedGeneration !== root.processViewGeneration) {
                root.refreshProcesses();
                return;
            }
            if (exitCode !== 0) {
                root.error = processError.text.trim() || "Process telemetry failed";
                return;
            }
            try {
                const parsed = JSON.parse(processOutput.text);
                if (parsed.ok && parsed.data) {
                    root.processes = parsed.data.processes || [];
                    root.processSort = parsed.data.sort_mode || root.processSort;
                    root.processesObservedAt = Date.now();
                    root.processSummary = parsed.data;
                    if (root.selectedProcessPid>0 && !processDetailProcess.running)
                        processDetailProcess.exec([root.sourceRoot+"/scripts/performance-process-detail.sh",String(root.selectedProcessPid)]);

                    if (root.selectedProcessPid > 0
                            && !root.processes.some(item => Number(item.pid) === root.selectedProcessPid)) {
                        root.selectedProcessPid = 0;
                        root.selectedProcessName = "";
                        root.selectedProcess = ({});
                        root.processDetailError = "The selected process exited.";
                    }
                }
            } catch (error) {
                root.error = "Process telemetry returned invalid JSON";
            }
        }
    }

    Process {
        id: processDetailProcess
        stdout: StdioCollector { id: processDetailOutput }
        stderr: StdioCollector { id: processDetailErrorOutput }
        onExited: (exitCode, exitStatus) => {
            try {
                const parsed = JSON.parse(processDetailOutput.text);
                if (exitCode === 0 && parsed.ok && parsed.data
                        && Number(parsed.data.pid) === root.selectedProcessPid) {
                    root.selectedProcess = parsed.data;
                    root.processDetailError = "";
                } else {
                    root.selectedProcess = ({});
                    root.processDetailError = (parsed.error || {}).message || "Process details are unavailable.";
                }
            } catch (error) {
                root.selectedProcess = ({});
                root.processDetailError = processDetailErrorOutput.text.trim() || "Process details returned invalid JSON.";
            }
        }
    }

    Process {
        id: processPreferenceProcess
        property string kind: ""
        property string value: ""
        stderr: StdioCollector { id: processPreferenceError }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                if (kind === "sort") root.processSort = value;
                else if (kind === "filter") root.processFilter = value;
                root.refreshProcesses();
            } else {
                root.error = processPreferenceError.text.trim() || "The process view preference could not be applied.";
            }
        }
    }

    Process {
        id: processActionProcess
        stderr: StdioCollector { id: processActionError }
        onExited: (exitCode, exitStatus) => {
            root.processActionState = exitCode === 0 ? "succeeded" : "failed";
            root.processActionMessage = exitCode === 0
                ? "The signal was sent. Live telemetry will confirm the resulting state."
                : processActionError.text.trim() || "The process was not signalled.";
            root.pendingProcessAction = "";
            root.pendingProcessPid = 0;
            root.pendingProcessName = "";
            root.pendingProcessStartTicks = "";
            root.refreshProcesses();
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
