import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import "config" as Config
import "components"
Scope {
    id: root
    property var metrics: ({ready:true,cpuPercent:5,memoryPercent:10,memoryTotalKib:2000000,memoryUsedKib:200000,kernelRelease:"test",hostName:"private",hostModel:"test",cpuModel:"test",temperatureAvailable:false,uptimeDetailedLabel:"00:00:01",history:null})
    readonly property bool privateSession: Quickshell.env("SENOMY_PRIVATE_OSK_TEST")==="1"
    Component.onCompleted: if(!privateSession) {console.error("FAIL: private compositor test opt-in required");Qt.exit(2);}
    property int phase: 0
    TestCase {id: probe;when:false}
    PanelWindow {screen:Quickshell.screens[0];visible:root.privateSession;anchors {bottom:true;left:true;right:true} implicitHeight:72;exclusiveZone:72;WlrLayershell.namespace:"senomy-test-rail"}
    MachineStateOverlay {id: machine;targetScreen:Quickshell.screens[0];metrics:root.metrics;senomy:null;requestedOpen:root.privateSession && root.phase<2}
    DashboardWindow {id: primary;targetScreen:Quickshell.screens[0];requestedOpen:root.privateSession && root.phase>=2 && root.phase<4;preferredWidth:960;preferredHeight:720;Rectangle {anchors.fill:parent;color:"#202530"}}
    PrimarySurfaceWindow {id: insights;targetScreen:Quickshell.screens[0];requestedOpen:root.privateSession && root.phase>=4;preferredWidth:960;preferredHeight:720;Rectangle {anchors.fill:parent;color:"#202530"}}
    function check(ok,label) {if(!ok){console.error("FAIL: "+label);Qt.exit(1);throw new Error(label);}}
    Timer {
        interval:500;running:root.privateSession;repeat:true
        onTriggered: {
            const screen=Quickshell.screens[0];
            if(root.phase===0) {Config.OskGeometry.update({ok:true,available:true,screen:screen.name,x:0,y:380,width:screen.width,height:200,reserved:true});root.phase++;return;}
            if(root.phase===1) {
                const scroll=probe.findChild(machine,"machineScroll");
                root.check(machine.fitted.y>=0 && machine.fitted.y+machine.fitted.height<=372,"expanded panel fits above keyboard");
                root.check(scroll && scroll.clip && scroll.interactive && scroll.contentHeight>scroll.height,"constrained expanded content scrolls inside frame");
                root.phase++;return;
            }
            if(root.phase===2) {
                root.check(primary.fitted.y>=0 && primary.fitted.y+primary.fitted.height<=372,"primary panel fits above keyboard");
                Config.OskGeometry.update({ok:true,available:true,screen:screen.name,x:0,y:0,width:screen.width,height:250,reserved:true});root.phase++;return;
            }
            if(root.phase===3) {
                root.check(primary.fitted.y>=258 && primary.fitted.y+primary.fitted.height<=screen.height-primary.reservedBottom,"dashboard fits below top keyboard and above Rail");
                Config.OskGeometry.update({ok:true,available:true,screen:screen.name,x:0,y:380,width:screen.width,height:200,reserved:true});root.phase++;return;
            }
            if(root.phase===4) {
                root.check(insights.fitted.y>=0 && insights.fitted.y+insights.fitted.height<=372,"Insights wrapper fits above keyboard");
                Config.OskGeometry.update({ok:true,available:true,screen:screen.name,x:0,y:0,width:screen.width,height:250,reserved:true});root.phase++;return;
            }
            if(root.phase===5) {
                root.check(insights.fitted.y>=258 && insights.fitted.y+insights.fitted.height<=screen.height-insights.reservedBottom,"Insights wrapper fits below top keyboard");
                Config.OskGeometry.update({ok:true,available:true,screen:screen.name,x:0,y:0,width:screen.width,height:250,reserved:false});root.phase++;return;
            }
            root.check(insights.WlrLayershell.layer===WlrLayer.Top && primary.WlrLayershell.layer===WlrLayer.Top && machine.WlrLayershell.layer===WlrLayer.Top,"floating OSK overlay stays above own shell panels");
            console.log("PASS: actual expanded, dashboard and Insights PanelWindows remain in bounds above/below OSK; expanded content scrolls; float layer ordering holds");Qt.quit();
        }
    }
}
