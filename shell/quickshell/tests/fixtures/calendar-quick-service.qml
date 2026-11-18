import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services/calendar" as CalendarState

// This fixture uses the actual CalendarService and private Python calendar owner.
Window {
    id: test; visible: true; width: 500; height: 850
    TestCase { id: input; when: false }
    QtObject { id: localClock; property date date: new Date(2026,9,24,12) }
    property string completed: ""
    property bool succeeded: false
    CalendarState.CalendarService {
        id: calendar; active: false
        search: "full workspace filter"; sourceFilter: "full workspace source"
        onRequestFinished: (id, operation, result, ok) => { test.completed = id; test.succeeded = ok; }
    }
    CalendarPopup {
        id: popup
        width: implicitWidth; height: implicitHeight
        availableWidth: 460; availableHeight: 800; calendarService: calendar
    }
    readonly property var view: input.findChild(popup,"popup-calendar-browser")
    function check(ok, message) { if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); } }
    function waitFor(predicate, message) { for (let i = 0; i < 200 && !predicate(); i++) input.wait(15); check(predicate(), message); }
    function request(operation, args) { const id = calendar.request(operation,args); waitFor(() => completed === id, operation + " reply"); check(succeeded, operation + " succeeded"); }
    Timer {
        interval: 150; running: true
        onTriggered: {
            const nav = CalendarState.Navigation;
            const actualClock = nav.timeSource;
            nav.todayOverride = ""; nav.timeSource = localClock; nav.goToday();
            waitFor(() => calendar.available && calendar.sources.length > 0, "private calendar connected");
            request("preferencesSave",{timezone:"Pacific/Kiritimati"});
            waitFor(() => calendar.preferences.timezone === "Pacific/Kiritimati", "display zone changed");
            check(nav.todayOverride === "" && nav.todayKey === "2026-10-24", "snapshot display zone never overrides local today");
            request("save",{source:"personal",title:"TEST FIXTURE · All day",allDay:true,start:"2026-10-24",end:"2026-10-24",timezone:"local",frequency:"NONE",reminder:""});
            request("save",{source:"personal",title:"TEST FIXTURE · Zoned event",start:"2026-10-24T09:00",end:"2026-10-24T10:00",timezone:"Europe/London",frequency:"NONE",reminder:""});
            request("save",{source:"personal",title:"TEST FIXTURE · Continuing",allDay:true,start:"2026-10-23",end:"2026-10-25",timezone:"local",frequency:"NONE",reminder:""});
            waitFor(() => view.model.entries.length === 3, "actual provider returns three selected-day events");
            check(view.model.entries[0].allDay && view.model.entries.some(e => e.time === "22:00"), "all-day and engine timezone conversion preserved");
            check(calendar.entries.length === 0, "quick requests do not replace full-workspace entries");
            view.model.browse(1); input.wait(200);
            check(view.model.entries.length === 3 && nav.selectedKey === "2026-10-24", "agenda independent of viewed month");
            request("sourceSave",{id:"personal",name:"Personal",visible:false});
            waitFor(() => !view.model.hasSources && !view.model.entries.length, "integer false source state respected");
            for (let i = 0; i < 6; i++) { popup.requestedOpen = false; input.wait(10); popup.requestedOpen = true; input.wait(90); }
            waitFor(() => Object.keys(calendar.pending).length === 0, "requests drained after repeated openings");
            localClock.date = new Date(2026,9,25,0,1); input.wait(100);
            check(nav.todayKey === "2026-10-25" && nav.selectedKey === "2026-10-25", "minute clock rollover independent of snapshot");
            console.log("PASS: real private calendar socket, unfiltered independent quick queries, local today versus display zone, all-day/spanning/zoned events, source visibility and repeated openings. No live state used.");
            nav.timeSource = actualClock;
            Qt.quit();
        }
    }
}
