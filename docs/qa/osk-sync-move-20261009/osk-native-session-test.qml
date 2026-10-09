import QtQuick
import QtTest
import Quickshell
import "services"
Scope {
    id: test
    OskAdapter { id: adapter }
    OskController { id: controller; provider: adapter; capabilities: ({providerInstalled:true,protocolState:"advertised",manualCandidate:true,provider:"wvkbd-mobintl"}) }
    Connections { target: adapter; function onProviderStarted(serial) {controller.started(serial);} function onProviderExited(serial,successful) {controller.exited(serial,successful);} function onProviderFailed(serial) {controller.failed(serial);} }
    TestCase { id: input; when: false }
    function check(ok,message) {if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
    function waitFor(f) {for(let n=0;n<400&&!f();n++)input.wait(25);check(f(),"native managed state timeout: "+controller.state);}
    Timer { running: true; interval: 300; onTriggered: {
        check(controller.toggle(),"explicit startup");waitFor(()=>adapter.signalReady && adapter.visibilityKnown && adapter.visible && !controller.startPending);
        check(adapter.lockSync,"native shared-Caps handshake");const pid=adapter.child.processId;
        for(const visible of [false,true,false,true]) {
            check(controller.toggle(),"managed toggle accepted");waitFor(()=>adapter.visible===visible);
            check(adapter.child.processId===pid && controller.owned,"same owned provider survives toggles");
        }
        check(controller.requestStop() && controller.confirmStop(),"confirmed owned stop");waitFor(()=>!controller.owned);
        console.log("PASS: real native managed startup/Caps handshake/four visibility toggles/same-child lifecycle/confirmed cleanup; private compositor only");Qt.quit();
    }}
}
