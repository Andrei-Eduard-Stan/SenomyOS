import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
Window {
    id: fixture
    visible: true; width: 540; height: 500
    QtObject {
        id: settings
        property bool editorAvailable: false
        property bool engineInstalled: false
        property bool nativeToolsBusy: false
        property string nativeToolsMessage: ""
        property int calls: 0
        function openInputMethodSettings() { calls++; }
    }
    NativeInputToolsView { id: view; width: parent.width; settings: settings }
    TestCase { id: input; when: false }
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); }
    }
    Timer {
        running: true; interval: 400
        onTriggered: {
            const button = input.findChild(view,"openInputMethodSettings");
            for (const width of [340,540]) {
                fixture.width = width; input.wait(40);
                settings.editorAvailable = false; input.wait(40);
                fixture.check(!button.enabled,"missing editor disabled");
                input.mouseClick(button); fixture.check(settings.calls === 0,"absent tool never activated");
                settings.editorAvailable = true; input.wait(40);
                fixture.check(button.enabled,"installed editor available independent of engine readiness");
                button.forceActiveFocus(); input.keyClick(Qt.Key_Return);
                fixture.check(settings.calls === 1,"keyboard fixed handoff requested once");
                settings.nativeToolsBusy = true; input.wait(40);
                fixture.check(!button.enabled,"duplicate handoff disabled while pending");
                input.mouseClick(button); fixture.check(settings.calls === 1,"busy activation blocked");
                fixture.check(view.implicitHeight <= fixture.height,"input tool cards fit fixture");
                settings.calls = 0; settings.nativeToolsBusy = false;
            }
            console.log("PASS: detected input-method handoff disabled when absent/busy and keyboard operable when available; fake provider only");
            Qt.quit();
        }
    }
}
