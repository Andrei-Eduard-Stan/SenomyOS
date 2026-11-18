import QtQuick
import QtQuick.Effects
import "Theme.js" as Theme

// SDDM owns a separate greeter display. This blurs its wallpaper, never a
// previous user's windows or a persisted desktop capture.
Item {
    id: root
    objectName: "greeter-backdrop"
    property url source: "assets/background-source.png"
    property url fallbackSource: "assets/background.png"
    property real blurAmount: 0.85
    property real scrimOpacity: 0.34
    property bool readable: false
    readonly property bool gpuBlur: GraphicsInfo.api !== GraphicsInfo.Software
        && GraphicsInfo.api !== GraphicsInfo.Unknown && GraphicsInfo.api !== GraphicsInfo.Null
    readonly property bool renderReady: gpuBlur ? imageReady : fallback.status === Image.Ready
    readonly property bool imageReady: original.status === Image.Ready
    clip: true
    Rectangle { anchors.fill: parent; color: Theme.background }
    Image {
        id: original
        anchors.fill: parent; anchors.margins: -48
        source: root.source
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.min(2560,root.width+96),Math.min(1600,root.height+96))
        asynchronous: true
        visible: false
    }
    MultiEffect {
        objectName: "greeter-live-qt-blur"
        anchors.fill: original
        source: original
        visible: root.gpuBlur && root.imageReady
        blurEnabled: true
        blur: Math.max(0,Math.min(1,root.blurAmount))
        blurMax: 32
        blurMultiplier: 1
        autoPaddingEnabled: true
        saturation: -0.12
    }
    Image {
        id: fallback
        anchors.fill: parent
        source: root.fallbackSource
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.min(2560,root.width),Math.min(1600,root.height))
        visible: !root.gpuBlur || !root.imageReady
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent; color: Theme.background
        opacity: root.readable ? 0.76 : Math.max(0,Math.min(0.9,root.scrimOpacity))
    }
}
