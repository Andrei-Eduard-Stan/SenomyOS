import QtQuick
import QtTest
import Quickshell
import "services"
Scope {
    id: test
    property int releases: 0
    property bool panelOpen: true
    InputSettings { id: settings; active: false; onReleasePrimaryFocusRequested: { test.releases++;test.panelOpen=false; } }
    TestCase { id: input; when: false }
    function check(ok,message) { if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);} }
    function waitForState(state) {
        for (let tries=0;tries<400 && settings.oskController.state!==state;tries++) input.wait(25);
        test.check(settings.oskController.state===state,"expected "+state+" got "+settings.oskController.state);
    }
    Timer {
        interval: 400; running: true
        onTriggered: {
            settings.consumeOskCapabilities(JSON.stringify({ok:true,providerInstalled:true,provider:"wvkbd-mobintl",protocolState:"advertised",manualCandidate:true,message:"Disposable stub only"}));
            const control=settings.oskController;
            test.check(control.requestShow() && control.confirmStart(),"confirmed stub start accepted");
            test.waitForState("show-requested");
            test.check(control.owned && !test.panelOpen && test.releases===1,"actual process survives panel dismissal and releases focus");
            test.check(control.requestHide(),"owned stub hide accepted");input.wait(100);
            test.check(control.requestStop() && control.confirmStop(),"owned stub graceful stop confirmed");
            test.waitForState("stopped");test.check(!control.owned,"actual exit observed");
            test.check(control.requestShow() && control.confirmStart(),"second confirmed stub start");test.waitForState("show-requested");
            console.log("READY: managed stub PID "+control.provider.child.processId);
            // Harness reloads this isolated configuration and verifies owned exit.
        }
    }
}
