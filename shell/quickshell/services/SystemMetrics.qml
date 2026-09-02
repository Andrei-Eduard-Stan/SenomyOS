import QtQuick
import Quickshell
import Quickshell.Io

// CPU has no event interface comparable to Hyprland, UPower, or PipeWire.
// This is the one bounded sampler in Milestone 1: it reads kernel pseudo-files
// directly and never forks a process.
Scope {
    id: root

    property real cpuPercent: 0
    property real memoryPercent: 0
    property double uptimeSeconds: 0
    property real networkRxKib: 0
    property real networkTxKib: 0
    property double previousNetworkRx: 0
    property double previousNetworkTx: 0
    property double previousNetworkAt: 0
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

    function parseCpu() {
        const line = cpuFile.text().split("\n")[0].trim();
        const fields = line.split(/\s+/).slice(1).map(Number);
        if (fields.length < 5 || fields.some(isNaN))
            return;

        const total = fields.reduce((sum, value) => sum + value, 0);
        const idle = fields[3] + (fields[4] || 0);
        if (previousCpuTotal > 0 && total > previousCpuTotal) {
            const totalDelta = total - previousCpuTotal;
            const idleDelta = idle - previousCpuIdle;
            cpuPercent = Math.max(0, Math.min(100, 100 * (totalDelta - idleDelta) / totalDelta));
            ready = true;
        }
        previousCpuTotal = total;
        previousCpuIdle = idle;
    }

    function parseMemory() {
        const values = {};
        const lines = memoryFile.text().split("\n");
        for (const line of lines) {
            const match = line.match(/^([A-Za-z_()]+):\s+(\d+)/);
            if (match)
                values[match[1]] = Number(match[2]);
        }
        if (values.MemTotal > 0) {
            const available = values.MemAvailable !== undefined
                ? values.MemAvailable
                : (values.MemFree || 0) + (values.Buffers || 0) + (values.Cached || 0);
            memoryPercent = Math.max(0, Math.min(100, 100 * (values.MemTotal - available) / values.MemTotal));
        }
    }

    function parseUptime() {
        const value = Number(uptimeFile.text().trim().split(/\s+/)[0]);
        if (!isNaN(value))
            uptimeSeconds = value;
    }

    function parseNetwork() {
        let rx = 0;
        let tx = 0;
        for (const line of networkFile.text().split("\n")) {
            const match = line.match(/^\s*([^:]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/);
            if (!match || match[1].trim() === "lo")
                continue;
            rx += Number(match[2]);
            tx += Number(match[3]);
        }
        const now = Date.now() / 1000;
        if (previousNetworkAt > 0 && now > previousNetworkAt) {
            const seconds = now - previousNetworkAt;
            networkRxKib = Math.max(0, (rx - previousNetworkRx) / seconds / 1024);
            networkTxKib = Math.max(0, (tx - previousNetworkTx) / seconds / 1024);
        }
        previousNetworkRx = rx;
        previousNetworkTx = tx;
        previousNetworkAt = now;
    }

    function refresh() {
        cpuFile.reload();
        memoryFile.reload();
        uptimeFile.reload();
        networkFile.reload();
    }

    FileView {
        id: cpuFile
        path: "/proc/stat"
        blockLoading: true
        printErrors: true
        onLoaded: root.parseCpu()
    }

    FileView {
        id: networkFile
        path: "/proc/net/dev"
        blockLoading: true
        printErrors: true
        onLoaded: root.parseNetwork()
    }

    FileView {
        id: memoryFile
        path: "/proc/meminfo"
        blockLoading: true
        printErrors: true
        onLoaded: root.parseMemory()
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        blockLoading: true
        printErrors: true
        onLoaded: root.parseUptime()
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
