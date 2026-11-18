import QtQuick
import QtQuick.Window
import Quickshell
import "components"
Window {
    visible: true; width: 600; height: 100
    MetalSheen { id: left; x: 0; width: 80; height: 64; animate: false }
    MetalSheen { id: right; x: 400; width: 80; height: 64; animate: false }
    Timer {
        interval: 500; running: true
        onTriggered: {
            if (Math.abs(left.progress - right.progress) < 0.001 || left.phase !== 0 || right.phase !== 0) {
                console.error("FAIL: spatial reflection or stopped motion"); Qt.exit(1); return;
            }
            console.log("PASS: equal-size islands at different screen positions receive different reflections; stopped motion is static");
            Qt.quit();
        }
    }
}
