import QtQuick
import QtQuick.Shapes
import "../config" as Config

// Shared compact/detail composition. Labels and connectors use the same row
// coordinates, so live strings cannot drift away from the authored line ends.
Item {
    id: root
    required property var metrics
    property bool detailed: false
    property bool decorative: true
    property bool interactive: true
    property bool animateAvatar: true
    readonly property bool narrowDetail: detailed && width < 620
    signal openPerformance()
    signal openInsights()
    readonly property int detailTextSize: Math.max(10, Math.min(20, Config.Skin.registry.persona && Config.Skin.registry.persona.detailTextPx || 14))
    readonly property real avatarSize: detailed ? Math.max(32, Math.min(width * (narrowDetail ? 0.5 : 0.4), height - (narrowDetail ? 194 : 42))) : Math.min(height, width < 150 ? 26 : 36)
    readonly property real avatarX: (width - avatarSize) / 2
    readonly property real avatarY: detailed ? 0 : (height - avatarSize) / 2
    readonly property real centerY: avatarY + avatarSize / 2
    readonly property real sideWidth: Math.max(24, avatarX - (detailed ? 64 : 26))
    readonly property real textInset: detailed ? 18 : 0
    readonly property int valueSize: detailed ? detailTextSize : 12
    readonly property int labelSize: detailed ? detailTextSize : 12

    SenomyAvatar {
        id: avatar
        x: root.avatarX; y: root.avatarY
        width: root.avatarSize; height: width
        animate: root.animateAvatar
        ButtonHoverFrame { trackPointer: true; anchors.fill: parent; enabled: root.interactive }
        MouseArea {
            enabled: root.interactive
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openPerformance()
        }
    }

    // Compact branches share the avatar centre; labels and values stay inline.
    Column {
        visible: !root.detailed
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: root.avatarX - (root.width < 150 ? 3 : 16)
        spacing: 4
        Repeater {
            model: ["CPU", "RAM"]
            Text {
                required property string modelData
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: modelData + " " + (modelData === "CPU"
                    ? (root.metrics.ready ? Math.round(root.metrics.cpuPercent) + "%" : "—")
                    : (root.metrics.memoryTotalKib > 0 ? Math.round(root.metrics.memoryPercent) + "%" : "—"))
                color: Config.Theme.foreground
                font.family: Config.Theme.fontFamily
                font.pixelSize: root.width < 150 ? 7 : root.width < 230 ? 10 : 12
            }
        }
        ButtonHoverFrame { trackPointer: true; anchors.fill: parent; enabled: root.interactive }
        TapHandler { enabled: root.interactive; onTapped: root.openPerformance() }
    }
    Text {
        visible: !root.detailed
        x: root.avatarX + root.avatarSize + (root.width < 150 ? 3 : 16)
        anchors.verticalCenter: parent.verticalCenter
        text: (root.width >= 230 ? (root.metrics.temperatureAvailable ? Math.round(root.metrics.temperatureCelsius) + " °C" : "TEMP —") + "\n" : "") + "UP " + root.metrics.uptimeDetailedLabel
        color: Config.Theme.foreground
        font.family: Config.Theme.fontFamily
        font.pixelSize: root.width < 150 ? 7 : root.width < 230 ? 8 : 9
        ButtonHoverFrame { trackPointer: true; anchors.fill: parent; enabled: root.interactive }
        TapHandler { enabled: root.interactive; onTapped: root.openPerformance() }
    }
    Repeater {
        model: root.decorative && !root.detailed && root.width >= 150 ? [-1, 1] : []
        Shape {
            required property int modelData
            x: root.width / 2 + modelData * (root.avatarSize / 2 + 2)
            y: root.centerY
            ShapePath {
                strokeColor: Config.Theme.muted; strokeWidth: 1; fillColor: "transparent"
                startX: 0; startY: 0
                PathLine { x: modelData * 6; y: -6 }
                PathLine { x: modelData * 12; y: -6 }
            }
        }
    }

    Repeater {
        model: root.detailed ? [
            {side: "left", y: root.centerY - 55, label: "KERNEL", value: root.metrics.kernelRelease, detail: ""},
            {side: "left", y: root.centerY + 40, label: "HOST", value: root.metrics.hostName, detail: root.metrics.hostModel},
            {side: "right", y: root.centerY - 55, label: "CPU", value: root.metrics.ready ? Math.round(root.metrics.cpuPercent) + "%" : "—", detail: root.metrics.cpuModel},
            {side: "right", y: root.centerY + 40, label: "RAM", value: root.metrics.memoryTotalKib > 0 ? Math.round(root.metrics.memoryPercent) + "%" : "—", detail: root.metrics.memoryTotalKib > 0 ? Math.round(root.metrics.memoryUsedKib / 1024) + " MiB out of " + Math.round(root.metrics.memoryTotalKib / 1024) + " MiB" : "Unavailable"}
        ] : []
        delegate: Item {
            id: branch
            required property var modelData
            readonly property bool isLeft: modelData.side === "left"
            x: root.narrowDetail ? (isLeft ? 12 : root.width / 2 + 8)
                : isLeft ? root.textInset : root.width - root.sideWidth - root.textInset
            y: root.narrowDetail ? (root.avatarSize + (modelData.y < root.centerY ? 12 : 84))
                : modelData.y - (root.detailed ? 25 : 10)
            width: root.narrowDetail ? root.width / 2 - 24 : root.sideWidth
            height: root.detailed ? 68 : 30
            Column {
                width: parent.width
                spacing: root.detailed ? 3 : 1
                Text {
                    width: parent.width
                    text: branch.modelData.label
                    horizontalAlignment: branch.isLeft ? Text.AlignRight : Text.AlignLeft
                    color: Config.Theme.muted
                    font.family: Config.Theme.fontFamily; font.pixelSize: root.labelSize
                }
                Text {
                    width: parent.width
                    text: branch.modelData.value
                    horizontalAlignment: branch.isLeft ? Text.AlignRight : Text.AlignLeft
                    color: Config.Theme.foreground
                    font.family: Config.Theme.fontFamily; font.pixelSize: root.valueSize; font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    visible: root.detailed && text.length > 0
                    width: parent.width
                    text: branch.modelData.detail
                    horizontalAlignment: branch.isLeft ? Text.AlignRight : Text.AlignLeft
                    color: Config.Theme.muted
                    font.family: Config.Theme.fontFamily; font.pixelSize: root.detailTextSize
                    elide: Text.ElideRight
                }
            }
            ButtonHoverFrame { trackPointer: true; anchors.fill: parent; enabled: root.interactive }
            MouseArea {
            enabled: root.interactive
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openPerformance()
            }
            Shape {
                visible: root.decorative && !root.narrowDetail && (root.detailed || root.width >= 180)
                // The horizontal terminal meets the value's baseline.
                x: branch.isLeft ? branch.width + 8 : -8
                y: root.detailed ? 27 : 16
                width: 1; height: 1
                ShapePath {
                    strokeColor: Config.Theme.foreground
                    strokeWidth: root.detailed ? 1.3 : 1
                    fillColor: "transparent"
                    startX: 0; startY: 0
                    PathLine { x: (branch.isLeft ? 1 : -1) * (root.detailed ? 24 : 7); y: 0 }
                    PathLine { x: (branch.isLeft ? 1 : -1) * (root.detailed ? 44 : 15); y: branch.modelData.y < root.centerY ? 12 : -12 }
                }
            }
        }
    }

    Column {
        visible: root.detailed
        x: root.detailed && !root.narrowDetail ? root.avatarX - 20 : 0
        y: root.detailed ? root.height - 36 : root.height - 16
        width: root.detailed && !root.narrowDetail ? root.avatarSize + 40 : root.width
        spacing: 2
        Text {
            visible: root.detailed
            anchors.horizontalCenter: parent.horizontalCenter
            text: "UPTIME"; color: Config.Theme.muted
            font.family: Config.Theme.fontFamily; font.pixelSize: root.detailTextSize
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (root.detailed ? "" : "UP  ") + root.metrics.uptimeDetailedLabel
            color: Config.Theme.foreground
            font.family: Config.Theme.fontFamily; font.pixelSize: root.detailed ? root.detailTextSize : 12
        }
        ButtonHoverFrame { trackPointer: true; anchors.fill: parent; enabled: root.interactive }
        TapHandler { enabled: root.interactive; onTapped: root.openPerformance() }
    }
}
