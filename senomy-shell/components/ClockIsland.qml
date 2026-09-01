import QtQuick
import QtQuick.Controls
import Quickshell
import "../config" as Config

SenomyFrame {
    id: root

    property bool calendarOpen: false
    property alias calendarAnchor: clockArea
    width: 188
    height: Config.Theme.islandHeight
    motif: "clock-notification"
    active: calendarOpen

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        anchors.fill: parent
        spacing: 10

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 44
            spacing: 1
            Text {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Config.Theme.foreground
                font.family: Config.Theme.fontFamily
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Text {
                text: Qt.formatDate(clock.date, "ddd dd MMM").toUpperCase()
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 8
            }
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 40
            Image {
                anchors.centerIn: parent
                width: 19
                height: 19
                source: "../assets/icons/notifications.svg"
                fillMode: Image.PreserveAspectFit
                opacity: 0.7
            }
        }
    }

    MouseArea {
        id: clockArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.calendarOpen = !root.calendarOpen
    }
    ToolTip.visible: clockArea.containsMouse && !root.calendarOpen
    ToolTip.delay: 450
    ToolTip.text: "Open calendar"
}
