import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Services.UPower
import "services"
import "components/control"
Window {
    id: suite; visible:true; width:390; height:760
    property int phase: 0
    property int ticks: 0
    function check(value, message) { if (!value) throw new Error(message); }
    BatteryService { id: battery; provider:source; energy:fake; energyEnabled:false; actionContext:"private-test" }
    QtObject {
        id: fake
        property bool available:true
        property string profile:"balanced"
        property string identity:"fixture-owner"
        property var profiles:["balanced","power-saver","performance"]
        property var backend:({kind:"tlp",token:"fixture-token",semantics:"Runtime only; fixture performs no writes."})
        property var diagnostics:({packs:[{name:"Fixture",healthPercent:80,cycleCount:20,startThreshold:75,stopThreshold:80,thresholdReason:"Read only. Supported vendor range and persistent authorization require separate review."}],cpus:[],inhibitors:[],policy:{IdleAction:"ignore",HandleLidSwitch:"ignore",HandleLidSwitchDocked:"ignore"}})
        property bool busy:false
        property bool runningAction:false
        property bool actionFailed:false
        property string actionError:""
        function refresh() {}
    }
    QtObject {
        id:source
        property var devices:({values:[{ready:true,isLaptopBattery:true,isPresent:true,energy:20,energyCapacity:40,percentage:.5,state:UPowerDeviceState.Discharging,changeRate:10,model:"Fixture pack"}]})
        property bool onBattery:true
        property var displayDevice:({ready:false})
    }
    ControlPowerPage {id:page;anchors.fill:parent;battery:battery;part:"profiles"}
    TestCase {id:input;when:false}
    Timer {interval:100;repeat:true;running:true;onTriggered:{
        try {
            if (++suite.ticks>50)throw new Error("Page deadline");
            if(suite.phase===0){
                const b=input.findChild(page,"control-power-profile-"+PowerProfile.PowerSaver);
                suite.check(!!b && b.enabled,"supported profile reachable");
                page.contentY=Math.max(0,b.mapToItem(page.contentItem,0,0).y-100);
                b.forceActiveFocus();input.keyClick(Qt.Key_Space);
                suite.check(battery.selectionActions.actionState==="pending","keyboard opens review only");
                suite.phase++;return;
            }
            if(suite.phase===1){
                const cancel=input.findChild(page,"selectionCancel");page.contentY=0;
                input.mouseClick(cancel,cancel.width/2,cancel.height/2);
                suite.check(battery.selectionActions.actionState==="idle","pointer cancels review");
                page.part="batteries";suite.phase++;return;
            }
            if(suite.phase===2){
                suite.check(page.contentHeight>0,"battery care layout");
                suite.width=1120;page.part="overview";suite.phase++;return;
            }
            if(suite.phase===3){
                suite.check(page.width===1120 && page.contentHeight>0,"wide diagnostics layout");
                suite.width=470;suite.height=486;page.compact=true;page.part="profiles";suite.phase++;return;
            }
            suite.check(page.width===470 && page.height===486,"fixed popup content geometry");
            console.log("PASS: native power page narrow/wide/compact, keyboard review and pointer cancellation; no writes");Qt.quit();
        }catch(e){console.error("FAIL: "+e.message+" "+e.stack);Qt.exit(1);}
    }}
}
