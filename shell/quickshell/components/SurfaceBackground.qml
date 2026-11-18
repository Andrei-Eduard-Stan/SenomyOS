import QtQuick
import QtQuick.Window
import "../config" as Config

// Independent fill layer: no input handlers, no changes to frame or content.
Item {
    id: root
    property string fillKey: ""
    property var spec: Config.Skin.registry.backgrounds && Config.Skin.registry.backgrounds[fillKey] || ({})
    readonly property bool imageReady: artwork.status === Image.Ready
    clip: true
    Image {
        id: artwork
        anchors.fill: parent
        source: Config.Skin.resolve(root.spec.source || "")
        visible: status === Image.Ready
        opacity: root.spec.imageOpacity === undefined ? 1 : root.spec.imageOpacity
        fillMode: root.spec.scaling === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.min(4096, Math.ceil(root.width * Math.max(1, Screen.devicePixelRatio))),
                            Math.min(4096, Math.ceil(root.height * Math.max(1, Screen.devicePixelRatio))))
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        visible: root.imageReady
        color: "black"
        opacity: root.spec.scrimOpacity || 0
    }
}
