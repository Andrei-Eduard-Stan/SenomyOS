import QtQuick
import QtQuick.Controls
import "../config" as Config

SenomyFrame {
    id: root

    required property var metrics
    property bool dashboardOpen: false
    property bool compact: false
    signal togglePerformance()
    width: 392
    height: Config.Theme.islandHeight
    motif: "telemetry"

    Row {
        anchors.centerIn: parent
        spacing: root.compact ? 4 : 18

        Repeater {
            model: root.compact ? [
                { key: "CPU", value: root.metrics.ready ? Math.round(root.metrics.cpuPercent) + "%" : "…" }
            ] : [
                { key: "CPU", value: root.metrics.ready ? Math.round(root.metrics.cpuPercent) + "%" : "…" },
                { key: "MEM", value: Math.round(root.metrics.memoryPercent) + "%" },
                { key: "UP", value: root.metrics.uptimeLabel }
            ]
            delegate: Row {
                required property var modelData
                spacing: 6
                Text {
                    text: modelData.key
                    color: Config.Theme.dim
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
                Text {
                    text: modelData.value
                    color: Config.Theme.foreground
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    MouseArea {
        id: telemetryArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.togglePerformance()
    }
    ToolTip.visible: telemetryArea.containsMouse
    ToolTip.delay: 550
    ToolTip.text: root.dashboardOpen ? "Close Performance Dashboard" : "Open Performance Dashboard"
}
