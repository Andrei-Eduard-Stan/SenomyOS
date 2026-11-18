import QtQuick
import ".." as UI
import QtQuick.Controls
import ".."
import "../../config" as Config

Column {
    id: root
    required property var model
    property real reservedHeight: desiredHeight
    readonly property int rowHeight: Math.max(Config.QuickPanelStyle.target, 52 * Config.DirectoryStyle.textScale)
    readonly property int desiredHeight: header.height + (model.entries.length ? Math.min(3, model.entries.length) * rowHeight : empty.implicitHeight + 4) + (limit.visible ? limit.implicitHeight + 4 : 0)
    readonly property string stateMessage: !model.available ? "Calendar service unavailable. Saved data is retained."
        : model.loading ? "Loading events…"
        : model.dayError ? model.dayError
        : !model.hasSources ? (model.service && (model.service.sources || []).length ? "No visible calendar sources." : "No calendar source available.")
        : model.entries.length === 0 ? "No events for this day." : ""
    signal eventRequested(var entry)
    signal addEventRequested(string date)
    spacing: 0
    Row {
        id: header
        width: parent.width; height: Config.QuickPanelStyle.target; spacing: 4
        Column {
            width: parent.width - add.width - 4
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width
                text: Qt.formatDate(root.model.navigation.selectedDate, "dddd, d MMM yyyy")
                textFormat: Text.PlainText; elide: Text.ElideRight
                color: Config.DirectoryStyle.ink
                font.family: Config.DirectoryStyle.bodyFont
                font.pixelSize: Config.DirectoryStyle.bodySize
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: (root.model.selectedKey === root.model.navigation.todayKey ? "TODAY" : "SELECTED")
                    + (root.model.service && root.model.service.preferences.timezone && root.model.service.preferences.timezone !== "local" ? " · " + root.model.service.preferences.timezone : "")
                textFormat: Text.PlainText; elide: Text.ElideRight
                color: Config.DirectoryStyle.muted
                font.family: Config.DirectoryStyle.dataFont; font.pixelSize: Config.QuickPanelStyle.metadataSize
            }
        }
        DashboardButton {
            id: add
            objectName: "quick-calendar-add"
            width: Config.QuickPanelStyle.target; height: width
            text: "+"; headerControl: true; labelSize: 20
            accessibleLabel: "Add event on " + root.model.selectedKey
            enabled: root.model.canCreate
            onClicked: root.addEventRequested(root.model.selectedKey)
        }
    }
    Text {
        id: empty
        objectName: "quick-calendar-empty"
        visible: !!root.stateMessage
        width: parent.width; topPadding: 4
        text: root.stateMessage; textFormat: Text.PlainText; wrapMode: Text.WordWrap
        color: Config.DirectoryStyle.muted
        font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.detailSize
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
    FocusScrollArea {
        id: agenda
        objectName: "quick-calendar-agenda-list"
        visible: !root.stateMessage && root.model.entries.length > 0
        width: parent.width
        height: Math.max(0, root.reservedHeight - header.height - (limit.visible ? limit.implicitHeight + 4 : 0))
        contentHeight: rows.height
        interactive: contentHeight > height
        ScrollBar.vertical: ShellScrollBar { policy: ScrollBar.AsNeeded }
        Column {
            id: rows; width: agenda.width - (agenda.contentHeight > agenda.height ? 10 : 0)
            Repeater {
                model: root.model.entries
                delegate: AbstractButton {
                    id: entryButton
                    required property var modelData
                    required property int index
                    width: rows.width; height: root.rowHeight
                    leftPadding:Config.DirectoryStyle.controlInset;rightPadding:Config.DirectoryStyle.controlInset
                    topPadding:Config.DirectoryStyle.controlVerticalInset;bottomPadding:Config.DirectoryStyle.controlVerticalInset;hoverEnabled: true; focusPolicy: Qt.StrongFocus
                    objectName: "quick-calendar-event-" + index
                    readonly property string timeLabel: modelData.kind === "note" ? "Note" : modelData.allDay ? "All day" : modelData.date < root.model.selectedKey ? "Continues" : modelData.time
                    Accessible.name: modelData.title + ". " + timeLabel + ". " + (modelData.endTime || "") + ". " + (modelData.location || "") + ". " + modelData.calendar
                    onClicked: root.eventRequested(modelData)
                    background: Rectangle {
                        color: "transparent"
                        border.width: 0; border.color: Config.DirectoryStyle.ink
                    }
                    UI.ButtonHoverFrame { focused: entryButton.visualFocus; anchors.fill: parent; engaged: entryButton.enabled && entryButton.hovered }
                    contentItem: Row {
                        spacing: 10
                        Text {
                            width: Math.min(90 * Config.DirectoryStyle.textScale, entryButton.availableWidth * 0.3)
                            anchors.verticalCenter: parent.verticalCenter
                            text: entryButton.timeLabel; textFormat: Text.PlainText; elide: Text.ElideRight
                            font.family: Config.DirectoryStyle.dataFont; font.pixelSize: Config.QuickPanelStyle.metadataSize
                            color: Config.DirectoryStyle.muted
                        }
                        Column {
                            width: parent.width - parent.children[0].width - 10
                            anchors.verticalCenter: parent.verticalCenter; spacing: 3
                            Text {
                                width: parent.width; text: entryButton.modelData.title; textFormat: Text.PlainText; elide: Text.ElideRight
                                color: Config.DirectoryStyle.ink; font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.bodySize
                            }
                            Text {
                                width: parent.width
                                text: entryButton.modelData.calendar + (entryButton.modelData.location ? " · " + entryButton.modelData.location : "")
                                    + (entryButton.modelData.pending ? " · Queued offline" : "") + (entryButton.modelData.conflict ? " · Sync conflict" : "")
                                textFormat: Text.PlainText; elide: Text.ElideRight
                                color: Config.DirectoryStyle.muted; font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.detailSize
                            }
                        }
                    }
                    ToolTip {
                        id: eventTip
                        visible: entryButton.hovered
                        delay: 700
                        text: entryButton.Accessible.name
                        contentItem: Text {
                            objectName: "quick-calendar-tooltip-" + entryButton.index
                            text: eventTip.text
                            textFormat: Text.PlainText
                            font: eventTip.font
                            wrapMode: Text.Wrap
                            color: eventTip.palette.toolTipText
                        }
                    }
                }
            }
        }
    }
    Text {
        id: limit
        visible: root.model.dayTruncated || root.model.monthTruncated || !!root.model.monthError
        width: parent.width; topPadding: 4
        text: root.model.monthError ? "Event indicators unavailable. Open Calendar to review." : "Event limit reached. Open Calendar for more."
        wrapMode: Text.WordWrap; textFormat: Text.PlainText
        color: Config.DirectoryStyle.muted; font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.detailSize
    }
}
