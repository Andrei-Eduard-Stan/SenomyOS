import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "components/control" as Control
import "components/calendar" as CalendarUi
import "config" as Config
import "services/calendar" as CalendarState

Window {
    id: test
    visible: true; width: 184; height: 64; color: "transparent"
    property string route: "clock"
    property string calendarDestination:""
    property int calendarClicks: 0
    property int notificationClicks: 0
    property int readCalls: 0
    property int dismissals: 0
    property bool opened: false
    TestCase { id: input; when: false }
    QtObject { id: fakeClock; property date date: new Date(2024, 0, 31, 23, 59) }
    QtObject {
        id: clearGuard
        property string actionState: "idle"
        property bool locked: false
        property string requestedContext: ""
        property string impact: ""
        property string message: ""
    }
    QtObject {
        id: provider
        property var sessionService:({busy:false,hasSchedule:false,schedule:{}})
        property bool serverEnabled: true
        property bool clearAvailable: true
        property bool dnd: false
        property int activeCount: 0
        property var clearActions: clearGuard
        property var history: Array.from({length: 8}, (_, i) => ({id: i, receivedAt: 1700000000000 + i, summary: "Message " + i, appName: "Audit fixture", body: "<b>Literal text</b> — complete notification details. " + "Long content. ".repeat(30), urgency: "Normal", unread: true, actions: []}))
        readonly property int unreadCount: history.filter(record => record.unread).length
        function markRead(record) {
            test.readCalls++;
            history = history.map(item => Object.assign({}, item, {unread: record && item.id !== record.id ? item.unread : false}));
        }
        function dismiss(record) { test.dismissals++; history = history.filter(item => item.id !== record.id); }
        function setDnd(value) { dnd = value; }
    }
    Loader {
        id: view
        anchors.fill: parent
        sourceComponent: test.route === "clock" ? clock : test.route === "popup" ? popup : test.route === "control" ? control : test.route === "browser" ? fullBrowser : archive
    }
    Component {
        id: clock
        ClockIsland {
            notifications: provider
            notificationsOpen: test.opened
            onToggleCalendar: test.calendarClicks++
            onToggleNotifications: { test.notificationClicks++; test.opened = !test.opened; }
        }
    }
    Component { id: popup; CalendarPopup {onOpenCalendarRequested:route=>test.calendarDestination=route} }
    Component { id: fullBrowser; CalendarUi.CalendarBrowser {} }
    Component { id: control; Control.ControlCalendarPage {} }
    Component { id: archive; NotificationCenter { notifications: provider; clearContext: "notifications:fixture" } }
    function check(value, message) { if (!value) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); } }
    function capture(name) {
        let done = false;
        view.item.grabToImage(result => { test.check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT") + "/" + name + ".png"), "save " + name); done = true; });
        while (!done) input.wait(20);
    }
    function browser() { return route === "control" || route === "browser" ? view.item : input.findChild(view.item, "popup-calendar-browser"); }
    function typeText(item, text) {
        item.forceActiveFocus(); item.selectAll();
        for (const character of text) input.keyClick(character);
    }
    Timer {
        interval: 600; running: true
        onTriggered: {
            const nav = CalendarState.Navigation;
            const actualClock = nav.timeSource;
            for (const touch of [false, true]) {
                Config.DirectoryStyle.touchMode = touch;
                test.width = view.item.implicitWidth; input.wait(30);
                const clock = view.item.calendarAnchor, bell = view.item.notificationsAnchor;
                test.check(bell.width === (touch ? 56 : 52) && bell.height === view.item.height - 2, "bell dimensions");
                test.check(clock.width >= 108 && clock.height >= 52, "clock target");
                const clockTop=clock.mapToItem(view.item,0,0),bellTop=bell.mapToItem(view.item,0,0);
                test.check(clockTop.x===1&&clockTop.y===1&&clock.height===view.item.height-2,"clock target fills authored frame interior");
                test.check(bellTop.y===1&&bellTop.x===clockTop.x+clock.width&&bellTop.x+bell.width===view.item.width-1,"bell target meets clock without gap and reaches outer edge");
                bell.forceActiveFocus(); input.keyClick(Qt.Key_Return); input.wait(20);
                test.check(view.item.active && test.opened, "notifications has active feedback");
                input.keyClick(Qt.Key_Space); input.wait(20);
                test.check(!test.opened && test.notificationClicks === (touch ? 4 : 2), "Enter and Space invoke once");
                clock.forceActiveFocus(); input.keyClick(Qt.Key_Return); test.check(test.calendarClicks === (touch ? 2 : 1), "calendar keyboard entry");
                input.mouseMove(clock,clock.width/2,clock.height/2);input.wait(20);
                const clockHover=input.findChild(view.item,"clock-calendar-hover");
                test.check(clockHover.leftCorner&&clockHover.highlighted,"clock hover follows authored left corner");
                test.capture("clock-hover-" + (touch ? "touch" : "desktop"));
                input.mouseMove(bell,bell.width/2,bell.height/2);input.wait(20);
                const bellHover=input.findChild(view.item,"clock-notifications-hover");
                test.check(bellHover.rightCorner&&bellHover.highlighted,"notification hover follows authored right corner");
                test.capture("bell-hover-" + (touch ? "touch" : "desktop"));
                test.capture("clock-" + (touch ? "touch" : "desktop"));
            }
            Config.DirectoryStyle.touchMode = false;
            for (const target of [132,148,184]) {
                test.width=target;input.wait(20);
                test.check(view.item.calendarAnchor.width>=52 && view.item.notificationsAnchor.width===52,"tight Rail retains both targets");
            }
            test.route = "browser"; test.width = 440; test.height = 720; input.wait(120);
            nav.select(new Date(2024, 0, 31, 12));
            const next = input.findChild(view.item, "calendar-next-period"); next.forceActiveFocus(); input.keyClick(Qt.Key_Return); input.wait(60);
            test.check(nav.selectedKey === "2024-02-29", "month navigation clamps to leap day");
            test.browser().focusSelected(); input.keyClick(Qt.Key_Right); input.wait(50);
            test.check(nav.selectedKey === "2024-03-01", "arrow crosses month boundary");
            nav.selectDateText("2024-02-29");
            input.mouseClick(input.findChild(view.item, "calendar-choose-period")); input.wait(30);
            test.check(test.browser().pickerOpen, "visible heading opens month/year picker");
            input.mouseClick(input.findChild(view.item, "calendar-next-year"));
            test.check(input.findChild(view.item, "calendar-year-entry").text === "2025", "pointer advances draft year");
            test.check(nav.selectedKey === "2024-02-29", "draft year does not change selected date before Apply");
            input.mouseClick(input.findChild(view.item, "calendar-apply-period")); input.wait(40);
            test.check(nav.selectedKey === "2025-02-28" && !test.browser().pickerOpen, "year change clamps leap day and commits");
            test.browser().openPicker(); input.wait(30);
            test.typeText(input.findChild(view.item, "calendar-year-entry"), "1999");
            input.keyClick(Qt.Key_Return); input.wait(30);
            test.check(nav.selectedKey === "1999-02-28", "typed year applies on Enter");
            test.browser().openPicker(); input.wait(30);
            const monthChoice = input.findChild(view.item, "calendar-month-choice");
            monthChoice.forceActiveFocus(); input.keyClick(Qt.Key_Down); input.wait(20);
            input.mouseClick(input.findChild(view.item, "calendar-apply-period")); input.wait(30);
            test.check(nav.selectedKey === "1999-03-28", "keyboard month selection applies");
            test.browser().openPicker(); input.wait(30);
            const entry = input.findChild(view.item, "calendar-date-entry");
            test.typeText(entry, "2025-02-29"); input.keyClick(Qt.Key_Return); input.wait(30);
            test.check(test.browser().pickerOpen && test.browser().entryError && nav.selectedKey === "1999-03-28", "invalid date rejected without selection mutation");
            test.typeText(entry, "0099-01-31"); input.keyClick(Qt.Key_Return); input.wait(30);
            test.check(nav.selectedDate.getFullYear() === 99 && nav.selectedKey === "0099-01-31", "low years are not interpreted as 1999");
            nav.moveMonths(1); test.check(nav.selectedKey === "0099-02-28", "low-year month clamps correctly");
            test.check(!nav.selectDateText("1900-02-29") && nav.selectDateText("2000-02-29"), "Gregorian century leap rules");
            nav.selectDateText("0001-01-01"); test.check(!nav.moveDays(-1) && !nav.canMoveMonths(-1), "minimum year boundaries");
            nav.selectDateText("9999-12-31"); test.check(!nav.moveDays(1) && !nav.canMoveMonths(1), "maximum year boundaries");
            nav.selectDateText("2024-03-01");
            test.browser().openPicker(); input.wait(30); test.capture("calendar-picker-440");
            input.keyClick(Qt.Key_Escape); input.wait(30);
            test.check(!test.browser().pickerOpen && nav.selectedKey === "2024-03-01", "Escape cancels picker without changing date");
            test.route = "popup"; input.wait(100);
            test.capture("calendar-popup-440");
            const briefingAction=input.findChild(view.item,"open-calendar-briefing");
            const workspaceAction=input.findChild(view.item,"open-calendar-workspace");
            test.check(briefingAction.width>0 && workspaceAction.width>briefingAction.width,"full Calendar is the primary footer action");
            briefingAction.forceActiveFocus();input.keyClick(Qt.Key_Return);test.check(test.calendarDestination==="calendar/briefing","popup briefing action uses occupied-date route");
            workspaceAction.forceActiveFocus();input.keyClick(Qt.Key_Return);test.check(test.calendarDestination==="calendar","popup calendar action uses full workspace");
            test.route = "control"; test.width = 780; test.height = 640; input.wait(80);
            test.check(test.browser().navigation.selectedKey === "2024-03-01", "selection shared with Control Calendar");
            test.browser().focusSelected(); input.keyClick(Qt.Key_PageUp); input.wait(40);
            test.check(nav.selectedKey === "2024-02-01", "PageUp previous month");
            test.capture("calendar-control-780");
            nav.timeSource = fakeClock; nav.goToday(); fakeClock.date = new Date(2024, 1, 1, 0, 1); input.wait(30);
            test.check(nav.selectedKey === "2024-02-01", "following today rolls at midnight");
            nav.select(new Date(2023, 11, 31, 12)); fakeClock.date = new Date(2024, 1, 2, 0, 1); input.wait(20);
            test.check(nav.selectedKey === "2023-12-31", "browsed date preserved at midnight");
            nav.moveDays(1); test.check(nav.selectedKey === "2024-01-01", "year boundary");
            test.check(nav.monthDays.length === 42 && nav.monthDays[0].getDay() === Qt.locale().firstDayOfWeek, "locale week-start alignment");
            nav.timeSource = actualClock; nav.goToday();
            test.route = "browser"; test.width = 320; test.height = 780; input.wait(100);
            test.check(test.browser().compact, "narrow uses operable week list");
            test.browser().openPicker(); input.wait(30); test.capture("calendar-picker-320");
            test.typeText(input.findChild(view.item, "calendar-date-entry"), "2035-11-05");
            const goDate = input.findChild(view.item, "calendar-go-to-date"); goDate.forceActiveFocus(); input.wait(30); input.mouseClick(goDate); input.wait(40);
            test.check(nav.selectedKey === "2035-11-05" && !test.browser().pickerOpen, "narrow pointer Go reaches distant year");
            Config.DirectoryStyle.touchMode = true;
            test.browser().openPicker(); input.wait(40); test.capture("calendar-picker-touch-320");
            const previousYear = input.findChild(view.item, "calendar-previous-year");
            input.mouseClick(previousYear); input.wait(20);
            test.check(input.findChild(view.item, "calendar-year-entry").text === "2034", "touch-profile previous year");
            input.mouseClick(input.findChild(view.item, "calendar-cancel-period")); input.wait(30);
            test.check(nav.selectedKey === "2035-11-05", "Cancel discards draft month/year");
            Config.DirectoryStyle.touchMode = false;
            nav.goToday();
            test.browser().focusSelected(); input.keyClick(Qt.Key_Down); input.wait(40);
            test.check(nav.selectedDate.getDate() === new Date(nav.today.getFullYear(), nav.today.getMonth(), nav.today.getDate() + 1).getDate(), "compact arrow advances one day");
            test.capture("calendar-full-browser-320");
            test.route = "notifications"; test.width = 480; test.height = 640; input.wait(150);
            test.check(provider.unreadCount === 8 && test.readCalls === 0, "opening archive does not mark offscreen messages read");
            const first = input.findChild(view.item, "notification-open-0"); first.forceActiveFocus(); input.keyClick(Qt.Key_Return); input.wait(80);
            test.check(provider.history.length === 8 && test.dismissals === 0, "opening message does not delete");
            test.check(provider.unreadCount === 7 && !provider.history[0].unread, "only expanded record read");
            test.check(input.findChild(view.item, "notification-open-0").activeFocus, "focus survives model read update");
            test.capture("notification-detail-480");
            input.keyClick(Qt.Key_Escape); input.wait(30);
            test.check(input.findChild(view.item, "archive-list").expandedKey === "", "Escape collapses details");
            input.keyClick(Qt.Key_Return); input.wait(40);
            test.width = 320; input.wait(50); test.capture("notification-detail-320");
            const dismiss = input.findChild(view.item, "notification-dismiss-0"); dismiss.forceActiveFocus(); input.wait(40); input.mouseClick(dismiss); input.wait(60);
            test.check(provider.history.length === 7 && test.dismissals === 1, "explicit dismissal separate");
            const readAll = input.findChild(view.item, "notifications-read-all"); input.mouseClick(readAll); input.wait(50);
            test.check(provider.history.length === 7 && provider.unreadCount === 0, "read all preserves retained history");
            console.log("PASS: entry geometry/keyboard, month/year picker/direct-date validation, shared dates/midnight/leap/year boundaries, narrow navigation, notification read/detail/dismiss and focus; isolated providers only");
            Qt.quit();
        }
    }
}
