import QtQuick
import QtQuick.Controls
import "../config" as Config

SenomyFrame {
    id: root

    width: 397
    height: Config.Theme.islandHeight
    motif: "identity"

    Row {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 12
            color: Config.Theme.surfaceRaised
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: "../assets/senomy/senomy_chibi_rail-v1.png"
                fillMode: Image.PreserveAspectCrop
                mipmap: true
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 46
            spacing: 2

            Text {
                width: parent.width
                text: "SENO // SYSTEM COMPANION"
                color: Config.Theme.accent
                font.family: Config.Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: "Everything looks steady"
                color: Config.Theme.foreground
                font.family: Config.Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: identityArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
    }
    ToolTip.visible: identityArea.containsMouse
    ToolTip.delay: 550
    ToolTip.text: "Senomy Insights and companion migrate after the Rail foundation"
}
