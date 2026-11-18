import Quickshell

// A truthful, provider-shaped activity resolver for the Rail. The initial
// providers reuse state already owned by Quickshell; no new polling process is
// introduced. Additional transfer/device providers can join this contract
// later without teaching the presentation component about their source.
Scope {
    id: root

    required property var media
    required property var performance
    required property var insights
    required property var notifications

    readonly property bool benchmarkRunning: performance
        && (performance.benchmarkActionState === "running"
            || performance.benchmarkStatus.state === "running")
    readonly property bool operationRunning: insights && insights.actionState === "running"

    readonly property string kind: {
        if (benchmarkRunning)
            return "benchmark";
        if (operationRunning)
            return "operation";
        if (media && media.available)
            return "media";
        if (notifications && notifications.unreadCount > 0)
            return "notification";
        return "idle";
    }

    readonly property string eyebrow: {
        switch (kind) {
        case "benchmark": return "SYSTEM BENCHMARK";
        case "operation": return "SYSTEM OPERATION";
        case "media": return media.identity.toUpperCase();
        case "notification": return "SYSTEM NOTICE";
        default: return "CONTEXT";
        }
    }

    readonly property string title: {
        switch (kind) {
        case "benchmark": return performance.benchmarkStatus.state_label || "Benchmark running";
        case "operation": return insights.actionDomain
            ? insights.actionDomain.toUpperCase() : "Task running";
        case "media": return media.title;
        case "notification": return notifications.unreadCount
            + (notifications.unreadCount === 1 ? " notification waiting" : " notifications waiting");
        default: return "No active task";
        }
    }

    readonly property string detail: {
        switch (kind) {
        case "benchmark": return performance.benchmarkStatus.message || "Measured local workload";
        case "operation": return "SenomyOS is completing an allowlisted task";
        case "media": return media.artist || media.album || "Active media session";
        case "notification": return "Open the private notification ledger";
        default: return "System activity will appear here";
        }
    }

    readonly property real progress: {
        if (kind === "benchmark")
            return Math.max(0, Math.min(1, Number(performance.benchmarkStatus.progress || 0) / 100));
        if (kind === "media" && media.duration > 0)
            return Math.max(0, Math.min(1, media.position / media.duration));
        return -1;
    }

    readonly property string artwork: kind === "media" ? media.artwork : ""
    readonly property bool mediaControlsAvailable: kind === "media" && media.available
    readonly property bool mediaPlaying: mediaControlsAvailable && media.playing

    function previous() {
        return mediaControlsAvailable ? media.previous() : false;
    }

    function toggle() {
        return mediaControlsAvailable ? media.toggle() : false;
    }

    function next() {
        return mediaControlsAvailable ? media.next() : false;
    }
}
