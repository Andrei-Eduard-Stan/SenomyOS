import QtQuick
import QtQuick.Controls
import "../config" as Config

ScrollBar {
    id: root
    policy: ScrollBar.AsNeeded
    minimumSize: 0.08
    padding: Config.DirectoryStyle.touchMode ? 10 : 3
    implicitWidth: Config.DirectoryStyle.touchMode ? 24 : 10
    implicitHeight: Config.DirectoryStyle.touchMode ? 24 : 10
    opacity: size < 1 ? 1 : 0
    contentItem: Rectangle {
        implicitWidth: 3
        implicitHeight: 3
        radius: 0
        color: root.pressed ? Config.DirectoryStyle.ink : Qt.rgba(1, 1, 1, root.hovered ? 0.6 : 0.28)
    }
    background: Rectangle {
        color: "transparent"
    }
}
