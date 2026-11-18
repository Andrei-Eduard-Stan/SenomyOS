import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services"

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
        property string controlPath:""
        property var controlPins:[]
        onControlSectionChanged:controlPath=""
        property bool controlDraftDirty:false
        property var deferredPrimary:null
        function completeDeferredPrimary(){return false;}
        function showPrimary(){return true;}
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
        property var oskAutomatic: ({mode:"manual",settingMode:false,status:"Fixture unavailable"})
        property var oskController: null
        property var oskCapabilities: ({providerInstalled:false,protocolState:"unknown",message:"Fixture unavailable"})
        function apply() { test.mutations++; }
    }

    property var sessionProvider: ({available:false,busy:false,configured:false,activationRequired:false,displayOffSeconds:600,lockSeconds:300,lidAction:"lock",lidAvailable:false,message:"",error:"",apply:function(){test.mutations++;}})
    QtObject{id:runner;property bool running:false;function exec(args){test.mutations++;}}
    DesktopPreferenceActions{id:reviews;runner:runner;helper:"fixture.py";active:true;context:"apps:fixture";defaults:settings.defaults;autostart:settings.autostart;apps:settings.apps;deployment:settings.deployment}
    QtObject {
        id:settings;property bool available:true;property bool loading:false;property string error:"";property string capabilityError:"";property string message:"Fixture desktop registry"
        property var actions:reviews
        property var defaults:Array.from({length:6},(_,i)=>({mime:i===0?"text/plain":"type/"+i,label:"Role "+i,current:"one.desktop",currentName:"Fixture One",options:[{id:"one.desktop",name:"Fixture One"},{id:"two.desktop",name:"Fixture Two"}],token:"role-token"}))
        property var apps:[{id:"two.desktop",name:"Fixture Two",token:"app-token",autostartAllowed:true}]
        property var autostart:Array.from({length:24},(_,i)=>({id:"entry-"+i+".desktop",name:"Autostart "+i,enabled:true,eligible:true,protected:i===0,source:"user",token:"entry-token"}))
        property var deployment:({supported:true,enabled:false,token:"deployment-token",message:"Future login required"})
        property var capabilities:({services:[{unit:"fixture-portal.service",available:true,state:"active"}],portal:{state:"advertised",message:"Not physical acceptance",features:[{name:"ScreenCast",advertised:true}]},flatpakAvailable:false,permissionPolicy:"Fixture native permission dialogs",journeys:"Fixture journeys"})
        function refresh(){test.mutations++;}
    }
    ControlCentre {
        id: panel
        anchors.fill: parent
        targetScreen: ({name:"fixture"})
        state: state
        metrics: ({cpuPercent:10,memoryPercent:20,uptimeLabel:"Fixture uptime"})
        audio: ({available:false,inputAvailable:false,inputMuted:false,inputName:"Unavailable",inputNodes:test.fakeInputs,inputVolume:0,label:"Unavailable",muted:false,outputName:"Unavailable",outputNodes:test.fakeOutputs,volume:0,sink:null,source:null,selectionActions:actions})
        network: ({connectionAttempt:{message:"",actionState:"idle"},actions:actions,activeConnection:"",available:false,connectivityName:"Unavailable",detail:"Fake unavailable provider",label:"Unavailable",managedDevices:[],primaryDevice:"",scanning:false,sortedWifiNetworks:test.fakeWifi,wifiEnabled:true,wifiHardwareEnabled:true})
        bluetooth: ({actions:actions,available:false,devices:test.fakeBluetooth,discovering:false,enabled:true})
        battery: ({batteries:[],charging:false,count:0,detail:"No fixture battery",label:"Unavailable",onBattery:false,powerProfile:0,powerProfileAvailable:false,powerProfileName:"Unavailable",selectionActions:actions,selectionOptions:function(){return [];},timeLabel:"Unavailable"})
        media: ({available:false,artist:"",identity:"Fixture",playing:false,selectedPlayer:null,title:"No player"})
        notifications: ({dnd:false,serverEnabled:false,setDnd:function(){test.mutations++;}})
        senomy: ({message:"Fixture",state:"nominal"})
        inputSettings: inputProvider
        desktopSettings: settings
        sessionPolicy: test.sessionProvider
        deviceInventory: ({snapshot:{},loading:false,error:"Fixture unavailable",displays:[],displayActions:actions})
    }

    function capture(name,item) {
        let done=false;
        item.grabToImage(function(result){result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});
        while(!done)input.wait(20);
    }
    function verify(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
    function focusable(item,output){
        if(!item.visible)return;
        if(item.activeFocusOnTab && item.enabled)output.push(item);
        for(const child of item.children)focusable(child,output);
    }
    function checkFocus(){
        const controls=[];focusable(panel.contentArea,controls);
        for(const item of controls){
            item.forceActiveFocus(Qt.TabFocusReason);input.wait(15);
            let ancestor=item.parent;
            while(ancestor && ancestor!==panel.contentArea){
                if(ancestor.clip){
                    const pos=item.mapToItem(ancestor,0,0);
                    verify(pos.x>=-1 && pos.x+item.width<=ancestor.width+1,"horizontal focus clipped: "+state.controlSection);
                    verify(pos.y>=-1 && pos.y+item.height<=ancestor.height+1,"vertical focus clipped: "+state.controlSection);
                }
                ancestor=ancestor.parent;
            }
        }
    }
    Timer {interval:500;running:true;onTriggered:{
        for(const size of [{w:1120,h:820},{w:390,h:640}]){
            test.width=size.w;test.height=size.h;input.wait(100);
            for(const section of panel.sections){state.controlSection=section.id;input.wait(120);test.capture("control-"+section.id+"-"+size.w,panel);if(size.w===390)test.checkFocus();}
            if(size.w<850){panel.navigationOpen=true;input.wait(100);test.capture("control-navigation-"+size.w,panel);panel.navigationOpen=false;}
        }
        test.width=390;state.controlSection="overview";panel.metrics=({ready:false,cpuPercent:0,memoryPercent:0,memoryTotalKib:0,uptimeLabel:""});input.wait(80);test.capture("control-warming-390",panel);
        function values(item,output){if(item.title && item.value!==undefined)output.push(item.value);for(const child of item.children)values(child,output);}
        const readings=[];values(panel.contentArea,readings);test.verify(readings.filter(value=>value==="WARMING").length===2,"startup metrics cannot appear as healthy zeros");
        if(test.mutations!==0){console.error("FAIL: capturing routes mutated fixture provider");Qt.exit(1);return;}
        console.log("PASS: actual Control Centre window layout, portrait focus visibility and persistent drawer/header captured without mutations");Qt.quit();
    }}
}
