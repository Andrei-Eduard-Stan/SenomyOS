import QtQuick
import "../../config" as Config

FocusScope {
    id: root
    required property var model
    property int cellHeight: Config.DirectoryStyle.touchMode ? 48 : Math.max(38, Math.ceil(22 * Config.DirectoryStyle.textScale + 16))
    readonly property int gap: 2
    implicitHeight: 22 + 6 * cellHeight + 5 * gap
    function focusDate() {
        const key = model.navigation.key(model.focusedDate);
        for (let i = 0; i < cells.count; ++i) {
            const cell = cells.itemAt(i);
            if (cell && model.navigation.key(cell.date) === key) { cell.forceActiveFocus(); return; }
        }
    }
    function requestFocus() { Qt.callLater(root.focusDate); }
    Connections {
        target: root.model
        // The local clock or a saved week-start change can move/rebuild cells
        // without a key event. Keep the visible outline with the focused date,
        // and leave header/footer focus alone when the grid does not own it.
        function onFocusedDateChanged() { if (root.activeFocus) root.requestFocus(); }
        function onDatesChanged() { if (root.activeFocus) root.requestFocus(); }
    }
    function handleKey(event) {
        const nav = model.navigation;
        const date = model.focusedDate;
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right)
            model.moveFocus((event.key === Qt.Key_Left ? -1 : 1) * (Qt.locale().textDirection === Qt.RightToLeft ? -1 : 1));
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) model.moveFocus(event.key === Qt.Key_Up ? -7 : 7);
        else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown)
            model.browse((event.key === Qt.Key_PageUp ? -1 : 1) * (event.modifiers & Qt.ControlModifier ? 12 : 1));
        else if (event.key === Qt.Key_Home && event.modifiers & Qt.ControlModifier) model.today();
        else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
            const offset = (date.getDay() - nav.weekStart + 7) % 7;
            model.moveFocus((event.key === Qt.Key_End ? 6 : 0) - offset);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) model.select(date);
        else return;
        event.accepted = true;
        requestFocus();
    }
    Row {
        width: parent.width; height: 22; spacing: root.gap
        layoutDirection: Qt.locale().textDirection
        Repeater {
            model: root.model.navigation.weekdayNames
            delegate: Text {
                required property string modelData
                width: (root.width - 6 * root.gap) / 7; height: 22
                text: modelData; textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                color: Config.DirectoryStyle.muted
                font.family: Config.DirectoryStyle.dataFont
                font.pixelSize: Math.round(10 * Config.DirectoryStyle.textScale)
            }
        }
    }
    Grid {
        y: 22; width: parent.width; columns: 7; spacing: root.gap
        layoutDirection: Qt.locale().textDirection
        Repeater {
            id: cells
            model: root.model.dates
            delegate: CalendarDayCell {
                required property var modelData
                date: modelData
                width: (root.width - 6 * root.gap) / 7; height: root.cellHeight
                selected: root.model.navigation.key(date) === root.model.selectedKey
                today: root.model.navigation.key(date) === root.model.navigation.todayKey
                inMonth: date.getMonth() === root.model.viewedMonth.getMonth()
                eventCount: root.model.dayCounts[root.model.navigation.key(date)] || 0
                enabled: root.model.navigation.supported(date)
                activeFocusOnTab: selected || activeFocus
                onPressed: root.model.focusedDate = root.model.navigation.civil(date)
                onClicked: {
                    // Selection may replace this delegate (adjacent month).
                    // Queue focus before invalidating its creation context.
                    const calendar = root.model;
                    root.requestFocus();
                    calendar.select(date);
                }
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: event => root.handleKey(event)
            }
        }
    }
}
