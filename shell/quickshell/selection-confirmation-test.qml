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
    height: 360
    color: "#08090b"
    QtObject { id: backend }
    QtObject {
        id: provider
        property var selectionBackend: backend
        property string allowedKind: "output"
        property int current: 1
        property int writes: 0
        function selectionAvailable(kind) { return kind === allowedKind; }
        function selectionOptions(kind) { return selectionAvailable(kind) ? [0, 1] : []; }
        function selectionCurrent(kind) { return current; }
        function selectionLabel(kind, value) {
            return kind === "profile" ? (value === 0 ? "Power saver" : "Balanced")
                : (kind === "input" ? "Microphone" : "Audio output") + (value === 0 ? " · Fixture USB device with a long name" : " · Built-in device");
        }
        function selectionImpact(kind) {
            return kind === "profile" ? "Change system power policy. Performance, heat, fan noise and battery life may change. Select the previous profile to switch back."
                : "Change the default audio device. Playback, recording and calls may move to another device. Choose the previous device to switch back.";
        }
        function applySelection(kind, target) { writes++; return true; }
    }
    SelectionActions { id: guard; provider: provider; context: "fixture-screen" }
    SelectionActionReview { id: review; x: 10; y: 10; width: parent.width - 20; actions: guard }
    TestCase { id: input; when: false }
    function check(condition, label) {
        if (!condition) { console.error("FAIL " + label); Qt.exit(1); return false; }
        return true;
    }
    Timer {
        running: true
        interval: 400
        onTriggered: {
            for (const kind of ["output", "input", "profile"]) {
                for (const size of [340, 540]) {
                    fixture.width = size;
                    provider.allowedKind = kind;
                    provider.current = 1;
                    const before = provider.writes;
                    if (!fixture.check(guard.request(kind, 0), "request")) return;
                    input.wait(80);
                    const cancel = input.findChild(review, "selectionCancel");
                    const confirm = input.findChild(review, "selectionConfirm");
                    if (!fixture.check(review.implicitHeight < fixture.height - 20, "confirmation fits")) return;
                    input.mouseClick(cancel);
                    if (!fixture.check(guard.actionState === "idle" && provider.writes === before, "pointer cancellation")) return;
                    guard.request(kind, 0);
                    input.wait(80);
                    fixture.requestActivate();
                    confirm.forceActiveFocus();
                    input.keyClick(Qt.Key_Return);
                    if (!fixture.check(provider.writes === before + 1 && guard.actionState === "running", "keyboard confirmation")) return;
                    guard.observe();
                    if (!fixture.check(guard.actionState === "running", "no premature success")) return;
                    provider.current = 0;
                    guard.observe();
                    if (!fixture.check(guard.actionState === "succeeded", "observed selection")) return;
                }
            }
            console.log("PASS: input/output/profile controls at narrow/wide widths, pointer cancel, keyboard confirm, observed completion; fake providers only");
            Qt.quit();
        }
    }
}
