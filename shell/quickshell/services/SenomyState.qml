import Quickshell

Scope {
    id: root

    required property var shellState
    required property var media
    required property var battery
    required property var network
    required property var metrics
    required property var notifications

    readonly property string state: {
        if (battery.critical)
            return "critical";
        if (battery.low && battery.onBattery)
            return "battery-low";
        if (!network.available || network.connectivityName === "None")
            return "offline";
        if (metrics.cpuPercent >= 90 || metrics.memoryPercent >= 92)
            return "warning";
        if (notifications.unreadCount > 0)
            return "attention";
        if (media.playing)
            return "listening";
        if (battery.charging)
            return "charging";
        return "idle";
    }

    readonly property string message: {
        switch (state) {
        case "critical": return "Power is critical — save your work";
        case "battery-low": return "Battery is running low";
        case "offline": return "Network connectivity is unavailable";
        case "warning": return "System load needs attention";
        case "attention": return notifications.unreadCount + " notification(s) waiting";
        case "listening": return media.title + (media.artist ? " — " + media.artist : "");
        case "charging": return "Power connected · " + battery.label;
        default: return "Everything looks steady";
        }
    }

    readonly property string attentionState: notifications.unreadCount > 0 ? "unread" : "clear"
    readonly property string systemHealth: metrics.cpuPercent >= 90 || metrics.memoryPercent >= 92
        ? "warning" : "nominal"
}
