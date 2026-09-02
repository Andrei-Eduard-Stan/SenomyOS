import QtQuick
import QtQuick.Controls
import "../config" as Config

SenomyFrame {
    id: root

    required property var senomy
    property bool insightsOpen: false
    property bool companionOpen: false
    signal toggleInsights()
    signal toggleCompanion()
    width: 397
    height: Config.Theme.islandHeight
    motif: "identity"

    Row {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            id: avatar
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

            MouseArea {
                id: avatarArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleCompanion()
            }
            ToolTip.visible: avatarArea.containsMouse
            ToolTip.delay: 450
            ToolTip.text: root.companionOpen ? "Close Senomy companion" : "Open Senomy companion"
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 46
            height: parent.height

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    text: "SENO // " + root.senomy.state.toUpperCase()
                    color: root.senomy.state === "critical" ? Config.Theme.danger : Config.Theme.accent
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.senomy.message
                    color: Config.Theme.foreground
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: insightsArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleInsights()
            }
            ToolTip.visible: insightsArea.containsMouse
            ToolTip.delay: 450
            ToolTip.text: root.insightsOpen ? "Close Senomy Insights" : "Open Senomy Insights"
        }
    }
}
