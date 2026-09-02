import QtQuick
import QtQuick.Controls
import Quickshell
import "../config" as Config

SenomyFrame {
    id: root

    property bool calendarOpen: false
    property bool notificationsOpen: false
    property var notifications
    property alias calendarAnchor: calendarArea
    property alias notificationsAnchor: notificationArea
    signal toggleCalendar()
    signal toggleNotifications()
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

        Item {
            width: parent.width - 44
            height: parent.height
            Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
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
            MouseArea {
                id: calendarArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleCalendar()
            }
            ToolTip.visible: calendarArea.containsMouse && !root.calendarOpen
            ToolTip.delay: 450
            ToolTip.text: "Open calendar"
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
            Rectangle {
                visible: root.notifications && root.notifications.unreadCount > 0
                anchors.right: parent.right
                anchors.top: parent.top
                width: 18
                height: 18
                radius: 9
                color: Config.Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: String(Math.min(99, root.notifications ? root.notifications.unreadCount : 0))
                    color: Config.Theme.background
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 7
                    font.weight: Font.Bold
                }
            }
            MouseArea {
                id: notificationArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleNotifications()
            }
            ToolTip.visible: notificationArea.containsMouse && !root.notificationsOpen
            ToolTip.delay: 450
            ToolTip.text: root.notifications && root.notifications.serverEnabled
                ? "Open notification history" : "Native history awaits notification migration"
        }
    }
}
