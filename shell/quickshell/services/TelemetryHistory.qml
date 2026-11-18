import QtQuick
import Quickshell

// Session-owned, memory-only history. No panel controls collection lifetime.
Scope {
    id: root
    required property var metrics
    property int retentionSeconds: 900
    property int maximumSamples: 900
    property var samples: []
    readonly property alias disk: diskSampler
    readonly property double lastSampleAt: samples.length ? samples[samples.length - 1].at : 0
    function sample(now) {
        if (!Number.isFinite(now) || now <= 0 || (lastSampleAt && now <= lastSampleAt)) return;
        function finite(value, available) { return available && Number.isFinite(Number(value)) ? Number(value) : null; }
        const next = samples.filter(p => now - p.at <= Math.min(900, Math.max(60, retentionSeconds)) * 1000);
        next.push({at:now, cpu:finite(metrics.cpuPercent, metrics.ready),
            ram:finite(metrics.memoryPercent, metrics.memoryTotalKib > 0),
            rx:finite(metrics.networkRxKib, metrics.networkReady), tx:finite(metrics.networkTxKib, metrics.networkReady),
            temperature:finite(metrics.temperatureCelsius, metrics.temperatureAvailable),
            frequency:metrics.frequency && metrics.frequency.available ? metrics.frequency.mhz : null,
            cores:(metrics.cores || []).map(c => ({id:c.id, percent:c.percent})),
            disk:finite(diskSampler.busyPercent, diskSampler.available && now>=diskSampler.previousAt && now-diskSampler.previousAt<5000)});
        samples = next.slice(-Math.min(900, Math.max(1, maximumSamples)));
    }
    function window(seconds, now) {
        return samples.filter(p => p.at <= now && now-p.at <= seconds*1000);
    }
    DiskActivity { id: diskSampler; active: true }
}
