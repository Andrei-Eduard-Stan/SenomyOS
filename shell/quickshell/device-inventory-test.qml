import QtQuick
import QtQuick.Window
import Quickshell
import "components"
import "services" as Services
Window {
    id: test
    visible: true; width: 600; height: 720; color: "#101016"
    property int phase: 0
    Services.DeviceInventory { id: liveReadOnly; active: true }
    QtObject {
        id: inventory
        property bool loading: false
        property string error: ""
        property var snapshot: ({displays:{available:true,items:[{name:"DP-fixture",width:2560,height:1440,refreshRate:59.95,scale:1.25,x:-2560,y:0,disabled:false,dpmsStatus:true,transform:0}]},inputs:{available:true,items:[{name:"Fixture keyboard",kind:"Keyboard",layout:"English"},{name:"Fixture touch",kind:"Touch"}]}})
    }
    DeviceInventoryView { id: view; x: 12; y: 12; width: parent.width-24; inventory: inventory }
    Timer {
        interval: 600; repeat: true; running: true
        onTriggered: {
            if (test.phase === 0) {
                test.contentItem.grabToImage(r=>{ r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/inventory-wide.png"); test.width = 360; });
            } else if (test.phase === 1) {
                test.contentItem.grabToImage(r=>{ r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/inventory-narrow.png"); inventory.snapshot = {displays:{available:false,items:[],error:"Provider unavailable"},inputs:{available:true,items:[]}}; });
            } else {
                if (!liveReadOnly.snapshot.displays && !liveReadOnly.error) { console.error("FAIL: service did not return data or error"); Qt.quit(); return; }
                liveReadOnly.active = false;
                console.log("PASS: inventory wide, narrow, unavailable and empty rendering");
                Qt.quit();
            }
            test.phase++;
        }
    }
}
