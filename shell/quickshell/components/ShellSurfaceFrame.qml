import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../config" as Config

// Fill selection remains independent of the new perimeter. Art-backed legacy
// panels retain their .38 scrim; native panels retain the Theme glass states.
Item {
    id: root
    property string frameKey: ""
    property string fillKey: frameKey
    property bool readableContent: false
    property string tier: "standard"
    property string motif: ""
    property real motifCenterX: width / 2
    property bool fullHeightFrame: true
    property bool active: false
    readonly property bool hovered: hover.hovered
    readonly property alias backgroundItem: surfaceBackground
    default property alias contentData: content.data
    property real perimeterInset: 1
    property real perimeterCorner: 24
    property real contentInset: 20
    property bool animate: visible && !((Config.Skin.registry.persona || {}).reducedMotion)
    readonly property var legacySpec: Config.Skin.frame(frameKey)
    readonly property bool legacyArt: Config.Skin.mode(legacySpec) === "art" && legacyProbe.status === Image.Ready
    readonly property bool artBackdrop: legacyArt && legacySpec.background !== "native"
    property color backdropColor: artBackdrop ? Qt.rgba(10 / 255, 12 / 255, 15 / 255, 0.38 * (legacySpec.opacity === undefined ? 1 : legacySpec.opacity)) : Config.Theme.glassSurface
    property color stateColor: legacyArt ? "transparent" : active ? Config.Theme.glassFocus : hovered ? Config.Theme.glassHover : "transparent"
    // Probe availability only; legacy decorative frames are never stacked.
    Image {
        id: legacyProbe
        visible: false
        source: Config.Skin.resolve(legacySpec.source || "")
        sourceSize: Qt.size(4, 4)
    }
    property var skinSpec: ({
            contentPadding: {
                left: contentInset,
                right: contentInset,
                top: contentInset,
                bottom: contentInset
            }
        })
    Canvas {
        id: backdrop
        parent: root
        anchors.fill: parent
        z: -2
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onBackdropColorChanged() {
                backdrop.requestPaint();
            }
            function onStateColorChanged() {
                backdrop.requestPaint();
            }
        }
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const inset = root.perimeterInset, cut = root.perimeterCorner / 2;
            const l = inset, r = width - inset, t = inset, b = height - inset;
            c.beginPath();
            c.moveTo(l + cut, t);
            c.lineTo(r - cut, t);
            c.lineTo(r, t + cut);
            c.lineTo(r, b - cut);
            c.lineTo(r - cut, b);
            c.lineTo(l + cut, b);
            c.lineTo(l, b - cut);
            c.lineTo(l, t + cut);
            c.closePath();
            c.fillStyle = root.backdropColor;
            c.fill();
            c.fillStyle = root.stateColor;
            c.fill();
        }
    }
    SurfaceBackground {
        id: surfaceBackground
        parent: root
        x: Math.max(8, root.perimeterInset + 1)
        y: x
        width: Math.max(0, root.width - 2 * x)
        height: Math.max(0, root.height - 2 * y)
        fillKey: root.fillKey
        layer.enabled: imageReady
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: backgroundMask
        }
    }
    Item {
        id: backgroundMask
        parent: root
        anchors.fill: surfaceBackground
        visible: false
        layer.enabled: true
        readonly property real cut: Math.max(0, Math.min(root.perimeterCorner / 2 + 2 * root.perimeterInset - 2 * surfaceBackground.x, width / 2, height / 2))
        Shape {
            anchors.fill: parent
            antialiasing: true
            ShapePath {
                fillColor: "white"
                strokeColor: "transparent"
                startX: backgroundMask.cut
                startY: 0
                PathLine {
                    x: backgroundMask.width - backgroundMask.cut
                    y: 0
                }
                PathLine {
                    x: backgroundMask.width
                    y: backgroundMask.cut
                }
                PathLine {
                    x: backgroundMask.width
                    y: backgroundMask.height - backgroundMask.cut
                }
                PathLine {
                    x: backgroundMask.width - backgroundMask.cut
                    y: backgroundMask.height
                }
                PathLine {
                    x: backgroundMask.cut
                    y: backgroundMask.height
                }
                PathLine {
                    x: 0
                    y: backgroundMask.height - backgroundMask.cut
                }
                PathLine {
                    x: 0
                    y: backgroundMask.cut
                }
                PathLine {
                    x: backgroundMask.cut
                    y: 0
                }
            }
        }
    }
    SurfaceOutline {
        parent: root
        anchors.fill: parent
        anchors.margins: root.perimeterInset
        cornerExtent: root.perimeterCorner
        z: 1
    }
    MetalSheen {
        parent: root
        anchors.fill: parent
        anchors.margins: root.perimeterInset + 1
        z: 2
        animate: root.animate
    }
    Rectangle {
        parent:root
        anchors.fill:parent
        anchors.margins:root.contentInset
        color:Config.DirectoryStyle.highContrast?"#080a0c":"#64080a0c"
        visible:root.readableContent || Config.DirectoryStyle.highContrast
    }
    Item {
        id: content
        parent: root
        anchors.fill: parent
        anchors.leftMargin: (root.skinSpec.contentPadding || {}).left || root.contentInset
        anchors.rightMargin: (root.skinSpec.contentPadding || {}).right || root.contentInset
        anchors.topMargin: (root.skinSpec.contentPadding || {}).top || root.contentInset
        anchors.bottomMargin: (root.skinSpec.contentPadding || {}).bottom || root.contentInset
    }
    HoverHandler {
        id: hover
        parent: root
    }
}
