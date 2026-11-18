import QtQuick
import QtQuick.Controls
import "../config" as Config

Slider {
    id: root
    implicitHeight: Math.max(44, Config.Theme.touchTarget)
    implicitWidth: 180
    opacity: enabled ? 1 : 0.4
    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 5
        radius: 2
        color: "#292c30"
        border.color: "#4a4e55"
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#aeb2b9" }
                GradientStop { position: 1; color: "#f1f1f4" }
            }
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 18; height: 24; radius: 1
        color: root.pressed ? "#ffffff" : "#d9dbe0"
        border.color: root.activeFocus || root.hovered ? "#ffffff" : "#90959e"
    }
}
