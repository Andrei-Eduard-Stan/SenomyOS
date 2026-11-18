import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtTest
import Quickshell
import "components"
import "services/calendar" as CalendarState
import "config" as Config

Window {
    id: test
    visible: true; width: 1000; height: 900; color: "#eeeeee"
    property int checks: 0
    property int closes: 0
    property string route: ""
    property string opened: ""
    property string composed: ""
    property real workWidth: 1920
    property real workHeight: 1080
    TestCase { id: input; when: false }
    Repeater {
        model: 40
        Text { required property int index; y: index * 23; text: "BUSY BACKGROUND // TEXT MUST NOT SHOW THROUGH THE CALENDAR 1234567890"; color: "#151515"; font.pixelSize: 20 }
    }
    QtObject {
        id: provider
        property bool available: true
        property var sources: [{id:"personal", name:"Personal", visible:true, writable:true}]
        property var preferences: ({timezone:"local"})
        property var snapshot: ({revision:1})
        property var items: []
        property int serial: 0
        property var queue: []
        property bool hold: false
        property bool fail: false
        property bool truncate: false
        property string search: "unrelated full workspace filter"
        property string sourceFilter: "unrelated source"
        signal requestFinished(string id, string operation, var result, bool ok)
        function request(op, args) {
            test.check(args.search === "" && args.source === "", "quick query independent of full filters");
            const id = "fixture-" + (++serial);
            queue = queue.concat([{id:id,args:args}]);
            return id;
        }
        function flush() {
            const pending = queue; queue = [];
            for (const request of pending) requestFinished(request.id, "query", fail ? {error:"Fixture query failed"} : {items:items.filter(e => e.date < request.args.end && e.lastDate >= request.args.start), truncated:truncate}, !fail);
        }
        function open(entry) { test.opened = entry.uid; }
        function compose(kind, date, screen) { test.composed = kind + ":" + date; }
        property Timer replies: Timer { interval: 10; repeat: true; running: provider.queue.length > 0 && !provider.hold; onTriggered: provider.flush() }
    }
    CalendarPopup {
        id: popup
        x: 20; y: 20; width: implicitWidth; height: implicitHeight
        availableWidth: test.workWidth - 40
        availableHeight: test.workHeight - Config.Theme.railHeight - 40
        calendarService: provider
        onDismissRequested: test.closes++
        onOpenCalendarRequested: requestedRoute => test.route = requestedRoute
    }
    readonly property var view: named("popup-calendar-browser")
    readonly property var model: view.model
    readonly property var nav: CalendarState.Navigation
    function check(ok, message) { checks++; if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); } }
    function waitFor(predicate, message) { for (let i = 0; i < 150 && !predicate(); i++) input.wait(10); check(predicate(), message); }
    function named(name) { const item = input.findChild(popup, name); if (!item) {console.error("FAIL: missing " + name); Qt.exit(1);throw new Error(name);} return item; }
    function click(name) { const item = named(name); input.mouseClick(item, item.width/2, item.height/2); input.wait(80); }
    function capture(name) { let done = false; popup.grabToImage(result => {check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT") + "/" + name + ".png"), "saved screenshot"); done = true;}); while (!done) input.wait(10); }
    function event(uid, date, allDay, time) { return {source:"personal",uid:uid,rid:"",title:"TEST FIXTURE · " + uid,date:date,lastDate:date,allDay:allDay,time:time,endTime:"11:00",startEpoch:allDay?0:100,calendar:"Fixture calendar",location:"Test room",kind:"event"}; }
    function refresh() { provider.snapshot = {revision:provider.snapshot.revision + 1}; input.wait(160); }
    Timer {
        interval: 200; running: true
        onTriggered: {
            nav.todayOverride = "2026-10-24"; nav.weekStartOverride = 1; nav.goToday(); view.focusSelected(); input.wait(180);
            check(popup.width === 760 && popup.height < 650, "wide calendar bounds " + popup.height);
            const restHeight = popup.height;
            check(!view.interactive, "whole calendar does not scroll on normal screen");
            check(named("quick-calendar-day-2026-10-24").today && named("quick-calendar-day-2026-10-24").selected, "today selected");
            check(named("quick-calendar-empty").text === "No events for this day.", "accurate empty state");
            capture("01-today-empty");
            click("quick-calendar-day-2026-10-27");
            check(nav.selectedKey === "2026-10-27", "pointer selection immediate");
            check(named("quick-calendar-day-2026-10-24").today && !named("quick-calendar-day-2026-10-24").selected, "today survives other selection");
            check(closes === 0, "selection does not dismiss or open a menu");
            capture("02-other-day");
            const selected = nav.selectedKey;
            click("quick-calendar-previous"); check(model.viewedMonth.getMonth() === 8 && nav.selectedKey === selected, "browse month preserves selected day"); capture("03-previous-month");
            click("quick-calendar-next"); click("quick-calendar-next"); check(model.viewedMonth.getMonth() === 10, "next month"); capture("04-next-month");
            check(popup.height === restHeight, "five/six-week arrangement stays stable");
            click("quick-calendar-today");
            const today = named("quick-calendar-day-2026-10-24"); today.forceActiveFocus(); input.keyClick(Qt.Key_Right); input.wait(50);
            check(nav.selectedKey === "2026-10-24" && nav.key(model.focusedDate) === "2026-10-25", "arrows focus independently");
            check(named("quick-calendar-day-2026-10-25").activeFocus, "focus ring moves");
            input.keyClick(Qt.Key_Return); input.wait(150); check(nav.selectedKey === "2026-10-25", "Enter commits focused day");
            input.keyClick(Qt.Key_PageDown); input.wait(100); check(model.viewedMonth.getMonth() === 10 && nav.selectedKey === "2026-10-25", "PageDown browses without selection");
            input.keyClick(Qt.Key_Home, Qt.ControlModifier); input.wait(120); check(nav.selectedKey === "2026-10-24", "Control Home returns today");
            input.keyClick(Qt.Key_End); input.keyClick(Qt.Key_Space); input.wait(100); check(nav.selectedKey === "2026-10-25", "End and Space");
            click("quick-calendar-day-2026-11-01"); check(nav.selectedKey === "2026-11-01" && model.viewedMonth.getMonth() === 10, "adjacent month click");

            nav.selectDateText("2024-02-29"); input.wait(100); check(model.dates.some(d => nav.key(d) === "2024-02-29"), "leap day");
            model.browse(12); check(model.focusedDate.getDate() === 28 && model.viewedMonth.getFullYear() === 2025, "leap year clamp for focus");
            nav.selectDateText("2026-12-31"); model.browse(1); check(model.viewedMonth.getFullYear() === 2027 && model.viewedMonth.getMonth() === 0 && model.focusedDate.getDate() === 31, "year boundary");
            for (const year of [1, 99, 1900, 2000, 2024, 2026, 9999]) {
                for (let month = 0; month < 12; month++) {
                    const dates = nav.daysForMonth(nav.dateAt(year, month, 1));
                    check(dates.length === 42 && dates[0].getDay() === 1, "42 days Monday first");
                    for (let i = 1; i < dates.length; i++) check(nav.key(nav.dateAt(dates[i-1].getFullYear(),dates[i-1].getMonth(),dates[i-1].getDate()+1)) === nav.key(dates[i]), "civil days consecutive across leap/DST/year");
                }
            }
            check(!nav.selectDateText("1900-02-29") && nav.selectDateText("2000-02-29"), "century leap rules");
            nav.weekStartOverride = 0; check(model.dates[0].getDay() === 0, "Sunday preference"); nav.weekStartOverride = 1;
            nav.selectDateText("0001-01-01"); model.browse(-1); check(model.viewedMonth.getFullYear() === 1, "lower year bound");
            nav.selectDateText("9999-12-31"); input.wait(160); check(!!model.dayError && !model.loading, "honest upper event boundary");
            nav.goToday(); input.wait(160);

            provider.items = [event("One event", "2026-10-24", false, "10:00")]; refresh();
            check(model.entries.length === 1 && named("quick-calendar-day-2026-10-24").eventCount === 1, "real data abstraction and indicator");
            capture("05-one-event-fixture"); click("quick-calendar-event-0");
            check(!opened && named("calendar-event-preview").visible,"selection opens an inline preview without handing off");
            click("calendar-event-open");check(opened === "One event","explicit Open event uses the provider");click("calendar-preview-back");
            provider.items = [event("Timed", "2026-10-24", false, "10:00"), event("All day", "2026-10-24", true, ""), event("Third", "2026-10-24", false, "12:00"), event("Fourth", "2026-10-24", false, "14:00")]; refresh();
            check(model.entries.length === 4 && model.entries[0].allDay, "all-day sorts first");
            check(named("quick-calendar-agenda-list").interactive, "only agenda scrolls beyond three entries");
            capture("06-multiple-all-day-fixtures");
            const expandedHeight = popup.height;
            click("quick-calendar-day-2026-10-27"); check(model.entries.length === 0 && popup.height === expandedHeight, "agenda does not shrink during an opening");
            click("quick-calendar-add"); check(composed === "event:2026-10-27", "compose destination");
            click("open-calendar-workspace"); check(route === "calendar", "full workspace route");
            click("open-calendar-briefing"); check(route === "calendar/briefing", "real briefing route");

            provider.hold = true; model.select(nav.dateAt(2026,9,28)); input.wait(90);
            const stale = provider.queue.slice(); provider.queue = [];
            model.select(nav.dateAt(2026,9,24)); input.wait(90);
            for (const request of stale) provider.requestFinished(request.id,"query",{items:[event("Stale", "2026-10-28", false, "10:00")]},true);
            check(!model.entries.some(e => e.uid === "Stale"), "late response cannot replace current selection");
            provider.hold = false; input.wait(100);
            provider.fail = true; refresh(); check(model.dayError && !model.entries.length, "query failure never looks like no events"); capture("07-query-error");
            provider.fail = false; provider.sources = []; provider.items = []; refresh(); check(named("quick-calendar-empty").text === "No calendar source available.", "no source differs from empty day"); capture("08-no-source");
            provider.available = false; input.wait(50); check(named("quick-calendar-empty").text.indexOf("unavailable") >= 0 && !named("quick-calendar-add").enabled, "provider loss"); capture("09-unavailable");
            provider.available = true; provider.sources = [{id:"personal",visible:true,writable:true}]; refresh();

            view.focusSelected(); input.wait(40);
            nav.todayOverride = "2026-10-25"; input.wait(150); check(nav.selectedKey === "2026-10-25", "midnight follows today");
            check(named("quick-calendar-day-2026-10-25").activeFocus, "midnight keeps the focus outline on the focused civil day");
            nav.weekStartOverride = 0; input.wait(50);
            check(named("quick-calendar-day-2026-10-25").activeFocus, "week-start changes preserve date focus");
            nav.weekStartOverride = 1; input.wait(50);
            model.select(nav.dateAt(2026,9,20)); nav.todayOverride = "2026-10-26"; input.wait(100); check(nav.selectedKey === "2026-10-20", "midnight preserves a browsed selection");
            check(named("quick-calendar-day-2026-10-26").today, "today highlight rolls over");
            click("quick-calendar-today");
            popup.requestedOpen = false; input.wait(50); const requestsBefore = provider.serial; input.wait(160); check(provider.serial === requestsBefore, "closed popup makes no queries");
            popup.requestedOpen = true; input.wait(160); check(popup.height === restHeight, "next opening resets agenda reserve");
            workWidth = 360; workHeight = 600; input.wait(100); check(popup.width === 320 && popup.height <= 488, "narrow short work area bounded"); capture("10-narrow-short");
            const footer = named("open-calendar-workspace"); footer.forceActiveFocus(); input.wait(80); const point = footer.mapToItem(popup,0,0); check(point.y >= 0 && point.y+footer.height <= popup.height, "short layout reveals keyboard focus");
            workHeight = 900; Config.DirectoryStyle.touchMode = true; input.wait(100);click("calendar-month-toggle");check(named("quick-calendar-day-2026-10-26").height >= 48, "touch day targets"); capture("11-touch-narrow");
            Config.DirectoryStyle.touchMode = false; workWidth = 1920; workHeight = 1080;
            const registry = JSON.parse(JSON.stringify(Config.Skin.registry)); registry.persona = Object.assign({},registry.persona || {},{uiTextScale:1.5,highContrast:true,reducedMotion:true}); Config.Skin.registry = registry; input.wait(100);
            check(Config.QuickPanelStyle.openMs === 0, "reduced motion"); capture("12-large-type-contrast");
            click("quick-calendar-close"); check(closes === 1, "close routes to owner");
            popup.forceActiveFocus(); input.keyClick(Qt.Key_Escape); input.wait(40); check(closes === 2, "Escape routes to owner");
            console.log("PASS: " + checks + " calendar checks: civil dates, independent today/selection/focus, pointer/keyboard, query races, error/empty/event/all-day states, routes, sizing, touch and reduced motion. Fixtures only.");
            Qt.quit();
        }
    }
}
