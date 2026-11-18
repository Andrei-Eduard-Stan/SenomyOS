//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
import QtQuick
import QtTest
import Quickshell
import "components"

Scope {
    id: test
    TestCase { id: input; when: false }
    property string out: Quickshell.env("SENOMY_QA_OUT")
    property int phase: 0
    property var metrics: ({ready:true,cpuPercent:32,memoryPercent:21,networkRxKib:3,networkTxKib:8,uptimeLabel:"5h 24m"})
    QtObject {
        id: state
        property string activePrimary: "performance"
        property string primaryScreen: Quickshell.screens[0].name
        property string performanceSection: "overview"
        function closePrimary() { activePrimary = ""; }
    }
    QtObject {
        id: perf
        property bool benchmarkPageActive: false
        property var cpuHistory: Array.from({length:60}, (_,i) => 25 + Math.sin(i)*8)
        property var memoryHistory: Array(60).fill(21)
        property var rxHistory: Array.from({length:60}, (_,i) => i%9)
        property var txHistory: Array.from({length:60}, (_,i) => i%7)
        property var details: ({health:{hostname:"fixture",kernel:"test-kernel"},services:{available:true,failed_total:0,user_state:"running"},storage:{percent:20,used_bytes:1000000000,total_bytes:5000000000,devices:[]},cpu_inventory:{},sensors:{temperatures:[]}})
        property var processes: []
        property string error: ""
        property var benchmarkStatus: ({state:"idle",state_label:"READY",progress:0,message:"Fixture only",logs:[]})
        property var benchmarkPlans: ({})
        property string benchmarkActionState: "idle"
        property string pendingBenchmark: ""
    }
    PerformanceDashboard {
        id: panel
        targetScreen: Quickshell.screens[0]
        preferredWidth: test.phase >= 7 ? 520 : 720
        preferredHeight: 740
        state: state; performance: perf; metrics: test.metrics
        battery: ({label:"26%",detail:"Two packs · on battery"})
        network: ({label:"CONNECTED",detail:"Fixture network"})
    }
    Timer {
        interval: 1200; running: true; repeat: true
        onTriggered: {
            if (test.phase === 8) {
                console.log("PASS: dashboard routes rendered at narrow widths without executing actions");
                Qt.quit(); return;
            }
            const name = test.phase === 7 ? "overview-520" : state.performanceSection + "-720";
            panel.captureItem.grabToImage(result => {
                if (!result.saveToFile(test.out + "/" + name + ".png")) { console.error("FAIL: capture " + name); Qt.exit(1); return; }
                test.phase++;
                const next = ["overview","cpu","memory","storage","network","processes","benchmarks","overview"][test.phase] || "overview";
                const button = input.findChild(panel.captureItem, "dashboard-nav-" + next);
                if (!button) { console.error("FAIL: missing navigation " + next); Qt.exit(1); return; }
                input.mouseClick(button, button.width / 2, button.height / 2);
                if (state.performanceSection !== next) { console.error("FAIL: navigation " + next); Qt.exit(1); }
            });
        }
    }
}
