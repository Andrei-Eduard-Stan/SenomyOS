import QtQuick
import QtQuick.Window
import Quickshell
import "interaction" as Interaction
import "calendar" as CalendarUi
import "../config" as Config
import "../services/calendar" as CalendarState

Interaction.QuickPopoverWindow {
    id: root
    property var calendarService: null
    property string screenName: ""
    readonly property int displayedYear: calendarView.model.viewedMonth.getFullYear()
    readonly property int displayedMonth: calendarView.model.viewedMonth.getMonth()
    signal openCalendarRequested(string route)

    readonly property real availableWidth: (targetScreen || (anchorItem && anchorItem.Window.window)) ? (targetScreen ? targetScreen.width : anchorItem.Screen.width) - 2 * Config.Theme.screenInset : 440
    readonly property real availableHeight: (targetScreen || (anchorItem && anchorItem.Window.window)) ? (targetScreen ? targetScreen.height : anchorItem.Screen.height) - Config.Theme.railHeight - 2 * Config.Theme.screenInset : 800
    implicitWidth: Math.min(availableWidth >= 720 ? 760 : 460, Math.max(1, availableWidth))
    implicitHeight: Math.min(Math.max(1, availableHeight), calendarView.implicitHeight + 2 * popupFrame.contentInset)
    color: "transparent"
    keyboardPriority: true

    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.rect.x: anchorItem ? anchorItem.width / 2 : 0
    anchor.rect.y: -12
    anchor.rect.width: 1
    anchor.rect.height: 1
    focusTarget: card
    onCardShownChanged: if (cardShown) {
        const opening = lease;
        Qt.callLater(function() {
            if (root.requestedOpen && root.cardShown && root.lease === opening) calendarView.focusSelected();
        });
    }
    FocusScope {
        id: card
        anchors.fill: parent
        focus: root.cardShown
        opacity: root.presentationProgress
        transform: Translate {
            y: (1-root.presentationProgress)*Config.Motion.travel

        }

        Keys.onEscapePressed: if (!calendarView.dismissPreview()) root.handleEscape()
        IslandPopupFrame {
            id: popupFrame
            frameKey: "calendar"
            anchors.fill: parent
            tier: "standard"
            motif: "clock-notification"
            active: true
            animate: false
            contentInset: 24
            perimeterCorner: Config.QuickPanelStyle.corner
            CalendarUi.CalendarPopupView {
                id: calendarView
                objectName: "popup-calendar-browser"
                anchors.fill: parent
                service: root.calendarService
                active: root.requestedOpen
                onDismissRequested: root.dismiss()
                onOpenCalendarRequested: route => root.openCalendarRequested(route)
                onEventRequested: entry => { if (root.calendarService) root.calendarService.open(entry); }
                onAddEventRequested: date => { if (root.calendarService) root.calendarService.compose("event", date, root.screenName); }
            }
        }
    }
}
