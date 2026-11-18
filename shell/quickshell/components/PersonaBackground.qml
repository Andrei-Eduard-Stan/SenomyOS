import QtQuick
import QtQuick.Window
import "../config" as Config

// Legibility is independent of frame artwork and input. A missing image cannot
// remove the backing. Sources are relative to the central skin manifest.
Item {
    id: root
    property string variant: "rail"
    property bool drawBacking: true
    property bool drawScrim: true
    property var spec: Config.Skin.registry.backgrounds && Config.Skin.registry.backgrounds["senomy-" + variant]
        && Config.Skin.registry.backgrounds["senomy-" + variant].source
        ? Config.Skin.registry.backgrounds["senomy-" + variant] : Config.Skin.registry.persona && Config.Skin.registry.persona.backgrounds
        && Config.Skin.registry.persona.backgrounds[variant] || ({})
    readonly property bool imageReady: artwork.status === Image.Ready
    clip: true
    Rectangle {
        anchors.fill: parent
        color: root.spec.color || "#080a0c"
        opacity: root.drawBacking ? (root.spec.opacity === undefined ? 0.96 : root.spec.opacity) : 0
    }
    Image {
        id: artwork
        anchors.fill: parent
        source: Config.Skin.resolve(root.spec.source || "")
        visible: status === Image.Ready
        opacity: root.spec.imageOpacity === undefined ? 1 : root.spec.imageOpacity
        // A backdrop preserves aspect ratio; it is not a stretched frame.
        fillMode: root.spec.scaling === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(root.width*Math.max(1,Screen.devicePixelRatio)),Math.ceil(root.height*Math.max(1,Screen.devicePixelRatio)))
        asynchronous: true
        onStatusChanged: if(status===Image.Error) console.warn("Senomy background unavailable; retaining dark fill: " + source)
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.drawScrim ? (root.spec.scrimOpacity || 0) : 0
    }
}
