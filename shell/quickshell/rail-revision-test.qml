import QtQuick
import QtQuick.Window
import Quickshell
import "components"
import "config" as Config
import "services/SystemHealth.js" as Health

Window {
    id: test
    visible: true
    width: 980; height: 660
    color: "#08090b"
    property int phase: 0
    Component.onCompleted: Config.RailStyle.workspaceBorderType = "native"
    property var items: fixtures(4, 4)
    property string out: Quickshell.env("SENOMY_QA_OUT")
    function fixtures(n, selected) {
        return Array.from({length:n}, (_, i) => ({id:i+1, monitor:null, active:i+1===selected,
            toplevels:{values:[]}, activate:()=>{}}));
    }
    function check(ok, message) { if (!ok) throw new Error(message); }
    property var metrics: ({ready:true,cpuPercent:14,memoryPercent:31,memoryTotalKib:33554432,
        memoryUsedKib:10401874,kernelRelease:"6.12.0",hostName:"senomy",hostModel:"Reference laptop",
        cpuModel:"Portable processor description",uptimeDetailedLabel:"02:14:09"})
    Item {
        id: capture
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "#08090b" }
        Column {
            x: 24; y: 14; spacing: 10
            Text { text: "WORKSPACE BORDER + ARROWS / " + Config.RailStyle.workspaceBorderType.toUpperCase(); color: "white"; font.pixelSize: 16 }
            WorkspaceRail { id: rail; monitor: null; workspaceSource: test.items; width: implicitWidth; height: 64 }
            Text { text: "COMPACT / CPU · RAM · UPTIME"; color: "#92959f"; font.pixelSize: 12 }
            MachineDiagram { width: 336; height: 64; metrics: test.metrics }
            MachineDiagram { width: 900; height: 260; detailed: true; metrics: test.metrics }
            Text { text: "NARROW / 138 px + 238 px"; color: "#92959f"; font.pixelSize: 12 }
            Row {
                spacing: 30
                MachineDiagram { width: 114; height: 64; metrics: test.metrics }
                MachineDiagram { width: 214; height: 64; metrics: test.metrics }
            }
        }
    }
    MachineDiagram { id: narrowDetail; visible: test.phase === 5; width: 366; height: 320; detailed: true; metrics: test.metrics }
    SenomyAvatar { id: rotationTest; visible: test.phase >= 6; x: 920; y: 600; width: 48; height: 48 }
    Timer {
        interval: 450; running: true; repeat: true
        onTriggered: {
            try {
                if (test.phase === 0) {
                    test.check(rail.overflow && rail.offset === 1, "four workspaces reveal active fourth");
                    capture.grabToImage(r=>r.saveToFile(test.out+"/native.png"));
                    rail.grabToImage(r=>r.saveToFile(test.out+"/border-native.png"));
                } else if (test.phase === 1) {
                    Config.RailStyle.workspaceBorderType = "art";
                    Config.RailStyle.arrowBorderType = "art";
                } else if (test.phase === 2) {
                    capture.grabToImage(r=>r.saveToFile(test.out+"/art.png"));
                    rail.grabToImage(r=>{r.saveToFile(test.out+"/border-art.png");test.items = test.fixtures(3, 1);});
                } else if (test.phase === 3) {
                    test.check(!rail.overflow && Math.abs(rail.implicitWidth - 178)<1, "no arrow allocation at capacity");
                    test.check(rail.offset === 0, "offset clamped after removal");
                    test.items = test.fixtures(1, 1);
                } else if (test.phase === 4) {
                    test.check(Math.abs(rail.implicitWidth - 54)<1, "single workspace no empty slots");
                    test.items = test.fixtures(8, 8);
                } else if (test.phase === 5) {
                    test.check(rail.offset === 5 && rail.overflow, "eight workspaces follows active");
                    narrowDetail.grabToImage(r=>{
                        r.saveToFile(test.out+"/narrow-detail.png");
                        Config.RailStyle.avatarCircleSource = Qt.resolvedUrl("assets/icons/tray-up.svg");
                        Config.RailStyle.rotateAvatarCircle = true;
                    });
                    test.items = test.fixtures(0, 0);
                } else if (test.phase === 6) {
                    test.check(rotationTest.customCircle && rotationTest.rotationActive, "custom SVG rotation enabled");
                    rotationTest.animate = false;
                } else {
                    test.check(!rotationTest.rotationActive, "hidden/disabled rotation stops");
                    test.check(rail.offset === 0 && !rail.overflow, "empty model resets offset");
                    let m = test.metrics;
                    let b = {available:true,onBattery:true,percentage:0.05};
                    let n = {available:true,connectivityName:"Full"};
                    test.check(Health.observation(m,b,n).state === "critical", "critical battery");
                    b.onBattery=false;
                    test.check(Health.observation(m,b,n).state === "charging", "plugged low battery is not critical");
                    b.available=false; m.memoryPercent=95;
                    test.check(Health.observation(m,b,n).message.startsWith("RAM"), "RAM priority");
                    m.memoryPercent=20;m.cpuPercent=95;
                    test.check(Health.observation(m,b,n).message.startsWith("CPU"), "CPU warning");
                    m.ready=false;m.cpuPercent=0;
                    test.check(Health.observation(m,b,n).state === "unavailable", "unavailable telemetry");
                    console.log("PASS: borders, overflow, model shrink/empty, active reveal, health priorities");
                    Qt.quit();
                }
                test.phase++;
            } catch(e) { console.error("FAIL: "+e); Qt.exit(1); }
        }
    }
}
