import QtQuick
import ".." as UI
import QtQuick.Controls
import ".."
import "CalendarFormat.js" as Format
import "../../config" as Config
import "../../services/calendar" as CalendarState

FocusScrollArea {
    id: root
    property bool compactChrome: false
    property var service: null
    property bool showAgenda: true
    signal eventRequested(var entry)
    signal addEventRequested(string date)
    signal addNoteRequested(string date)
    signal viewDayRequested(string date)
    signal importRequested()
    function choose(date,item) {navigation.select(date);if(service)dayActions.openFor(item,navigation.selectedKey);else requestDateFocus();}
    CalendarDayActions {id:dayActions;objectName:"calendar-date-actions";service:root.service;onAddEventRequested:date=>root.addEventRequested(date);onAddNoteRequested:date=>root.addNoteRequested(date);onViewDayRequested:date=>root.viewDayRequested(date);onImportRequested:root.importRequested();onEventRequested:entry=>root.eventRequested(entry)}
    property var navigation: (CalendarState.Navigation)
    readonly property bool compact: width < (Config.DirectoryStyle.touchMode ? 416 : 336)
    readonly property var dates: compact ? navigation.weekDays : navigation.monthDays
    property bool pickerOpen: false
    property string entryError: ""
    contentWidth:Math.max(1,width-10)
    contentHeight: body.implicitHeight
    ScrollBar.vertical: ShellScrollBar {}
    function focusSelected() {
        for (let i = 0; i < days.count; ++i) {
            const item = days.itemAt(i);
            if (item && item.selected) { item.forceActiveFocus(); return; }
        }
    }
    Timer { id: focusTimer; interval: 1; onTriggered: root.focusSelected() }
    function requestDateFocus() { focusTimer.restart(); }
    function select(date) { navigation.select(date); requestDateFocus(); }
    // One sweep per query/range update, rather than filtering every event in
    // each cell's text, visibility and accessibility bindings.
    readonly property var dayCounts: {
        const keys=dates.map(d=>navigation.key(d));const positions={};const delta=Array(keys.length+1).fill(0);const result={};
        keys.forEach((key,i)=>positions[key]=i);
        for(const entry of service?service.entries:[]){
            const first=entry.date<keys[0]?keys[0]:entry.date;
            const last=entry.lastDate>keys[keys.length-1]?keys[keys.length-1]:entry.lastDate;
            if(first<=last&&positions[first]!==undefined&&positions[last]!==undefined){delta[positions[first]]++;delta[positions[last]+1]--;}
        }
        let count=0;keys.forEach((key,i)=>{count+=delta[i];result[key]=count;});return result;
    }
    function eventCount(date) {return dayCounts[navigation.key(date)]||0;}
    function openPicker() {
        monthChoice.currentIndex = navigation.selectedDate.getMonth();
        yearEntry.text = String(navigation.selectedDate.getFullYear());
        dateEntry.text = Format.display(navigation.selectedKey,navigation.dateFormat);
        entryError = "";
        pickerOpen = true;
        pickerFocus.restart();
    }
    Timer { id: pickerFocus; interval: 1; onTriggered: yearEntry.forceActiveFocus() }
    function closePicker() { pickerOpen = false; entryError = ""; requestDateFocus(); }
    function changeDraftYear(delta) {
        const year = Number(yearEntry.text);
        if (!/^\d{1,4}$/.test(yearEntry.text) || !Number.isInteger(year) || year + delta < navigation.minimumYear || year + delta > navigation.maximumYear) {
            entryError = "Choose a year from 1 to 9999."; return;
        }
        yearEntry.text = String(year + delta); entryError = "";
    }
    function applyPeriod() {
        if (!/^\d{1,4}$/.test(yearEntry.text) || !navigation.selectMonthYear(Number(yearEntry.text), monthChoice.currentIndex)) {
            entryError = "Choose a year from 1 to 9999."; yearEntry.forceActiveFocus(); return;
        }
        closePicker();
    }
    function applyDate() {
        if (!navigation.selectDateText(Format.iso(dateEntry.text,navigation.dateFormat))) {
            entryError = "Enter a real date as "+Format.hint(navigation.dateFormat)+" (years 0001–9999)."; dateEntry.forceActiveFocus(); return;
        }
        closePicker();
    }
    Keys.onEscapePressed: event => {
        if (pickerOpen) closePicker(); else event.accepted = false;
    }
    function handleKey(event) {
        const key = event.key;
        if (key === Qt.Key_Left || key === Qt.Key_Right)
            navigation.moveDays((key === Qt.Key_Left ? -1 : 1) * (Qt.locale().textDirection === Qt.RightToLeft ? -1 : 1));
        else if (key === Qt.Key_Up || key === Qt.Key_Down)
            navigation.moveDays((key === Qt.Key_Up ? -1 : 1) * (compact ? 1 : 7));
        else if (key === Qt.Key_PageUp || key === Qt.Key_PageDown)
            navigation.moveMonths((key === Qt.Key_PageUp ? -1 : 1) * (event.modifiers & Qt.ControlModifier ? 12 : 1));
        else if (key === Qt.Key_Home && event.modifiers & Qt.ControlModifier) navigation.goToday();
        else if (key === Qt.Key_Home || key === Qt.Key_End) navigation.weekEdge(key === Qt.Key_End);
        else return;
        event.accepted = true;
        requestDateFocus();
    }
    Column {
        id: body
        width: parent.width
        spacing: 12
        Row {
            width: parent.width; spacing: 6
            DashboardButton {
                objectName: "calendar-choose-period"
                width: Math.max(1, parent.width - 100); height: 44
                text: root.navigation.monthTitle.toUpperCase() + " ⌄"
                headerControl: true; labelSize: root.compact ? 12 : 14
                accessibleLabel: "Choose month, year or a specific date. " + root.navigation.monthTitle
                active: root.pickerOpen
                onClicked: root.pickerOpen ? root.closePicker() : root.openPicker()
            }
            DashboardButton {
                objectName: "calendar-previous-period"
                width: 44; height: 44; text: "‹"; headerControl: true; labelSize: 20
                accessibleLabel: root.compact ? "Previous week" : "Previous month"
                enabled: !root.pickerOpen && (root.compact ? root.navigation.canMoveDays(-7) : root.navigation.canMoveMonths(-1))
                onClicked: root.compact ? root.navigation.moveDays(-7) : root.navigation.moveMonths(-1)
            }
            DashboardButton {
                objectName: "calendar-next-period"
                width: 44; height: 44; text: "›"; headerControl: true; labelSize: 20
                accessibleLabel: root.compact ? "Next week" : "Next month"
                enabled: !root.pickerOpen && (root.compact ? root.navigation.canMoveDays(7) : root.navigation.canMoveMonths(1))
                onClicked: root.compact ? root.navigation.moveDays(7) : root.navigation.moveMonths(1)
            }
        }
        Column {
            visible: root.pickerOpen; width: parent.width; spacing: 8
            Text {
                text: "MONTH"; font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 11; color: Config.DirectoryStyle.muted
            }
            ShellComboBox {
                id: monthChoice; objectName: "calendar-month-choice"
                width: parent.width; model: root.navigation.monthNames
                Accessible.name: "Choose month"
            }
            Text {
                text: "YEAR // 1–9999"; font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 11; color: Config.DirectoryStyle.muted
            }
            Row {
                width: parent.width; spacing: 6
                DashboardButton {
                    objectName: "calendar-previous-year"; width: 44; height: 44; text: "−"; labelSize: 20
                    accessibleLabel: "Previous year"
                    onClicked: root.changeDraftYear(-1)
                }
                ShellTextField {
                    id: yearEntry; objectName: "calendar-year-entry"
                    width: parent.width - 100; maximumLength: 4
                    inputMethodHints: Qt.ImhDigitsOnly
                    Accessible.name: "Year from 1 to 9999"
                    onAccepted: root.applyPeriod()
                }
                DashboardButton {
                    objectName: "calendar-next-year"; width: 44; height: 44; text: "+"; labelSize: 20
                    accessibleLabel: "Next year"
                    onClicked: root.changeDraftYear(1)
                }
            }
            Text {
                text: "OR GO TO DATE // YYYY-MM-DD"; font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 11; color: Config.DirectoryStyle.muted
            }
            Row {
                width: parent.width; spacing: 6
                ShellTextField {
                    id: dateEntry; objectName: "calendar-date-entry"
                    width: parent.width - 90; maximumLength: 10; placeholderText: Format.hint(root.navigation.dateFormat)
                    Accessible.name: "Go to date in "+Format.hint(root.navigation.dateFormat)+" format"
                    onAccepted: root.applyDate()
                }
                DashboardButton {
                    objectName: "calendar-go-to-date"; width: 84; height: 44; text: "GO"
                    accessibleLabel: "Go to the entered date"
                    onClicked: root.applyDate()
                }
            }
            Text {
                visible: root.entryError.length > 0; width: parent.width; text: root.entryError
                textFormat: Text.PlainText; wrapMode: Text.WordWrap
                font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 12; color: Config.Theme.danger
            }
            Row {
                width: parent.width; spacing: 6
                DashboardButton {
                    objectName: "calendar-apply-period"; width: (parent.width - 6) / 2; text: "APPLY"
                    accessibleLabel: "Apply chosen month and year"
                    onClicked: root.applyPeriod()
                }
                DashboardButton {
                    objectName: "calendar-cancel-period"; width: (parent.width - 6) / 2; text: "CANCEL"
                    onClicked: root.closePicker()
                }
            }
        }
        Text {
            visible: !root.pickerOpen
            width: parent.width; text: Qt.formatDate(root.navigation.selectedDate, root.navigation.dateFormat==="us"?"dddd, MMMM d, yyyy":"dddd, d MMMM yyyy")
            textFormat: Text.PlainText; wrapMode: Text.WordWrap
            font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 14; color: Config.DirectoryStyle.ink
        }
        Text {
            visible: root.compact && !root.pickerOpen; width: parent.width
            text: "WEEK OF " + Qt.formatDate(root.dates[0], "d MMM") + " · use arrows to browse weeks"
            textFormat: Text.PlainText; wrapMode: Text.WordWrap
            font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 11; color: Config.DirectoryStyle.muted
        }
        Row {
            visible: !root.compact && !root.pickerOpen; width: parent.width; spacing: 4
            layoutDirection: Qt.locale().textDirection
            Repeater {
                model: root.navigation.weekdayNames
                delegate: Text {
                    required property string modelData
                    width: (body.width - 24) / 7; height: 24; text: modelData
                    font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 11
                    color: Config.DirectoryStyle.muted; horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        Grid {
            visible: !root.pickerOpen
            width: parent.width; columns: root.compact ? 1 : 7; spacing: 4
            layoutDirection: Qt.locale().textDirection
            Repeater {
                id: days
                model: root.dates
                delegate: Rectangle {
                    id: day
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.navigation.key(modelData) === root.navigation.selectedKey
                    readonly property bool today: root.navigation.key(modelData) === root.navigation.todayKey
                    readonly property bool inMonth: modelData.getMonth() === root.navigation.monthStart.getMonth()
                    enabled: root.navigation.supported(modelData)
                    opacity: enabled ? 1 : 0.35
                    objectName: "calendar-day-" + index
                    width: root.compact ? body.width : (body.width - 24) / 7
                    height: Config.DirectoryStyle.touchMode ? 56 : 44
                    activeFocusOnTab: (selected && !root.pickerOpen) || activeFocus
                    Accessible.role: Accessible.Button
                    Accessible.onPressAction: root.choose(modelData,day)
                    Accessible.name: Qt.formatDate(modelData, "dddd, d MMMM yyyy") + (today ? ". Today" : "") + (selected ? ". Selected" : "") + (root.service ? ". "+root.eventCount(modelData)+" events" : "")
                    color: "transparent"
                    border.width: 0; border.color: Config.DirectoryStyle.ink
                    Keys.onPressed: event => root.handleKey(event)
                    Keys.onReturnPressed: root.choose(modelData,day)
                    Keys.onSpacePressed: root.choose(modelData,day)
                    Text {
                        x: root.compact ? 12 : 0
                        width: parent.width - (root.compact ? 100 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.compact ? Qt.formatDate(day.modelData, "ddd, d MMM") : String(day.modelData.getDate())
                        textFormat: Text.PlainText
                        horizontalAlignment: root.compact ? Text.AlignLeft : Text.AlignHCenter
                        font.family: Config.DirectoryStyle.headingFont; font.pixelSize: root.compact ? 13 : 15
                        color: day.inMonth || root.compact ? Config.DirectoryStyle.ink : Config.DirectoryStyle.dim
                    }
                    Text {
                        visible: root.compact; width: 80
                        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        text: day.today ? "TODAY" : day.selected ? "SELECTED" : ""
                        font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 10
                        color: Config.DirectoryStyle.muted; horizontalAlignment: Text.AlignRight
                    }
                    Rectangle {
                        visible: day.today && !root.compact; width: 5; height: 5; radius: 3
                        anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 9; color: Config.Theme.accent
                    }
                    Text {
                        visible:root.eventCount(day.modelData)>0
                        anchors.right:parent.right;anchors.rightMargin:root.compact?90:4;y:parent.height-15
                        text:root.eventCount(day.modelData);font.family:Config.DirectoryStyle.dataFont;font.pixelSize:9;color:Config.DirectoryStyle.muted
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Config.DirectoryStyle.rule }
                    UI.ButtonHoverFrame { focusTarget: day; pointerTarget: area; selected: day.selected; anchors.fill: parent; engaged: day.enabled && area.containsMouse }
                    MouseArea {
                        id: area
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons:Qt.LeftButton|Qt.RightButton
                        onClicked: root.choose(day.modelData,day)
                    }
                }
            }
        }
        DashboardButton {
            objectName: "calendar-today"; width: parent.width; text: "TODAY"
            onClicked: { root.navigation.goToday(); root.closePicker(); }
        }
        Text {
            visible:!!(root.service&&root.service.preferences.weekNumbers&&!root.pickerOpen)
            width:parent.width;text:"ISO WEEK "+root.navigation.isoWeek(root.navigation.selectedDate)
            font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted
        }
        CalendarAgenda {
            visible:!!(root.service&&root.showAgenda&&!root.pickerOpen)
            width:parent.width;height:contentHeight;embedded:true
            entries:root.service?root.service.entries:[];dateFilter:root.navigation.selectedKey;heading:"SELECTED DAY"
            onEventRequested:entry=>root.eventRequested(entry)
        }
        Text {
            visible: !root.compactChrome
            width: parent.width; text: root.service ? "DISPLAY ZONE // "+(root.service.preferences.timezone||"local") : Qt.formatDateTime(root.navigation.timeSource.date, "HH:mm · t") + " // LOCAL TIME"
            textFormat: Text.PlainText; wrapMode: Text.WordWrap
            font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 12; color: Config.DirectoryStyle.muted
        }
        Text {
            visible: !root.compactChrome
            width: parent.width; text: root.service ? (root.service.available ? "Saved local events // reminders run independently of this panel" : "Calendar service unavailable // saved data is retained") : "Date browsing // event service is not connected."
            textFormat: Text.PlainText; wrapMode: Text.WordWrap
            font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 12; color: Config.DirectoryStyle.muted
        }
    }
}
