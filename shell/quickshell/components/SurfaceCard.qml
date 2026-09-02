import QtQuick
import "../config" as Config

Rectangle {
    id: root

    property string title: ""
    property string value: ""
    property string detail: ""
    property color valueColor: Config.Theme.foreground

    implicitWidth: 210
    implicitHeight: 112
    radius: 16
    color: Config.Theme.surfaceRaised
    border.width: 1
    border.color: Config.Theme.surfaceHover

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 7

        Text {
            width: parent.width
            text: root.title.toUpperCase()
            color: Config.Theme.dim
            font.family: Config.Theme.fontFamily
            font.pixelSize: 8
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.value
            color: root.valueColor
            font.family: Config.Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.detail
            color: Config.Theme.muted
            font.family: Config.Theme.fontFamily
            font.pixelSize: 9
            elide: Text.ElideRight
        }
    }
}
