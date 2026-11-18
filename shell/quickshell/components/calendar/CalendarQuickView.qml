import QtQuick
import QtQuick.Controls
import ".."
import "../../config" as Config
import "../../services/calendar" as CalendarState

FocusScrollArea {
    id: root
    property var service: null
    property bool active: false
    property real agendaReserve: 0
    readonly property var model: calendar
    signal dismissRequested()
    signal openCalendarRequested(string route)
    signal eventRequested(var entry)
    signal addEventRequested(string date)
    implicitHeight: body.implicitHeight
    contentHeight: body.implicitHeight
    contentWidth: width
    interactive: contentHeight > height
    ScrollBar.vertical: ShellScrollBar { policy: ScrollBar.AsNeeded }
    function focusSelected() { calendar.showSelected(); grid.requestFocus(); }
    function reserveAgenda() { if (active) agendaReserve = Math.max(agendaReserve, agenda.desiredHeight); }
    onActiveChanged: if (active) { agendaReserve = agenda.desiredHeight; contentY = 0; }
    CalendarState.CalendarQuickModel { id: calendar; service: root.service; active: root.active }
    Column {
        id: body
        width: root.width - (root.contentHeight > root.height ? 10 : 0)
        spacing: 0
        Row {
            width: parent.width; height: Math.max(Config.QuickPanelStyle.target, identity.implicitHeight); spacing: 8
            Column {
                id: identity
                width: parent.width - close.width - 8
                anchors.verticalCenter: parent.verticalCenter; spacing: 4
                Text {
                    text: "CALENDAR"; textFormat: Text.PlainText
                    color: Config.DirectoryStyle.ink; font.family: Config.QuickPanelStyle.headingFont
                    font.pixelSize: Config.QuickPanelStyle.titleSize
                }
                Text {
                    objectName: "quick-calendar-current-date"
                    width: parent.width
                    text: Qt.formatDate(calendar.navigation.today, "ddd, d MMMM yyyy")
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    color: Config.DirectoryStyle.muted; font.family: Config.DirectoryStyle.bodyFont
                    font.pixelSize: Config.DirectoryStyle.detailSize
                }
            }
            DashboardButton {
                id: close; objectName: "quick-calendar-close"
                width: Config.QuickPanelStyle.target; height: width
                text: "×"; headerControl: true
                accessibleLabel: "Close calendar"
                onClicked: root.dismissRequested()
            }
        }
        Item { width: 1; height: 16 }
        Row {
            width: parent.width; height: Math.max(Config.QuickPanelStyle.target, monthIdentity.implicitHeight); spacing: 4
            Column {
                id: monthIdentity
                width: parent.width - today.width - previous.width - next.width - 12
                anchors.verticalCenter: parent.verticalCenter; spacing: 2
                Text {
                    objectName: "quick-calendar-month"
                    width: parent.width
                    text: Qt.formatDate(calendar.viewedMonth, "MMMM")
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    color: Config.DirectoryStyle.ink; font.family: Config.DirectoryStyle.valueFont
                    font.pixelSize: Math.round(20 * Config.DirectoryStyle.textScale)
                    fontSizeMode: Text.HorizontalFit; minimumPixelSize: 14
                }
                Text {
                    text: Qt.formatDate(calendar.viewedMonth, "yyyy"); textFormat: Text.PlainText
                    color: Config.DirectoryStyle.muted; font.family: Config.DirectoryStyle.dataFont
                    font.pixelSize: Config.QuickPanelStyle.metadataSize
                }
            }
            DashboardButton {
                id: today; objectName: "quick-calendar-today"
                width: 62; height: Config.QuickPanelStyle.target
                text: "Today"; headerControl: true; labelSize: Config.DirectoryStyle.detailSize
                accessibleLabel: "Select today. Control+Home"
                onClicked: { calendar.today(); grid.requestFocus(); }
            }
            DashboardButton {
                id: previous; objectName: "quick-calendar-previous"
                width: Config.QuickPanelStyle.target; height: width
                text: "‹"; headerControl: true; labelSize: 24
                accessibleLabel: "Previous month. Page Up"
                enabled: calendar.canBrowse(-1)
                onClicked: calendar.browse(-1)
                HoverHandler { id: previousHover }
                ToolTip.visible: previousHover.hovered; ToolTip.text: accessibleLabel; ToolTip.delay: 500
            }
            DashboardButton {
                id: next; objectName: "quick-calendar-next"
                width: Config.QuickPanelStyle.target; height: width
                text: "›"; headerControl: true; labelSize: 24
                accessibleLabel: "Next month. Page Down"
                enabled: calendar.canBrowse(1)
                onClicked: calendar.browse(1)
                HoverHandler { id: nextHover }
                ToolTip.visible: nextHover.hovered; ToolTip.text: accessibleLabel; ToolTip.delay: 500
            }
        }
        Item { width: 1; height: 12 }
        CalendarQuickGrid {
            id: grid
            objectName: "quick-calendar-grid"
            width: parent.width; height: implicitHeight
            model: calendar
        }
        Item { width: 1; height: 12 }
        Rectangle { width: parent.width; height: 1; color: Config.DirectoryStyle.rule }
        Item { width: 1; height: 4 }
        CalendarQuickAgenda {
            id: agenda
            width: parent.width; height: reservedHeight
            model: calendar
            reservedHeight: Math.max(root.agendaReserve, desiredHeight)
            onDesiredHeightChanged: root.reserveAgenda()
            onEventRequested: entry => root.eventRequested(entry)
            onAddEventRequested: date => root.addEventRequested(date)
        }
        Item { width: 1; height: 8 }
        Row {
            width: parent.width; height: Config.QuickPanelStyle.target; spacing: 8
            DashboardButton {
                objectName: "open-calendar-workspace"
                width: (parent.width - 8) * 0.6; height: parent.height
                text: "Open Calendar ›"; headerControl: true; centered: false
                labelSize: Config.DirectoryStyle.detailSize
                accessibleLabel: "Open full calendar workspace"
                onClicked: root.openCalendarRequested("calendar")
            }
            DashboardButton {
                objectName: "open-calendar-briefing"
                width: (parent.width - 8) * 0.4; height: parent.height
                text: "Briefing ›"; headerControl: true
                labelSize: Config.DirectoryStyle.detailSize
                accessibleLabel: "Open upcoming event briefing"
                onClicked: root.openCalendarRequested("calendar/briefing")
            }
        }
    }
}
