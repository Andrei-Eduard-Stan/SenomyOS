import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
Window {
    id: test
    visible: true; width: 420; height: 250
    property int actions: 0
    TestCase { id: input; when: false }
    CathedralSlider { id: slider; x: 20; y: 20; width: 280; from: 0; to: 1; value: 0.25; onMoved: test.actions++ }
    DashboardButton { id: button; x: 20; y: 80; text: "TEST ACTION"; onClicked: test.actions++ }
    DashboardButton { id: disabledButton; x: 20; y: 135; text: "DISABLED ACTION"; enabled: false; onClicked: test.actions++ }
    DashboardButton { id: nextButton; x: 20; y: 190; text: "NEXT ACTION"; onClicked: test.actions++ }
    Timer {
        running: true; interval: 600
        onTriggered: {
            input.mouseClick(slider, slider.width * 0.8, slider.height / 2);
            if (slider.value < 0.6 || test.actions < 1) { console.error("FAIL slider"); Qt.exit(1); return; }
            const before = test.actions;
            input.mouseClick(button, button.width/2, button.height/2);
            if (test.actions !== before+1) { console.error("FAIL button"); Qt.exit(1); return; }
            input.mouseClick(disabledButton, disabledButton.width/2, disabledButton.height/2);
            if (test.actions !== before+1) { console.error("FAIL disabled action"); Qt.exit(1); return; }
            button.forceActiveFocus();
            input.keyClick(Qt.Key_Return);
            if (test.actions !== before+2) { console.error("FAIL keyboard activation"); Qt.exit(1); return; }
            input.keyClick(Qt.Key_Tab);
            if (!nextButton.activeFocus || disabledButton.activeFocus) { console.error("FAIL disabled focus skip"); Qt.exit(1); return; }
            input.keyClick(Qt.Key_Space);
            if (test.actions !== before+3) { console.error("FAIL keyboard next activation"); Qt.exit(1); return; }
            console.log("PASS: styled controls support pointer, ordered keyboard focus, activation, and disabled gates; fixture only"); Qt.quit();
        }
    }
}
