import QtQuick
import Quickshell
import Quickshell.Io
import "CpuSample.js" as Samples

// CPU has no event interface comparable to Hyprland, UPower, or PipeWire.
// The session owns one CPU/memory/network sampler. Short history stays in RAM;
// expensive inventories and process enumeration belong to visible services.
Scope {
    id: root
    readonly property alias history: historyService
    TelemetryHistory { id: historyService; metrics: root }
    TemperatureService { id: temperatureService }
    readonly property bool temperatureAvailable: temperatureService.available
    readonly property real temperatureCelsius: temperatureService.celsius

    property var cores: []
    property var previousCores: []
    property var frequency: ({available:false,mhz:null})
    property var memory: ({available:false,swapAvailable:false})
    property var pressure: ({available:false})
    property var baseFrequency: ({available:false,mhz:null})
    property double observedAt: 0
    property bool networkReady: false
    property string error: ""
    property double lastRefreshAt: 0
    property int sampleIntervalMs: 1000
    property real cpuPercent: 0
    property real memoryPercent: 0
    property double memoryTotalKib: 0
    property double memoryAvailableKib: 0
    property double memoryUsedKib: 0
    property double uptimeSeconds: 0
    property real networkRxKib: 0
    property real networkTxKib: 0
    property double previousNetworkRx: 0
    property double previousNetworkTx: 0
    property double previousNetworkAt: 0
    property string previousNetworkInterfaces:""
    property bool ready: false

    property double previousCpuTotal: 0
    property double previousCpuIdle: 0

    readonly property string uptimeLabel: {
        const totalMinutes = Math.floor(uptimeSeconds / 60);
        const days = Math.floor(totalMinutes / 1440);
        const hours = Math.floor((totalMinutes % 1440) / 60);
        const minutes = totalMinutes % 60;
        if (days > 0)
            return days + "d " + hours + "h";
        if (hours > 0)
            return hours + "h " + minutes + "m";
        return minutes + "m";
    }
    readonly property string uptimeDetailedLabel: {
        const totalSeconds = Math.max(0, Math.floor(uptimeSeconds));
        const days = Math.floor(totalSeconds / 86400);
        const hours = Math.floor((totalSeconds % 86400) / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        const clock = String(hours).padStart(2, "0") + ":"
            + String(minutes).padStart(2, "0") + ":"
            + String(seconds).padStart(2, "0");
        return days > 0 ? days + "d " + clock : clock;
    }
    readonly property string kernelRelease: kernelFile.text().trim() || "Unavailable"
    readonly property string hostName: hostnameFile.text().trim() || "Unknown host"
    readonly property string hostModel: {
        const version = productVersionFile.text().trim();
        return version && !/^(none|unknown|default string|to be filled by o\.e\.m\.)$/i.test(version)
            ? version : productNameFile.text().trim() || "Generic Linux device";
    }
    readonly property string cpuModel: {
        const lines = cpuInfoFile.text().split("\n");
        for (const line of lines) {
            const match = line.match(/^model name\s*:\s*(.+)$/);
            if (match)
                return match[1].trim();
        }
        return "Processor model unavailable";
    }

    function parseCpu(text) {
        const raw=text===undefined?cpuFile.text():text;
        const current = Samples.counters(raw);
        cores = Samples.cores(current, previousCores);
        previousCores = current;
        const line = raw.split("\n")[0].trim();
        const fields = line.split(/\s+/).slice(1,9).map(Number);
        if (!line.startsWith("cpu ") || fields.length < 5 || fields.some(v=>!Number.isFinite(v)||v<0)) {ready=false;previousCpuTotal=0;return;}

        const total = fields.reduce((sum, value) => sum + value, 0);
        const idle = fields[3] + (fields[4] || 0);
        ready=false;
        if (previousCpuTotal > 0 && total > previousCpuTotal && idle>=previousCpuIdle && idle-previousCpuIdle<=total-previousCpuTotal) {
            const totalDelta = total - previousCpuTotal;
            const idleDelta = idle - previousCpuIdle;
            cpuPercent = Math.max(0, Math.min(100, 100 * (totalDelta - idleDelta) / totalDelta));
            ready = true;
        }
        previousCpuTotal = total;
        previousCpuIdle = idle;
    }

    function parseMemory(text) {
        const raw=text===undefined?memoryFile.text():text;
        memory = Samples.memory(raw);
        if(!memory.available){memoryTotalKib=0;memoryAvailableKib=0;memoryUsedKib=0;memoryPercent=0;return;}
        const values = {};
        const lines = raw.split("\n");
        for (const line of lines) {
            const match = line.match(/^([A-Za-z_()]+):\s+(\d+)/);
            if (match)
                values[match[1]] = Number(match[2]);
        }
        if (values.MemTotal > 0) {
            const available = values.MemAvailable !== undefined
                ? values.MemAvailable
                : (values.MemFree || 0) + (values.Buffers || 0) + (values.Cached || 0);
            memoryTotalKib = values.MemTotal;
            memoryAvailableKib = available;
            memoryUsedKib = Math.max(0, values.MemTotal - available);
            memoryPercent = Math.max(0, Math.min(100, 100 * (values.MemTotal - available) / values.MemTotal));
        }
    }

    function parseUptime() {
        const value = Number(uptimeFile.text().trim().split(/\s+/)[0]);
        if (!isNaN(value))
            uptimeSeconds = value;
    }

    function parseNetwork(text,at) {
        const raw=text===undefined?networkFile.text():text;
        let rx = 0;
        let tx = 0;
        let valid=0;
        const names=[];
        for (const line of raw.split("\n")) {
            const match = line.match(/^\s*([^:]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/);
            if (!match || match[1].trim() === "lo")
                continue;
            rx += Number(match[2]);
            tx += Number(match[3]);
            valid++;
            names.push(match[1].trim());
        }
        if(!valid || !Number.isFinite(rx) || !Number.isFinite(tx)){networkReady=false;previousNetworkAt=0;return;}
        const now = at===undefined?Date.now()/1000:at;
        const interfaces=names.sort().join("\n");
        if(interfaces!==previousNetworkInterfaces)previousNetworkAt=0;
        previousNetworkInterfaces=interfaces;
        networkReady=false;
        if (previousNetworkAt > 0 && now > previousNetworkAt) {
            const seconds = now - previousNetworkAt;
            networkRxKib = Math.max(0, (rx - previousNetworkRx) / seconds / 1024);
            networkTxKib = Math.max(0, (tx - previousNetworkTx) / seconds / 1024);
            networkReady = rx >= previousNetworkRx && tx >= previousNetworkTx;
        }
        previousNetworkRx = rx;
        previousNetworkTx = tx;
        previousNetworkAt = now;
    }

    function refresh() {
        const now = Date.now();
        // Suspend, counter reset and clock discontinuities start a fresh delta;
        // old history stays timestamped, leaving a visible gap.
        if(lastRefreshAt && now<lastRefreshAt)historyService.samples=[];
        if (lastRefreshAt && (now-lastRefreshAt>Math.max(5000,Math.max(1000,Math.min(10000,sampleIntervalMs))*3) || now<=lastRefreshAt)) {
            previousCpuTotal=0;previousCores=[];previousNetworkAt=0;ready=false;networkReady=false;
        }
        lastRefreshAt=now;
        cpuFile.reload();
        memoryFile.reload();
        uptimeFile.reload();
        networkFile.reload();
        observedAt = now;
        error = ready ? "" : "Awaiting a valid CPU delta";
        historyService.sample(now);
    }

    FileView {
        id: cpuFile
        path: "/proc/stat"
        blockLoading: true
        printErrors: true
        onLoaded: root.parseCpu()
        onLoadFailed: {root.ready=false;root.previousCpuTotal=0;root.previousCores=[];root.cores=[];}
    }

    FileView {
        id: networkFile
        path: "/proc/net/dev"
        blockLoading: true
        printErrors: true
        onLoaded: root.parseNetwork()
        onLoadFailed: {root.networkReady=false;root.previousNetworkAt=0;}
    }

    FileView {
        id: memoryFile
        path: "/proc/meminfo"
        blockLoading: true
        printErrors: true
        onLoaded: root.parseMemory()
        onLoadFailed: {root.memoryTotalKib=0;root.memory=({available:false,swapAvailable:false});}
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        blockLoading: true
        printErrors: true
        onLoaded: root.parseUptime()
    }

    FileView {
        id: kernelFile
        path: "/proc/sys/kernel/osrelease"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: hostnameFile
        path: "/proc/sys/kernel/hostname"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: productVersionFile
        path: "/sys/class/dmi/id/product_version"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: productNameFile
        path: "/sys/class/dmi/id/product_name"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: cpuInfoFile
        path: "/proc/cpuinfo"
        blockLoading: true
        printErrors: false
        onLoaded: root.frequency=Samples.frequency(text())
        onLoadFailed: root.frequency=({available:false,mhz:null})
    }

    FileView {
        id: psiFile; path:"/proc/pressure/memory"; blockLoading:true; printErrors:false
        onLoaded: root.pressure=Samples.pressure(text())
        onLoadFailed: root.pressure=({available:false})
    }
    FileView {
        id: baseFrequencyFile
        path:root.cores.length ? "/sys/devices/system/cpu/cpu"+root.cores[0].id+"/cpufreq/base_frequency" : ""
        printErrors:false
        onLoaded: {const khz=Number(text().trim());root.baseFrequency=({available:khz>0,mhz:khz>0?khz/1000:null});}
        onLoadFailed: root.baseFrequency=({available:false,mhz:null})
    }
    Timer { interval:5000;repeat:true;running:true;onTriggered:{cpuInfoFile.reload();psiFile.reload();} }
    Timer {
        interval: Math.max(1000,Math.min(10000,root.sampleIntervalMs))
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
