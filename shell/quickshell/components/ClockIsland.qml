import QtQuick
import QtQuick.Controls
import Quickshell
import "../config" as Config

SenomyFrame {
    id: root
    frameKey: ""
    fillKey: "clock"
    borderType: "none"
    nativeFrameEnabled: false
    fullHeightFrame: true
    railBackground: true
    stateUnderlineEnabled: false
    skinSpec: ({contentPadding: {left: 9, right: 9, top: touchMode ? 4 : 6, bottom: touchMode ? 4 : 6}})
    property bool calendarOpen: false
    property bool notificationsOpen: false
    property var notifications
    property bool compact: false
    readonly property bool touchMode: Config.DirectoryStyle.touchMode
    readonly property int minimumWidth: touchMode ? 136 : 128
    readonly property int unread: notifications ? notifications.unreadCount : 0
    readonly property bool quiet: notifications ? notifications.dnd : false
    property alias calendarAnchor: calendarButton
    property alias notificationsAnchor: notificationButton
    signal toggleCalendar()
    signal toggleNotifications()
    implicitWidth: compact ? (touchMode ? 160 : 148) : (touchMode ? 196 : 184)
    width: implicitWidth
    height: Config.Theme.islandHeight
    active: calendarOpen || notificationsOpen
    SilverIslandFrame {
        drawFill: false
        parent: root
        anchors.fill: parent
        z: -1
        active: false
        hovered: calendarButton.hovered || notificationButton.hovered || calendarButton.visualFocus || notificationButton.visualFocus
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Row {
        parent: root
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0
        Button {
            id: calendarButton
            objectName: "rail-calendar-button"
            width: parent.width - notificationButton.width - parent.spacing
            height: parent.height
            focusPolicy: Qt.StrongFocus
            hoverEnabled: true
            padding: 0
            Accessible.name: "Open calendar. " + Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy, HH:mm")
            Keys.onReturnPressed: clicked()
            onClicked: root.toggleCalendar()
            background: ChamferHover {
                objectName:"clock-calendar-hover"
                leftCorner:true
                highlighted:calendarButton.enabled && calendarButton.hovered
                selected: root.calendarOpen
                focused: calendarButton.visualFocus
            }
            contentItem: Item {
                Column {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 2
                    Text {
                        width: parent.width
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        color: Config.Theme.foreground
                        font.family: "Audiowide"
                        font.pixelSize: root.compact ? 15 : 18
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 12
                    }
                    Text {
                        visible: !root.compact
                        width: parent.width
                        text: Qt.formatDate(clock.date, "ddd  dd MMM").toUpperCase()
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        color: Config.DirectoryStyle.muted
                        font.family: "Audiowide"
                        font.pixelSize: 8
                        font.letterSpacing: 0.4
                    }
                }
            }
        }
        Button {
            id: notificationButton
            padding: 0
            objectName: "rail-notification-button"
            width: root.touchMode ? 56 : 52
            height: parent.height
            focusPolicy: Qt.StrongFocus
            hoverEnabled: true
            Accessible.name: "Open notifications. " + root.unread + " unread" + (root.quiet ? ". Do Not Disturb on" : "")
            Keys.onReturnPressed: clicked()
            onClicked: root.toggleNotifications()
            background: ChamferHover {
                objectName:"clock-notifications-hover"
                rightCorner:true
                highlighted:notificationButton.enabled && notificationButton.hovered
                selected: root.notificationsOpen
                focused: notificationButton.visualFocus
            }
            contentItem: Item {
                Image {
                    objectName: "rail-notification-bell"
                    width: 28; height: 28
                    anchors.centerIn: parent
                    source: "../assets/icons/notifications.svg"
                    fillMode: Image.PreserveAspectFit
                    opacity: root.quiet ? 0.6 : 1
                    Rectangle {
                        visible: root.quiet
                        width: 26; height: 2
                        anchors.centerIn: parent
                        rotation: -45
                        color: Config.Theme.foreground
                    }
                }
                Rectangle {
                    objectName: "rail-notification-badge"
                    visible: root.unread > 0
                    anchors.top: parent.top; anchors.right: parent.right
                    anchors.topMargin: 5; anchors.rightMargin: 5
                    width: root.unread > 99 ? 22 : root.unread > 9 ? 18 : 14
                    height: width; radius: width / 2
                    color: Config.Theme.accent
                    Text {
                        anchors.centerIn: parent
                        text: root.unread > 99 ? "99+" : String(root.unread)
                        color: Config.Theme.background
                        font.family: Config.DirectoryStyle.dataFont
                        font.pixelSize: root.unread > 99 ? 8 : 9
                        font.bold: true
                    }
                }
            }
        }
    }
}
