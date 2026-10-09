import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "services"
import "components"
Window {
    id: test
    visible: true; width: 560; height: 420
    property int releases: 0
    QtObject {
        id: fakeChild
        property bool running: false
        property int processId: 424242
        property var command: []
        property var sent: []
        function signal(number) { sent=sent.concat([number]); }
    }
    QtObject { id: fakeObserver; property bool running: false; property var command: [] }
    InputSettings { id: settings; active: false; onReleasePrimaryFocusRequested: { test.releases++; context.visible=false; } }
    Item { id: context; anchors.fill: parent; OskControls { id: controls; width: parent.width; controller: settings.oskController } }
    TestCase { id: input; when: false }
    function check(ok,message) { if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);} }
    Timer {
        running: true; interval: 500
        onTriggered: {
            const control=settings.oskController;
            const adapter=control.provider;
            adapter.child=fakeChild;adapter.observer=fakeObserver;
            const show=input.findChild(controls,"oskShow"),hide=input.findChild(controls,"oskHide"),stop=input.findChild(controls,"oskStop");
            const cancel=input.findChild(controls,"oskCancel"),confirm=input.findChild(controls,"oskConfirm");
            test.check(!show.enabled,"absent provider disabled");
            settings.consumeOskCapabilities(JSON.stringify({ok:true,providerInstalled:true,provider:"wvkbd-mobintl",protocolState:"advertised",manualCandidate:true,message:"Fake candidate"}));input.wait(30);
            show.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(40);
            test.check(control.state==="pending-start" && cancel.activeFocus && !fakeChild.running,"start preview defaults Cancel and launches nothing");
            input.keyClick(Qt.Key_Return);input.wait(40);test.check(control.state==="stopped" && !fakeChild.running,"default start activation cancels");
            input.mouseClick(show);input.wait(40);settings.cancelOskReviews();input.wait(20);test.check(control.state==="stopped","route dismissal cancels start preview");
            input.mouseClick(show);input.wait(40);input.keyClick(Qt.Key_Tab);input.wait(30);
            test.check(confirm.activeFocus,"deliberate keyboard movement reaches Start confirmation");
            input.keyClick(Qt.Key_Return);input.wait(40);
            test.check(control.startPending && fakeChild.running && test.releases===0,"confirmed start waits for process readiness");
            test.check(fakeChild.command.length===4 && fakeChild.command[2]==="launch-confirmed" && fakeChild.command[3]==="wvkbd-mobintl","fixed provider argv");
            adapter.probe();adapter.consumeObservation('{"ok":true,"ready":false}');test.check(fakeChild.sent.length===0 && test.releases===0,"no signals before readiness");
            fakeObserver.running=false;adapter.probe();adapter.consumeObservation('{"ok":true,"ready":true}');input.wait(40);
            test.check(control.state==="show-requested" && fakeChild.sent[0]===12 && test.releases===1,"owned ready provider receives show request and releases primary context");
            test.check(fakeChild.running && !context.visible,"route close preserves child");
            context.visible=true;input.wait(40);input.mouseClick(hide);test.check(fakeChild.sent[1]===10 && control.state==="hide-requested","hide addresses same child");
            input.mouseClick(stop);input.wait(40);test.check(cancel.activeFocus && fakeChild.running,"stop preview defaults Cancel");
            input.keyClick(Qt.Key_Return);input.wait(30);test.check(fakeChild.running && control.state==="hide-requested","default stop cancels");
            input.mouseClick(stop);input.wait(30);settings.cancelOskReviews();test.check(fakeChild.running,"route dismissal cancels stop without killing");
            input.mouseClick(stop);input.wait(30);input.keyClick(Qt.Key_Tab);input.keyClick(Qt.Key_Return);input.wait(30);
            test.check(!fakeChild.running && control.state==="stop-requested","confirmed stop requests graceful termination");
            adapter.childExited(15);test.check(control.state==="stopped" && !control.owned,"requested termination observed before success");
            test.check(!adapter.show(control.serial) && !adapter.hide(control.serial),"expired ownership cannot signal anything");
            test.check(adapter.start("arbitrary-command",99)===false,"adapter rejects unallowlisted provider");
            adapter.ownerSerial=123;fakeChild.running=true;
            adapter.consumeGeometry('{"event":"geometry","visible":true,"width":500,"height":200}');
            test.check(adapter.visibilityKnown && adapter.visible,"bounded owned geometry observed");
            adapter.consumeGeometry('{"event":"geometry","visible":false,"width":-1,"height":0}');
            test.check(adapter.visible,"invalid geometry rejected");
            adapter.consumeGeometry('{"event":"geometry","visible":false,"width":0,"height":0}');
            test.check(!adapter.visible,"provider-native hiding observed");
            fakeChild.running=false;adapter.consumeGeometry('{"event":"geometry","visible":true,"width":500,"height":200}');
            test.check(!adapter.visible,"stale child output cannot establish visibility");
            adapter.childExited(0);test.check(!adapter.visibilityKnown,"exit clears geometry ownership");
            console.log("PASS: OSK adapter ownership/readiness, guarded keyboard controls, route preservation and confirmed graceful stop; fake processes only");
            Qt.quit();
        }
    }
}
