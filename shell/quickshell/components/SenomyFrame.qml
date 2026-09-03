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
    property real motifCenterX: width / 2
    default property alias contentData: content.data

    readonly property int opticalHeight: tier === "compact" ? Math.min(44, height) : height
    readonly property int opticalY: Math.round((height - opticalHeight) / 2)
    readonly property int cornerSize: tier === "large" ? Config.Theme.largeCorner
        : tier === "standard" ? Config.Theme.standardCorner : Config.Theme.compactCorner
    readonly property int horizontalEdgeHeight: tier === "large" ? Config.Theme.largeEdgeHorizontal
        : tier === "standard" ? Config.Theme.standardEdgeHorizontal : 6
    readonly property int verticalEdgeWidth: tier === "large" ? Config.Theme.largeEdgeVertical
        : tier === "standard" ? Config.Theme.standardEdgeVertical : 6
    readonly property int safeTop: tier === "large" ? Config.Theme.largeSafeTop
        : tier === "standard" ? Config.Theme.standardSafeTop : 7
    readonly property int safeRight: tier === "large" ? Config.Theme.largeSafeRight
        : tier === "standard" ? Config.Theme.standardSafeRight : 9
    readonly property int safeBottom: tier === "large" ? Config.Theme.largeSafeBottom
        : tier === "standard" ? Config.Theme.standardSafeBottom : 7
    readonly property int safeLeft: tier === "large" ? Config.Theme.largeSafeLeft
        : tier === "standard" ? Config.Theme.standardSafeLeft : 9
    readonly property string assetRoot: "../assets/frames/"

    Rectangle {
        x: 1
        y: root.opticalY + 1
        width: parent.width - 2
        height: root.opticalHeight - 2
        radius: root.tier === "compact" ? 14 : 5
        color: Config.Theme.glassSurface
        border.width: root.active ? 1 : 0
        border.color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.48)
    }

    Rectangle {
        x: 1
        y: root.opticalY + 1
        width: parent.width - 2
        height: root.opticalHeight - 2
        radius: root.tier === "compact" ? 14 : 5
        color: root.active ? Config.Theme.glassFocus
            : root.hovered ? Config.Theme.glassHover : "transparent"
        Behavior on color { ColorAnimation { duration: 130 } }
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
            x: Math.max(root.cornerSize,
                Math.min(frame.width - root.cornerSize - width,
                    root.motifCenterX - width / 2))
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
        anchors.leftMargin: root.safeLeft
        anchors.rightMargin: root.safeRight
        anchors.topMargin: root.safeTop
        anchors.bottomMargin: root.safeBottom
    }

    HoverHandler { id: hoverHandler }
}
