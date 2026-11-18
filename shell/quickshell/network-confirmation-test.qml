import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "services"
import "components"

Window {
    id: fixture
    visible: true
    width: 580
    height: 320
    color: "#08090b"
    QtObject { id: radio; property bool wifiEnabled: true }
    QtObject { id: adapter }
    QtObject {
        id: network
        property string name: "Fixture <b>network</b> with a long descriptive name"
        property bool connected: true
        property bool stateChanging: false
        property int calls: 0
        function disconnect() { calls++; }
    }
    QtObject {
        id: provider
        property var radio: null
        property bool available: true
        property bool wifiEnabled: true
        property bool wifiHardwareEnabled: true
        property var wifiDevices: [adapter]
        property var wifiNetworks: [network]
    }
    NetworkActions { id: guard; provider: provider; context: "fixture" }
    NetworkActionReview { id: review; x: 10; y: 10; width: parent.width - 20; actions: guard }
    TestCase { id: input; when: false }
    Timer {
        interval: 400
        running: true
        onTriggered: {
            provider.radio = radio;
            if (!guard.request("disconnect", network)) { console.error("FAIL request"); Qt.exit(1); return; }
            Qt.callLater(function() {
                const cancel = input.findChild(review, "networkCancel");
                const confirm = input.findChild(review, "networkConfirm");
                input.wait(80);
                input.mouseClick(cancel);
                if (guard.actionState !== "idle" || network.calls !== 0) { console.error("FAIL cancel"); Qt.exit(1); return; }
                guard.request("disconnect", network);
                Qt.callLater(function() {
                    input.wait(80);
                    fixture.requestActivate();
                    confirm.forceActiveFocus();
                    input.keyClick(Qt.Key_Return);
                    if (network.calls !== 1 || guard.actionState !== "running") { console.error("FAIL keyboard confirm"); Qt.exit(1); return; }
                    guard.observe();
                    if (guard.actionState !== "running") { console.error("FAIL premature success"); Qt.exit(1); return; }
                    network.connected = false;
                    guard.observe();
                    if (guard.actionState !== "succeeded") { console.error("FAIL observed result"); Qt.exit(1); return; }
                    console.log("PASS: real confirmation controls cancel by pointer, confirm by keyboard, and await fake-provider completion");
                    Qt.quit();
                });
            });
        }
    }
}
