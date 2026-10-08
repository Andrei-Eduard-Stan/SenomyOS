import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"

Window {
    id: test
    visible: true
    width: 600
    height: 420
    property string route: "overview"
    property int activations: 0
    property int destroyedPages: 0
    TestCase { id: input; when: false }

    function check(ok, message) {
        if (!ok) {
            console.error("FAIL: " + message);
            Qt.exit(1);
            throw new Error(message);
        }
    }
    function focused(index) {
        const item = nav.itemAtIndex(index);
        return item && item.activeFocus;
    }

    DashboardButton { id: close; x: 10; y: 5; width: 200; text: "CLOSE" }
    DashboardNavigation {
        id: nav
        x: 10; y: 60; width: 200; height: 240
        activeSection: test.route
        restoreFocus: true
        sections: [
            {id: "overview", label: "OVERVIEW"}, {id: "network", label: "NETWORK"},
            {id: "audio", label: "AUDIO"}, {id: "power", label: "POWER"},
            {id: "calendar", label: "CALENDAR", enabled: false},
            {id: "input", label: "INPUT"}, {id: "devices", label: "DEVICES"},
            {id: "apps", label: "APPLICATIONS"}, {id: "appearance", label: "APPEARANCE"},
            {id: "settings", label: "SETTINGS"}
        ]
        onSectionRequested: section => { test.activations++; test.route = section; }
    }
    Loader {
        id: page
        x: 230; y: 60; width: 300; height: 240
        property string route: test.route
        // A distinct component ensures the focused old page is really destroyed.
        sourceComponent: route === "overview" ? overview : other
    }
    Component {
        id: overview
        DashboardButton {
            text: "OPEN SETTINGS"
            onClicked: test.route = "settings"
            Component.onDestruction: test.destroyedPages++
        }
    }
    Component { id: other; DashboardButton { text: "CONTENT" } }

    Timer {
        interval: 500; running: true
        onTriggered: {
            test.check(test.focused(0), "opening must focus the selected route");
            input.keyClick(Qt.Key_Down); input.wait(40);
            test.check(test.focused(1) && test.route === "overview", "arrows move focus without activating");
            input.keyClick(Qt.Key_Return); input.wait(40);
            test.check(test.route === "network" && test.activations === 1 && test.focused(1), "Return activates exactly once and restores route focus");
            input.keyClick(Qt.Key_Down); input.wait(40);
            input.keyClick(Qt.Key_Space); input.wait(40);
            test.check(test.route === "audio" && test.activations === 2, "Space activates exactly once");
            input.keyClick(Qt.Key_Down); input.wait(40);
            input.keyClick(Qt.Key_Down); input.wait(40);
            test.check(test.focused(5), "disabled routes are skipped");
            input.keyClick(Qt.Key_End); input.wait(80);
            test.check(test.focused(9) && nav.contentY > 0, "offscreen final route becomes visible and focused");
            input.keyClick(Qt.Key_Tab); input.wait(40);
            test.check(page.item.activeFocus, "Tab can leave navigation for content");
            input.keyClick(Qt.Key_Backtab); input.wait(60);
            test.check(test.focused(9), "Shift-Tab returns to the last route");
            input.keyClick(Qt.Key_Home); input.wait(80);
            test.check(test.focused(0), "Home reaches first route");
            input.keyClick(Qt.Key_Backtab); input.wait(40);
            test.check(close.activeFocus, "Shift-Tab can leave navigation for Close");
            test.route = "overview"; input.wait(80);
            const beforeDestruction = test.destroyedPages;
            page.item.forceActiveFocus(); input.keyClick(Qt.Key_Return); input.wait(80);
            test.check(test.route === "settings" && test.destroyedPages === beforeDestruction + 1 && test.focused(9), "route change after destroying focused content restores selected navigation");
            nav.restoreFocus = false;
            close.forceActiveFocus();
            test.route = "network"; input.wait(50);
            test.check(close.activeFocus, "closed/inactive navigation must not steal focus");
            nav.restoreFocus = true; input.wait(80);
            test.check(test.focused(1), "reopening focuses the selected route");
            test.route = "unknown"; input.wait(50);
            test.check(test.focused(1), "unknown route does not fabricate a selection");
            test.width = 360; nav.width = 138; input.wait(40);
            nav.focusIndex(9); input.wait(80);
            input.mouseClick(nav.itemAtIndex(9), 50, 24); input.wait(40);
            test.check(test.route === "settings" && test.activations === 3, "narrow pointer activation retains route semantics");
            console.log("PASS: section navigation, disabled routes, scroll visibility, Tab exit, route destruction and focus restoration; isolated fixture only");
            Qt.quit();
        }
    }
}
