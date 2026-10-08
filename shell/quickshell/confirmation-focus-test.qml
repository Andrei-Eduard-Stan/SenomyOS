import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"

Window {
    id: test
    visible: true; width: 540; height: 340
    TestCase { id: input; when: false }
    property int confirmed: 0
    property int cancelled: 0
    QtObject {
        id: actions
        property string actionState: "idle"
        property string title: "Fixture selection"
        property string action: "disconnect"
        property string targetName: "Fixture network"
        property string impact: "Fake provider only"
        property string message: ""
        function cancel() { test.cancelled++; actionState = "idle"; }
        function confirm() { test.confirmed++; actionState = "succeeded"; }
    }
    DashboardButton {
        id: request; x: 10; y: 5; width: 240
        text: "REQUEST FIXTURE CHANGE"
        enabled: actions.actionState === "idle"
        onClicked: actions.actionState = "pending"
    }
    DashboardButton { id: outside; x: 270; y: 5; text: "OUTSIDE" }
    Item {
        id: context
        x: 10; y: 70; width: parent.width-20; height: 250
        SelectionActionReview { id: selection; width: parent.width; actions: actions }
        NetworkActionReview { id: network; width: parent.width; actions: actions; visible: false }
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); }
    }
    Timer {
        interval: 500; running: true
        onTriggered: {
            for (const view of [selection,network]) {
                actions.actionState = "idle";
                selection.visible = view === selection;
                network.visible = view === network;
                request.forceActiveFocus();
                input.keyClick(Qt.Key_Return); input.wait(60);
                const prefix = view === selection ? "selection" : "network";
                const cancel = input.findChild(view,prefix+"Cancel");
                const confirm = input.findChild(view,prefix+"Confirm");
                test.check(cancel.activeFocus,"new "+prefix+" preview must focus Cancel");
                const before = test.cancelled;
                input.keyClick(Qt.Key_Return); input.wait(60);
                test.check(test.cancelled === before+1 && test.confirmed === 0,"default activation cancels exactly once");
                test.check(request.activeFocus,"cancellation returns focus to request control");
                input.keyClick(Qt.Key_Return); input.wait(60);
                input.keyClick(Qt.Key_Tab); input.wait(30);
                test.check(confirm.activeFocus,"explicit Tab can reach Confirm");
                actions.actionState = "idle"; input.wait(30);
                request.forceActiveFocus();
                actions.actionState = "pending";
                actions.actionState = "idle";
                outside.forceActiveFocus(); input.wait(60);
                test.check(outside.activeFocus,"expired preview must not steal delayed focus");
                actions.actionState = "pending";
                context.visible = false;
                outside.forceActiveFocus(); input.wait(60);
                test.check(outside.activeFocus,"hidden context must not steal focus");
                actions.actionState = "idle";
                context.visible = true;
            }
            console.log("PASS: selection and network confirmation default to Cancel, allow deliberate Confirm focus, restore request focus and ignore stale/hidden contexts; fake providers only");
            Qt.quit();
        }
    }
}
