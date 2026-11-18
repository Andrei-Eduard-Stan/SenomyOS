//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
import QtQuick
import QtQuick.Window
import Quickshell
import "components"
Window {
    visible: true
    width: 120; height: 40
    AppIndicator { id: code; toplevel: ({wayland: {appId: "code"}, lastIpcObject: {}}) }
    AppIndicator { id: firefox; x: 25; toplevel: ({wayland: {appId: "firefox-developer-edition"}, lastIpcObject: {}}) }
    AppIndicator { id: missing; x: 50; toplevel: ({wayland: {appId: "senomy-nonexistent-test-app"}, lastIpcObject: {}}) }
    AppIndicator { id: empty; x: 75; toplevel: ({lastIpcObject: {}}) }
    Timer {
        interval: 2000; running: true
        onTriggered: {
            if (!code.iconReady || !firefox.iconReady || missing.iconReady || empty.iconSource || empty.desktopEntry) {
                console.error("FAIL:", code.iconSource, code.iconReady, firefox.iconSource, firefox.iconReady, missing.iconSource, missing.iconReady, empty.iconSource, empty.desktopEntry); Qt.exit(1); return;
            }
            console.log("PASS: Wayland IDs without IPC data resolve Code/Firefox; unknown and empty IDs use honest fallback");
            Qt.quit();
        }
    }
}
