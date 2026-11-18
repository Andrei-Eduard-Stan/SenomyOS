import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "services"
import "components"

Window {
    id: fixture
    visible: true
    width: 560
    height: 350
    color: "#08090b"
    QtObject {
        id: provider
        property bool clearAvailable: true
        property var history: []
        property var activeNotifications: []
        property int calls: 0
        function clearConfirmed(records, active) { calls++; history = []; return true; }
    }
    NotificationClearActions { id: guard; provider: provider }
    NotificationClearReview {
        id: review
        x: 10; y: 10
        width: parent.width - 20
        actions: guard
        ownerContext: guard.context
    }
    TestCase { id: input; when: false }
    function check(condition, label) {
        if (!condition) { console.error("FAIL " + label); Qt.exit(1); return false; }
        return true;
    }
    Timer {
        running: true
        interval: 400
        onTriggered: {
            for (const owner of ["notifications:fixture", "insights:fixture"]) {
                for (const size of [340, 540]) {
                    fixture.width = size;
                    guard.context = owner;
                    provider.history = [{id: 1}];
                    const before = provider.calls;
                    if (!fixture.check(guard.request(owner), "request " + owner)) return;
                    input.wait(80);
                    const cancel = input.findChild(review, "notificationClearCancel");
                    const confirm = input.findChild(review, "notificationClearConfirm");
                    if (!fixture.check(review.implicitHeight < fixture.height - 20, "confirmation fits")) return;
                    input.mouseClick(cancel);
                    if (!fixture.check(guard.actionState === "idle" && provider.calls === before, "pointer cancellation")) return;
                    guard.request(owner);
                    input.wait(80);
                    fixture.requestActivate();
                    confirm.forceActiveFocus();
                    input.keyClick(Qt.Key_Return);
                    if (!fixture.check(provider.calls === before + 1 && guard.actionState === "running", "keyboard confirmation")) return;
                    guard.saved();
                    if (!fixture.check(guard.actionState === "succeeded", "save completion")) return;
                }
            }
            console.log("PASS: notification and Insights confirmation contexts, narrow/wide fit, pointer cancel and keyboard confirm; fake provider only");
            Qt.quit();
        }
    }
}
