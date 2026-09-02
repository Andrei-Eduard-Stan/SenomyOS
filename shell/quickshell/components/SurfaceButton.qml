import QtQuick
import QtQuick.Controls
import "../config" as Config

Rectangle {
    id: root

    property string text: ""
    property string detail: ""
    property bool active: false
    property bool enabled: true
    property color accentColor: Config.Theme.accent
    signal clicked()

    implicitWidth: 148
    implicitHeight: detail.length > 0 ? 54 : Config.Theme.touchTarget
    radius: 13
    color: active ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.16)
        : area.containsMouse && enabled ? Config.Theme.surfaceHover : Config.Theme.surfaceRaised
    border.width: 1
    border.color: active ? accentColor : Config.Theme.dim
    opacity: enabled ? 1 : 0.46

    Behavior on color { ColorAnimation { duration: 100 } }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Math.min(13, root.width / 6)
        spacing: 3

        Text {
            width: parent.width
            text: root.text
            color: root.active ? root.accentColor : Config.Theme.foreground
            font.family: Config.Theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            visible: root.detail.length > 0
            width: parent.width
            text: root.detail
            color: Config.Theme.muted
            font.family: Config.Theme.fontFamily
            font.pixelSize: 8
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
