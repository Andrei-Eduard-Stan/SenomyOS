import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"

Window {
    id: test
    visible: true; width: 540; height: 1200
    TestCase { id: input; when: false }
    property var currentReview: null
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
        property string requestedContext: "fixture"
        property bool locked: false
        property string actionKind: "configuration"
        property int secondsRemaining: 15
        property var previous: null
        property var proposed: null
        function cancel() { test.cancelled++; actionState = "idle"; }
        function revert() { test.cancelled++; actionState = "idle"; }
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
        x: 10; y: 70; width: parent.width-20; height: 1100
        SelectionActionReview { id: selection; width: parent.width; actions: actions; visible: test.currentReview === selection && actions.actionState !== "idle" }
        NetworkActionReview { id: network; width: parent.width; actions: actions; visible: test.currentReview === network && actions.actionState !== "idle" }
        NotificationClearReview { id: notification; width: parent.width; actions: actions; ownerContext: "fixture"; visible: test.currentReview === notification && actions.actionState !== "idle" }
        DisplaySettings { id: display; width: parent.width; inventory: ({displays:[], policy:{}, displayActions:actions}); visible: test.currentReview === display }
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); }
    }
    Timer {
        interval: 500; running: true
        onTriggered: {
            for (const view of [selection,network,notification,display]) {
                actions.actionState = "idle";
                test.currentReview = view;
                request.forceActiveFocus();
                input.keyClick(Qt.Key_Return); input.wait(60);
                const prefix = view === selection ? "selection" : view === network ? "network" : view === notification ? "notificationClear" : "display";
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
                if (view === display) {
                    actions.actionState = "revert-pending"; input.wait(60);
                    const revert = input.findChild(view,"displayRevert");
                    test.check(revert.activeFocus,"temporary display approval defaults to Revert");
                    input.keyClick(Qt.Key_Return); input.wait(60);
                    test.check(actions.actionState === "idle","default rollback activation reverts fake change");
                }
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
            console.log("PASS: selection, network/Bluetooth, notification and display confirmation default to Cancel, allow deliberate Confirm focus, restore request focus and ignore stale/hidden contexts; fake providers only");
            Qt.quit();
        }
    }
}
