import QtQuick
import "../config" as Config

Item {
    id: root
    property bool animate: true
    readonly property bool customCircle: circle.status === Image.Ready
    readonly property bool rotationActive: root.visible && root.animate && root.customCircle && Config.RailStyle.rotateAvatarCircle
    Image {
        anchors.fill: parent
        visible: !root.customCircle
        source: Config.Skin.resolve(Config.Skin.registry.persona && Config.Skin.registry.persona.fallback || "../../assets/senomy/senomy_machine_medallion.png")
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.ceil(root.width * 2)
        sourceSize.height: Math.ceil(root.height * 2)
        mipmap: true
    }
    Image {
        id: circle
        anchors.fill: parent
        source: Config.RailStyle.avatarCircleSource
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.ceil(root.width * 2)
        sourceSize.height: Math.ceil(root.height * 2)
        RotationAnimator on rotation {
            from: 0; to: 360
            duration: Math.max(4000, Config.RailStyle.avatarRotationMs)
            loops: Animation.Infinite
            running: root.rotationActive
        }
    }
    Image {
        visible: root.customCircle
        anchors.centerIn: parent
        width: parent.width * 0.62; height: parent.height * 0.62
        source: Config.RailStyle.avatarPortraitSource
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.ceil(width * 2)
        sourceSize.height: Math.ceil(height * 2)
    }
}
