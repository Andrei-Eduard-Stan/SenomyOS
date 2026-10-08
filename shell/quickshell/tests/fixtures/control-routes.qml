import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"

Window {
    id: test
    visible: true; width: 1120; height: 820
    property int mutations: 0
    property var fakeWifi: Array.from({length:24},(_,i)=>({name:"Network "+i,known:true,connected:false,security:0,signalStrength:0.7,stateChanging:false}))
    property var fakeBluetooth: Array.from({length:24},(_,i)=>({name:"Bluetooth "+i,connected:false,paired:true,pairing:false}))
    property var fakeOutputs: Array.from({length:16},(_,i)=>({name:"Output "+i,description:"Output "+i}))
    property var fakeInputs: Array.from({length:16},(_,i)=>({name:"Input "+i,description:"Input "+i}))
    TestCase { id: input; when: false }
    QtObject {
        id: state
        property string activePrimary: "control"
        property string primaryScreen: "fixture"
        property string controlSection: "overview"
        function closePrimary() { activePrimary = ""; }
    }
    QtObject {
        id: actions
        property string actionState: "idle"
        property bool locked: false
        property string title: "Fixture action"
        property string action: "disable"
        property string targetName: "Fixture target"
        property string impact: "Fake provider only"
        property string message: ""
        property string actionKind: "configuration"
        property var previous: null
        property var proposed: null
        function cancel() { test.mutations++; }
        function confirm() { test.mutations++; }
    }
    QtObject {
        id: inputProvider
        signal releasePrimaryFocusRequested()
        property bool available: true
        property bool busy: false
        property bool firstRun: true
        property string layout: "us"
        property var layouts: ["us","gb"]
        property string message: ""
        property bool naturalScroll: false
        property bool tapToClick: true
        property int repeatDelay: 600
        property int repeatRate: 25
        property real sensitivity: 0
        property bool usFallback: false
        property bool editorAvailable: false
        property bool engineInstalled: false
        property bool nativeToolsBusy: false
        property string nativeToolsMessage: ""
        property var oskController: null
        property var oskCapabilities: ({providerInstalled:false,protocolState:"unknown",message:"Fixture unavailable"})
        function apply() { test.mutations++; }
    }

    property var sessionProvider: ({available:false,busy:false,configured:false,activationRequired:false,displayOffSeconds:600,lockSeconds:300,lidAction:"lock",lidAvailable:false,message:"",error:"",apply:function(){test.mutations++;}})
    ControlCentre {
        id: panel
        anchors.fill: parent
        targetScreen: ({name:"fixture"})
        state: state
        metrics: ({cpuPercent:10,memoryPercent:20,uptimeLabel:"Fixture uptime"})
        audio: ({available:false,inputAvailable:false,inputMuted:false,inputName:"Unavailable",inputNodes:test.fakeInputs,inputVolume:0,label:"Unavailable",muted:false,outputName:"Unavailable",outputNodes:test.fakeOutputs,volume:0,sink:null,source:null,selectionActions:actions})
        network: ({actions:actions,activeConnection:"",available:false,connectivityName:"Unavailable",detail:"Fake unavailable provider",label:"Unavailable",managedDevices:[],primaryDevice:"",scanning:false,sortedWifiNetworks:test.fakeWifi,wifiEnabled:true,wifiHardwareEnabled:true})
        bluetooth: ({actions:actions,available:false,devices:test.fakeBluetooth,discovering:false,enabled:true})
        battery: ({batteries:[],charging:false,count:0,detail:"No fixture battery",label:"Unavailable",onBattery:false,powerProfile:0,powerProfileAvailable:false,powerProfileName:"Unavailable",selectionActions:actions,selectionOptions:function(){return [];},timeLabel:"Unavailable"})
        media: ({available:false,artist:"",identity:"Fixture",playing:false,selectedPlayer:null,title:"No player"})
        notifications: ({dnd:false,serverEnabled:false,setDnd:function(){test.mutations++;}})
        senomy: ({message:"Fixture",state:"nominal"})
        inputSettings: inputProvider
        sessionPolicy: test.sessionProvider
        deviceInventory: ({snapshot:{},loading:false,error:"Fixture unavailable",displays:[],displayActions:actions})
    }
    function within(item, ancestor) {
        while (item) {
            if (item === ancestor) return true;
            item = item.parent;
        }
        return false;
    }
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); }
    }
    Timer {
        interval: 500; running: true
        onTriggered: {
            for (const size of [{w:1120,h:820},{w:720,h:500}]) {
                test.width = size.w; test.height = size.h; input.wait(80);
                for (const actionState of ["idle","pending"]) {
                actions.actionState = actionState;
                for (const section of panel.sections) {
                    state.controlSection = section.id;
                    panel.navigation.focusSection(); input.wait(60);
                    const selected = panel.navigation.itemAtIndex(panel.navigation.currentIndex);
                    test.check(selected && selected.activeFocus, section.id + " selected-route focus");
                    const seen = new Set();
                    const steps = ["network","audio","devices"].indexOf(section.id) >= 0 && actionState === "idle" ? 90 : 45;
                    for (let step = 0; step < steps; step++) {
                        input.keyClick(Qt.Key_Tab); input.wait(2);
                        const item = test.activeFocusItem;
                        if (item && item.visible && test.within(item,panel.contentArea)) {
                            let record = item;
                            while (record && record !== panel.contentArea) {
                                if (record.modelData && record.modelData.name) seen.add(record.modelData.name);
                                record = record.parent;
                            }
                            let ancestor = item.parent;
                            while (ancestor && ancestor !== panel.contentArea) {
                                if (ancestor.clip) {
                                    const nested = item.mapToItem(ancestor,0,0);
                                    test.check(nested.y >= -1 && nested.y + item.height <= ancestor.height + 1,
                                        section.id + " focus clipped inside " + ancestor + " at " + nested.y);
                                }
                                ancestor = ancestor.parent;
                            }
                            const position = item.mapToItem(panel.contentArea,0,0);
                            test.check(position.y >= -1 && position.y + item.height <= panel.contentArea.height + 1,
                                section.id + " keyboard focus clipped vertically: " + item + " at " + position.y);
                        }
                    }
                    if (actionState === "idle" && ["network","audio","devices"].indexOf(section.id) >= 0) {
                        const expected = section.id === "audio" ? 32 : 24;
                        test.check(seen.size === expected,section.id + " only reached " + seen.size + " of " + expected + " device controls");
                    }
                    test.check(test.mutations === 0,"route loading/Tab must not mutate fake providers");
                }
                }
            }
            state.activePrimary = "insights";
            state.controlSection = "input";
            inputProvider.releasePrimaryFocusRequested();
            test.check(state.activePrimary === "insights","late OSK release must not close another primary surface");
            state.activePrimary = "control";
            state.controlSection = "audio";
            inputProvider.releasePrimaryFocusRequested();
            test.check(state.activePrimary === "control","late OSK release must not close another Control Centre route");
            state.controlSection = "input";
            inputProvider.releasePrimaryFocusRequested();
            test.check(state.activePrimary === "","OSK show releases only the current Input primary surface");
            test.check(test.mutations === 0,"focus release must not mutate providers");
            console.log("PASS: actual Control Centre routes load and keep keyboard focus visible at wide and constrained sizes; fake providers and window host only");
            Qt.quit();
        }
    }
}
