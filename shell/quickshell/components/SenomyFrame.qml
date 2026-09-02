import QtQuick
import "../config" as Config

// Native modular Luminous Reliquary frame. Fixed corners and motifs retain
// their authored size; only the neutral edge modules are stretched.
Item {
    id: root

    property string motif: ""
    property string tier: "compact"
    property bool active: false
    property bool hovered: hoverHandler.hovered
    default property alias contentData: content.data

    readonly property int opticalHeight: tier === "compact" ? Math.min(44, height) : height
    readonly property int opticalY: Math.round((height - opticalHeight) / 2)
    readonly property int cornerSize: tier === "standard" ? 32 : Config.Theme.compactCorner
    readonly property int horizontalEdgeHeight: tier === "standard" ? 9 : 6
    readonly property int verticalEdgeWidth: tier === "standard" ? 9 : 6
    readonly property string assetRoot: "../assets/frames/"

    Rectangle {
        x: 1
        y: root.opticalY + 1
        width: parent.width - 2
        height: root.opticalHeight - 2
        radius: root.tier === "standard" ? 25 : 15
        color: root.hovered ? Config.Theme.surfaceHover : Config.Theme.surface
        border.width: root.active ? 1 : 0
        border.color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.48)

        Behavior on color {
            ColorAnimation { duration: 110 }
        }
    }

    Item {
        id: frame
        x: 0
        y: root.opticalY
        width: root.width
        height: root.opticalHeight
        opacity: root.active ? 1 : 0.82

        Image {
            x: root.cornerSize
            y: 0
            width: frame.width - root.cornerSize * 2
            height: root.horizontalEdgeHeight
            source: root.assetRoot + root.tier + "/edge-top.svg"
            fillMode: Image.Stretch
        }
        Image {
            x: root.cornerSize
            y: frame.height - root.horizontalEdgeHeight
            width: frame.width - root.cornerSize * 2
            height: root.horizontalEdgeHeight
            source: root.assetRoot + root.tier + "/edge-bottom.svg"
            fillMode: Image.Stretch
        }
        Image {
            x: 0
            y: root.cornerSize
            width: root.verticalEdgeWidth
            height: frame.height - root.cornerSize * 2
            source: root.assetRoot + root.tier + "/edge-left.svg"
            fillMode: Image.Stretch
        }
        Image {
            x: frame.width - root.verticalEdgeWidth
            y: root.cornerSize
            width: root.verticalEdgeWidth
            height: frame.height - root.cornerSize * 2
            source: root.assetRoot + root.tier + "/edge-right.svg"
            fillMode: Image.Stretch
        }

        Repeater {
            model: [
                { name: "corner-tl.svg", x: 0, y: 0 },
                { name: "corner-tr.svg", x: frame.width - root.cornerSize, y: 0 },
                { name: "corner-bl.svg", x: 0, y: frame.height - root.cornerSize },
                { name: "corner-br.svg", x: frame.width - root.cornerSize, y: frame.height - root.cornerSize }
            ]
            delegate: Image {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: root.cornerSize
                height: root.cornerSize
                source: root.assetRoot + root.tier + "/" + modelData.name
                fillMode: Image.PreserveAspectFit
            }
        }

        Image {
            visible: root.motif.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: root.motif === "telemetry" || root.motif === "clock-notification" || root.motif === "power"
                ? undefined : parent.top
            anchors.bottom: root.motif === "telemetry" || root.motif === "clock-notification" || root.motif === "power"
                ? parent.bottom : undefined
            source: root.assetRoot + "motifs/" + root.motif + ".svg"
            sourceSize.width: root.motif === "identity" ? 24 : root.motif === "telemetry" ? 18 : 10
            sourceSize.height: root.motif === "identity" ? 10 : root.motif === "power" ? 8 : 6
            width: sourceSize.width
            height: sourceSize.height
            fillMode: Image.PreserveAspectFit
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.leftMargin: root.tier === "standard" ? 16 : 9
        anchors.rightMargin: root.tier === "standard" ? 16 : 9
        anchors.topMargin: root.tier === "standard" ? 14 : 7
        anchors.bottomMargin: root.tier === "standard" ? 14 : 7
    }

    HoverHandler { id: hoverHandler }
}
