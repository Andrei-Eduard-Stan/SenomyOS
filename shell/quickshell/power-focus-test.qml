import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
Window {
    id: fixture
    visible: true; width: 500; height: 400
    Item { id: anchor; width: 50; height: 50 }
    QtObject {
        id: power
        property string state: "idle"
        property bool available: true
        property string pendingAction: ""
        property string error: ""
        property int confirms: 0
        property int cancels: 0
        function request(action) { pendingAction = action; state = "pending"; }
        function cancel() { cancels++; state = "idle"; }
        function confirm() { confirms++; state = "running"; }
    }
    PowerPopup { id: popup; anchorItem: anchor; powerService: power; requestedOpen: true }
    TestCase { id: input; when: false }
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); }
    }
    Timer {
        running: true; interval: 500
        onTriggered: {
            for (const action of ["lock","suspend","logout","reboot","poweroff"]) {
                power.request(action); input.wait(80);
                const cancel = input.findChild(popup,"powerCancel");
                fixture.check(cancel && cancel.activeFocus,"session " + action + " defaults Cancel");
                input.keyClick(Qt.Key_Return); input.wait(60);
                fixture.check(power.state === "idle" && power.confirms === 0,"default cancels fake session action");
            }
            fixture.check(power.cancels === 5,"one cancellation per preview");
            console.log("PASS: session confirmation defaults Cancel for all five actions; fake provider and window host only");
            Qt.quit();
        }
    }
}
