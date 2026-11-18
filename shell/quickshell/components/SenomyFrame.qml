import QtQuick
import "../config" as Config

// Native modular Luminous Reliquary frame. Fixed corners and motifs retain
// their authored size; only the neutral edge modules are stretched.
Item {
    id: root

    property string frameKey: ""
    property string fillKey: frameKey
    property var skinSpec: Config.Skin.frame(frameKey)
    property string borderType: Config.Skin.mode(skinSpec)
    property url artSource: ""
    property bool nativeFrameEnabled: true
    property bool fullHeightFrame: false
    property bool railBackground: false
    readonly property alias artRenderer: artImage
    property string visualState: active ? "active" : hovered ? "hover" : "normal"
    readonly property bool useArt: borderType === "art" && artImage.ready
    property string motif: ""
    property string tier: "compact"
    property bool active: false
    property bool hovered: hoverHandler.hovered
    property real motifCenterX: width / 2
    default property alias contentData: content.data

    readonly property int opticalHeight: tier === "compact" && !fullHeightFrame ? Math.min(52, height) : height
    readonly property int opticalY: Math.round((height - opticalHeight) / 2)
    readonly property int cornerSize: tier === "large" ? Config.Theme.largeCorner
        : tier === "standard" ? Config.Theme.standardCorner : Config.Theme.compactCorner
    readonly property int horizontalEdgeHeight: tier === "large" ? Config.Theme.largeEdgeHorizontal
        : tier === "standard" ? Config.Theme.standardEdgeHorizontal : 6
    readonly property int verticalEdgeWidth: tier === "large" ? Config.Theme.largeEdgeVertical
        : tier === "standard" ? Config.Theme.standardEdgeVertical : 6
    readonly property int safeTop: skinSpec.contentPadding && skinSpec.contentPadding.top !== undefined ? skinSpec.contentPadding.top : tier === "large" ? Config.Theme.largeSafeTop
        : tier === "standard" ? Config.Theme.standardSafeTop : 7
    readonly property int safeRight: skinSpec.contentPadding && skinSpec.contentPadding.right !== undefined ? skinSpec.contentPadding.right : tier === "large" ? Config.Theme.largeSafeRight
        : tier === "standard" ? Config.Theme.standardSafeRight : 9
    readonly property int safeBottom: skinSpec.contentPadding && skinSpec.contentPadding.bottom !== undefined ? skinSpec.contentPadding.bottom : tier === "large" ? Config.Theme.largeSafeBottom
        : tier === "standard" ? Config.Theme.standardSafeBottom : 7
    readonly property int safeLeft: skinSpec.contentPadding && skinSpec.contentPadding.left !== undefined ? skinSpec.contentPadding.left : tier === "large" ? Config.Theme.largeSafeLeft
        : tier === "standard" ? Config.Theme.standardSafeLeft : 9
    readonly property string assetRoot: "../assets/frames/"

    Rectangle {
        x: 1
        y: root.opticalY + 1
        width: parent.width - 2
        height: root.opticalHeight - 2
        radius: root.tier === "compact" ? 14 : 5
        color: (!root.nativeFrameEnabled && !root.useArt) || (root.useArt && root.skinSpec.background !== "native") ? "transparent" : Config.Theme.glassSurface
        border.width: root.nativeFrameEnabled && root.active && !root.useArt ? 1 : 0
        border.color: Qt.rgba(Config.Theme.accent.r, Config.Theme.accent.g, Config.Theme.accent.b, 0.48)
    }

    Rectangle {
        x: 1
        y: root.opticalY + 1
        width: parent.width - 2
        height: root.opticalHeight - 2
        radius: root.tier === "compact" ? 14 : 5
        color: root.useArt || !root.nativeFrameEnabled ? "transparent" : root.active ? Config.Theme.glassFocus
            : "transparent"
        Behavior on color { ColorAnimation { duration: Config.Motion.duration(130) } }
    }

    Item {
        id: frame
        visible: root.nativeFrameEnabled && !root.useArt
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
            source: root.motif ? root.assetRoot + "motifs/" + root.motif + ".svg" : ""
            sourceSize.width: root.motif === "identity" ? 24 : root.motif === "telemetry" ? 18 : 10
            sourceSize.height: root.motif === "identity" ? 10 : root.motif === "power" ? 8 : 6
            width: sourceSize.width
            height: sourceSize.height
            fillMode: Image.PreserveAspectFit
        }
    }

    ArtFrame {
        id: artImage
        x: (root.skinSpec.offset || [0,0])[0]
        y: root.opticalY + (root.skinSpec.offset || [0,0])[1]
        width: root.width; height: root.opticalHeight
        spec: root.skinSpec
        sourceOverride: root.artSource
        requested: root.borderType === "art"
        visualState: root.visualState
    }
    Loader {
        parent: root
        anchors.fill: parent
        z: -2
        active: root.railBackground
        sourceComponent: RailIslandBackground { fillKey: root.fillKey }
    }
    SurfaceBackground {
        visible: !root.railBackground
        x: 8; y: root.opticalY + 8
        width: Math.max(0, root.width - 16); height: Math.max(0, root.opticalHeight - 16)
        fillKey: root.railBackground ? "" : root.fillKey
    }
    property bool stateUnderlineEnabled: true

    // Functional feedback remains visible even when no state artwork is supplied.
    Rectangle {
        x: 4; y: root.opticalY + root.opticalHeight - 3
        width: Math.max(0, parent.width - 8); height: 2
        visible: root.stateUnderlineEnabled && root.useArt && root.active
        color: root.active ? Config.Theme.accent : Config.Theme.muted
        opacity: root.active ? 0.85 : 0.35
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
