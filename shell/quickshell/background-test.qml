import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "config" as Config
Window {
    id: test
    width: 800; height: 450; visible: true; color: "#333333"
    property int phase: 0
    property string out: Quickshell.env("SENOMY_QA_OUT")
    SurfaceBackground { id: fill; width: 100; height: 100; fillKey: "calendar" }
    SenomyFrame { x: 120; y: 20; width: 330; height: 260; frameKey: "calendar"; tier: "standard"
        Text { anchors.centerIn: parent; text: "Live content above image"; color: "white" }
    }
    ExpandedAvatar { x: 480; y: 20; width: 240; height: 240; animate: false }
    MachineStateIsland { x: 120; y: 310; metrics: ({ready:true,cpuPercent:12,memoryTotalKib:100,memoryPercent:30,temperatureAvailable:true,temperatureCelsius:40,uptimeDetailedLabel:"1h"}); senomy: ({state:"idle",attentionState:"clear",message:"System steady"}) }
    Timer {
        interval: 700; repeat: true; running: true
        onTriggered: {
            if (test.phase === 0) {
                let registry = JSON.parse(JSON.stringify(Config.Skin.registry));
                for (let key of ["calendar", "senomy-ring", "senomy-rail"])
                    registry.backgrounds[key] = {source:"../assets/backgrounds/example.svg", scaling:"crop", scrimOpacity:0.15};
                Config.Skin.registry = registry;
            } else if (test.phase === 1) {
                if (!fill.imageReady) { console.error("FAIL: custom fill not ready"); Qt.quit(); return; }
                test.contentItem.grabToImage(r => r.saveToFile(test.out + "/custom-backgrounds.png"));
                fill.spec = {source:"file:///nonexistent-background-test.png"};
            } else {
                if (fill.imageReady) console.error("FAIL: missing image did not fall back");
                else console.log("PASS: manifest image fill, ring mask, missing-image fallback");
                Qt.quit();
            }
            test.phase++;
        }
    }
}
