import QtQuick
import "../config" as Config

Column {
    id: root
    property var inventory: null
    readonly property var snapshot: inventory ? inventory.snapshot : ({})
    spacing: 10
    function number(value, suffix) {
        return typeof value === "number" && Number.isFinite(value) ? String(Math.round(value * 100) / 100) + suffix : "Unknown";
    }
    Text {
        width: parent.width
        text: "DISPLAYS & INPUT // READ-ONLY"
        color: Config.Theme.foreground; font.family: Config.Theme.fontFamily; font.pixelSize: 12
    }
    Text {
        width: parent.width
        text: root.inventory && root.inventory.error ? root.inventory.error
            : root.inventory && root.inventory.loading ? "Refreshing device inventory…"
            : "Reported by Hyprland · refreshes every 5 seconds while this page is open. Configuration controls are not yet available."
        color: Config.Theme.muted; font.family: Config.Theme.fontFamily; font.pixelSize: 10
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: ["displays", "inputs"]
        delegate: Column {
            id: group
            required property string modelData
            readonly property var result: root.snapshot[modelData] || ({})
            width: root.width
            spacing: 8
            Text {
                width: parent.width
                text: group.modelData.toUpperCase() + " // " + (group.result.available ? group.result.items.length + " REPORTED" : "UNAVAILABLE")
                color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 10
            }
            Text {
                width: parent.width
                visible: !group.result.available || group.result.items.length === 0
                text: group.result.error || (group.result.available ? "No devices reported." : "Inventory not available yet.")
                color: Config.Theme.muted; font.family: Config.Theme.fontFamily; font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: group.result.available ? group.result.items : []
                delegate: DashboardCard {
                    required property var modelData
                    width: group.width
                    height: 140
                    title: group.modelData === "displays" ? "DISPLAY" : modelData.kind
                    value: modelData.name || "Unnamed device"
                    detail: group.modelData === "displays"
                        ? [modelData.disabled === true ? "Disabled" : modelData.disabled === false ? "Enabled" : "State unknown",
                           root.number(modelData.width, "") + " × " + root.number(modelData.height, "") + " · " + root.number(modelData.refreshRate, " Hz"),
                           "Scale " + root.number(modelData.scale, "×") + " · Position " + root.number(modelData.x, "") + ", " + root.number(modelData.y, ""),
                           "Power " + (modelData.dpmsStatus === true ? "on" : modelData.dpmsStatus === false ? "off" : "unknown")
                           + " · Transform " + root.number(modelData.transform, "")].join("\n")
                        : (modelData.layout ? "Active keymap: " + modelData.layout : "Detected by the compositor")
                }
            }
        }
    }
}
