pragma Singleton
import QtQuick
import Quickshell

// Civil-date navigation only. Event timezones and recurrence belong to the engine.
QtObject {
    id: root
    property SystemClock clock: SystemClock { precision: SystemClock.Minutes }
    property var timeSource: clock
    property string todayOverride: ""
    property string dateFormat: "iso"
    readonly property date today: todayOverride ? dateAt(Number(todayOverride.slice(0,4)),Number(todayOverride.slice(5,7))-1,Number(todayOverride.slice(8,10))) : timeSource.date
    readonly property string todayKey: key(today)
    property date selectedDate: civil(today)
    property date monthStart: new Date(today.getFullYear(), today.getMonth(), 1, 12)
    property bool followsToday: true
    readonly property int minimumYear: 1
    readonly property int maximumYear: 9999
    readonly property var monthNames: Array.from({length: 12}, (_, i) => Qt.formatDate(new Date(2024, i, 1, 12), "MMMM"))
    property int weekStartOverride: -1
    readonly property int weekStart: weekStartOverride >= 0 ? weekStartOverride : Qt.locale().firstDayOfWeek % 7
    readonly property string selectedKey: key(selectedDate)
    readonly property string monthTitle: Qt.formatDate(monthStart, "MMMM yyyy")
    readonly property var monthDays: daysForMonth(monthStart)
    readonly property var weekDays: {
        const offset = (selectedDate.getDay() - weekStart + 7) % 7;
        return Array.from({length: 7}, (_, i) => dateAt(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate() - offset + i));
    }
    readonly property var weekdayNames: Array.from({length: 7}, (_, i) => Qt.formatDate(new Date(2024, 0, 7 + weekStart + i, 12), "ddd").toUpperCase())
    onTodayKeyChanged: if (followsToday) goToday()
    // Date's numeric constructor treats years 0..99 as 1900..1999. setFullYear
    // preserves the requested civil year, including direct four-digit entry.
    function dateAt(year, month, day) {
        const result = new Date(2000, 0, 1, 12);
        result.setFullYear(year, month, day);
        return result;
    }
    function supported(date) {
        return Boolean(date && Number.isFinite(date.getTime()) && date.getFullYear() >= minimumYear && date.getFullYear() <= maximumYear);
    }
    function civil(date) { return dateAt(date.getFullYear(), date.getMonth(), date.getDate()); }
    // The same civil-date model serves full Calendar and the quick navigator.
    // A custom grid preserves the user's explicit first-weekday preference,
    // which Qt's locale-only MonthGrid does not expose independently.
    function daysForMonth(month) {
        const first = dateAt(month.getFullYear(), month.getMonth(), 1);
        const offset = (first.getDay() - weekStart + 7) % 7;
        return Array.from({length: 42}, (_, i) => dateAt(first.getFullYear(), first.getMonth(), 1 - offset + i));
    }
    function key(date) { return Qt.formatDate(date, "yyyy-MM-dd"); }
    function isoWeek(date) {
        const utc=new Date(0);utc.setUTCFullYear(date.getFullYear(),date.getMonth(),date.getDate());utc.setUTCHours(0,0,0,0);
        utc.setUTCDate(utc.getUTCDate()+4-(utc.getUTCDay()||7));
        const first=new Date(0);first.setUTCFullYear(utc.getUTCFullYear(),0,1);first.setUTCHours(0,0,0,0);
        return String(utc.getUTCFullYear())+"-W"+String(Math.ceil(((utc-first)/86400000+1)/7)).padStart(2,"0");
    }
    function select(date) {
        if (!supported(date)) return false;
        selectedDate = civil(date);
        monthStart = dateAt(date.getFullYear(), date.getMonth(), 1);
        followsToday = key(date) === todayKey;
        return true;
    }
    function goToday() { select(today); }
    function moveDays(delta) {
        return select(dateAt(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate() + delta));
    }
    function moveMonths(delta) {
        const target = dateAt(monthStart.getFullYear(), monthStart.getMonth() + delta, 1);
        return selectMonthYear(target.getFullYear(), target.getMonth());
    }
    function canMoveMonths(delta) {
        return supported(dateAt(monthStart.getFullYear(), monthStart.getMonth() + delta, 1));
    }
    function canMoveDays(delta) {
        return supported(dateAt(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate() + delta));
    }
    function selectMonthYear(year, month) {
        if (!Number.isInteger(year) || year < minimumYear || year > maximumYear || !Number.isInteger(month) || month < 0 || month > 11) return false;
        const last = dateAt(year, month + 1, 0).getDate();
        return select(dateAt(year, month, Math.min(selectedDate.getDate(), last)));
    }
    function moveYears(delta) { return selectMonthYear(selectedDate.getFullYear() + delta, selectedDate.getMonth()); }
    function selectDateText(text) {
        const parts = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(text).trim());
        if (!parts) return false;
        const year = Number(parts[1]), month = Number(parts[2]) - 1, day = Number(parts[3]);
        const date = dateAt(year, month, day);
        if (date.getFullYear() !== year || date.getMonth() !== month || date.getDate() !== day) return false;
        return select(date);
    }
    function weekEdge(end) {
        const offset = (selectedDate.getDay() - weekStart + 7) % 7;
        moveDays((end ? 6 : 0) - offset);
    }
}
