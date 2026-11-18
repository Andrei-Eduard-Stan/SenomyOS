import QtQuick
import "." as CalendarState

// One consumer of the existing typed provider, with independent month/day
// requests. Full-workspace filters and ranges never govern a quick glance.
QtObject {
    id: root
    property var service: null
    property var navigation: CalendarState.Navigation
    property bool active: false
    property date viewedMonth: navigation.dateAt(navigation.selectedDate.getFullYear(), navigation.selectedDate.getMonth(), 1)
    property date focusedDate: navigation.civil(navigation.selectedDate)
    readonly property var dates: navigation.daysForMonth(viewedMonth)
    readonly property string rangeStart: dates[0].getFullYear() < 1 ? "0001-01-01" : navigation.key(dates[0])
    readonly property string rangeEnd: dates[41].getFullYear() > 9999 ? "9999-12-31" : navigation.key(navigation.dateAt(dates[41].getFullYear(), dates[41].getMonth(), dates[41].getDate() + 1))
    readonly property string selectedKey: navigation.selectedKey
    readonly property bool available: !!service && service.available
    property string monthRequest: ""
    property string dayRequest: ""
    property string loadedMonth: ""
    property string loadedDay: ""
    property string monthError: ""
    property string dayError: ""
    property var monthEntries: []
    property var dayEntries: []
    property bool monthTruncated: false
    property bool dayTruncated: false
    readonly property bool loading: active && available && loadedDay !== selectedKey && !dayError
    readonly property bool hasSources: !!service && (service.sources || []).some(s => s.visible === undefined || !!s.visible)
    readonly property bool canCreate: available && (service.sources || []).some(s => (s.visible === undefined || !!s.visible) && !!s.writable)
    readonly property var entries: loadedDay === selectedKey && available && !dayError ? dayEntries : []
    readonly property var dayCounts: {
        const counts = {};
        if (!available || loadedMonth !== rangeStart || monthError) return counts;
        for (const date of dates) {
            const key = navigation.key(date);
            counts[key] = monthEntries.filter(e => e.date <= key && e.lastDate >= key).length;
        }
        return counts;
    }
    function showSelected() {
        focusedDate = navigation.civil(navigation.selectedDate);
        viewedMonth = navigation.dateAt(focusedDate.getFullYear(), focusedDate.getMonth(), 1);
    }
    function select(date) {
        if (!navigation.supported(date)) return false;
        navigation.select(date);
        showSelected();
        return true;
    }
    function today() { navigation.goToday(); showSelected(); }
    function canBrowse(delta) {
        return navigation.supported(navigation.dateAt(viewedMonth.getFullYear(), viewedMonth.getMonth() + delta, 1));
    }
    function browse(delta) {
        if (!canBrowse(delta)) return false;
        const next = navigation.dateAt(viewedMonth.getFullYear(), viewedMonth.getMonth() + delta, 1);
        const day = Math.min(focusedDate.getDate(), navigation.dateAt(next.getFullYear(), next.getMonth() + 1, 0).getDate());
        viewedMonth = next;
        focusedDate = navigation.dateAt(next.getFullYear(), next.getMonth(), day);
        return true;
    }
    function focusDate(date) {
        if (!navigation.supported(date)) return false;
        focusedDate = navigation.civil(date);
        if (!dates.some(d => navigation.key(d) === navigation.key(date)))
            viewedMonth = navigation.dateAt(date.getFullYear(), date.getMonth(), 1);
        return true;
    }
    function moveFocus(days) {
        return focusDate(navigation.dateAt(focusedDate.getFullYear(), focusedDate.getMonth(), focusedDate.getDate() + days));
    }
    function invalidate() {
        monthRequest = ""; dayRequest = "";
        loadedMonth = ""; loadedDay = "";
        monthError = ""; dayError = "";
        if (active && available) refresh.restart();
    }
    function query() {
        if (!active || !available) return;
        if (loadedMonth !== rangeStart && !monthRequest) {
            monthRequest = service.request("query", {start:rangeStart, end:rangeEnd, search:"", source:"", view:"quick-month"});
            if (!monthRequest) monthError = "Calendar service unavailable.";
        }
        if (loadedDay !== selectedKey && !dayRequest) {
            const date = navigation.selectedDate;
            // The event engine supports Python's years 1..9999. Do not send
            // adjacent grid dates outside that range to the provider.
            const end = navigation.dateAt(date.getFullYear(), date.getMonth(), date.getDate() + 1);
            if (!navigation.supported(end)) { dayError = "Events unavailable at this date boundary."; return; }
            dayRequest = service.request("query", {start:selectedKey, end:navigation.key(end), search:"", source:"", view:"quick-day"});
            if (!dayRequest) dayError = "Calendar service unavailable.";
        }
    }
    function receive(id, operation, result, ok) {
        if (operation !== "query" || !active) return;
        if (id === monthRequest) {
            monthRequest = "";
            monthError = ok ? "" : (result.error || "Event indicators unavailable.");
            loadedMonth = rangeStart;
            monthEntries = ok ? result.items || [] : [];
            monthTruncated = ok && !!result.truncated;
        } else if (id === dayRequest) {
            dayRequest = "";
            dayError = ok ? "" : (result.error || "Events unavailable. Open Calendar to review.");
            loadedDay = selectedKey;
            dayEntries = ok ? (result.items || []).slice().sort((a,b) => Number(b.allDay) - Number(a.allDay) || a.startEpoch - b.startEpoch || a.title.localeCompare(b.title)) : [];
            dayTruncated = ok && !!result.truncated;
        }
    }
    property Timer refresh: Timer { interval: 60; onTriggered: root.query() }
    onActiveChanged: {
        if (active) { showSelected(); invalidate(); }
        else { refresh.stop(); monthRequest = ""; dayRequest = ""; }
    }
    onAvailableChanged: invalidate()
    onRangeStartChanged: { monthRequest = ""; monthError = ""; if (active && available) refresh.restart(); }
    onSelectedKeyChanged: { dayRequest = ""; dayError = ""; if (active && available) refresh.restart(); }
    property Connections providerChanges: Connections {
        target: root.service
        function onSnapshotChanged() { root.invalidate(); }
        function onRequestFinished(id, operation, result, ok) { root.receive(id, operation, result, ok); }
    }
    property Connections selectionChanges: Connections {
        target: root.navigation
        function onSelectedDateChanged() { root.showSelected(); }
    }
}
