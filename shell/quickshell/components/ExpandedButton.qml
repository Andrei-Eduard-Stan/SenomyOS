import QtQuick
import QtQuick.Controls
import "../config" as Config

Button {
    id: root

    property bool subtle: false
    property bool symbolic: false

    implicitHeight: 36
    implicitWidth: 116
    hoverEnabled: true
    opacity: enabled ? 1 : 0.3
    Accessible.name: text

    ButtonHoverFrame { focused: root.visualFocus; selected: root.checked; anchors.fill: parent; engaged: root.enabled && root.hovered }
    contentItem: ExpandedLabel {
        text: root.text
        font.family: root.symbolic ? "Font Awesome 7 Free" : "Bruno Ace SC"
        font.pixelSize: root.subtle ? 10 : 11
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        color: "transparent"
        border.width: 0
        border.color: Config.DirectoryStyle.ink

        Behavior on color {
            ColorAnimation {
                duration: Config.Motion.duration(120)
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: Config.Motion.duration(120)
            }

        }

    }

}
