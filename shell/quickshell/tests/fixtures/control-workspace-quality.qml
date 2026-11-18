import QtQuick
import QtQuick.Window
import Quickshell.Services.UPower
import Quickshell.Networking
import "config" as Config
import QtTest
import Quickshell
import "components"
import "services"
import "components/ControlDirectory.js" as Directory

Window {
    id: test
    visible: true; width: 1120; height: 820
    property int mutations: 0
    property var fakeWifi: Array.from({length:24},(_,i)=>({name:"Network "+i,known:true,connected:false,security:0,signalStrength:0.7,stateChanging:false}))
    property var fakeBluetooth: Array.from({length:24},(_,i)=>({name:"Bluetooth "+i,connected:false,paired:true,pairing:false}))
    property var fakeOutputs: Array.from({length:16},(_,i)=>({name:"Output "+i,description:"Output "+i,ready:false,audio:null}))
    property var fakeInputs: Array.from({length:16},(_,i)=>({name:"Input "+i,description:"Input "+i,ready:false,audio:null}))
    TestCase { id: input; when: false }
    ShellState {id:state;activePrimary:"control";primaryScreen:"fixture";confirmationSources:[actions]}
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
    QtObject {
        id:inventory
        property var policy: ({autoRecovery:false})
        property var snapshot: ({inputs:{available:true,items:Array.from({length:9},(_,i)=>({name:"Keyboard "+i,kind:"Keyboard",layout:"English (UK)"}))},displays:{available:true,items:[]}})
        property bool loading:false
        property string error:"Fixture unavailable"
        property var displays:[]
        property var displayActions:actions
    }
    QtObject {id:care;property var snapshot:({persistentAvailable:false,persistenceReason:"Private fixture"});property var packs:[];property bool persistentChoice:false;property bool locked:false;property bool installed:false;property bool busy:false;property bool fresh:false;property bool blocked:false;property string message:"";property string actionState:"idle";property string title:"Private care fixture";property string impact:"No hardware operation";function refresh(){test.mutations++;}function cancel(){test.mutations++;}function confirm(){test.mutations++;}}
    ControlCentre {
        id: panel
        anchors.fill: parent
        targetScreen: ({name:"fixture"})
        state: state
        metrics: ({ready:true,cpuPercent:17,memoryPercent:28,memoryTotalKib:33554432,uptimeLabel:"3h 14m"})
        audio: ({ready:true,volumeLimit:1.5,setVolume:function(v){test.mutations++;},setInputVolume:function(v){test.mutations++;},toggleMuted:function(){test.mutations++;},toggleInputMuted:function(){test.mutations++;},available:true,inputAvailable:true,inputMuted:false,inputName:"Built-in microphone",inputNodes:test.fakeInputs,inputVolume:.82,label:"48%",muted:false,outputName:"Studio speakers",outputNodes:test.fakeOutputs,volume:.48,sink:null,source:null,selectionActions:actions,preferences:{routes:[]},preferenceMessage:"",playbackStreams:[],recordingStreams:[],actionsLocked:false,graphSnapshot:{available:false,nodes:[],cards:[],error:"Fixture unavailable"},nodeName:function(n){return n.description||n.name;}})
        network: ({profiles:null,connectionAttempt:{message:"",actionState:"idle"},actions:actions,activeConnection:"Studio Wi-Fi",available:true,connectivity:NetworkConnectivity.Full,connectivityName:"Internet available",detail:"Fake unavailable provider",label:"Unavailable",managedDevices:[],primaryDevice:"",scanning:false,sortedWifiNetworks:test.fakeWifi,wifiEnabled:true,wifiHardwareEnabled:true,toggleWifi:function(){test.mutations++;}})
        bluetooth: ({actions:actions,available:false,devices:test.fakeBluetooth,discovering:false,enabled:true})
        battery: ({available:true,care:care,batteries:[],charging:false,count:0,detail:"On battery · 2 packs",label:"76%",onBattery:true,powerProfile:PowerProfile.Balanced,powerProfileAvailable:true,powerProfileName:"Balanced",selectionActions:actions,selectionOptions:function(){return [PowerProfile.PowerSaver,PowerProfile.Balanced,PowerProfile.Performance];},setPowerProfile:function(v){test.mutations++;return true;},timeLabel:"4h 20m"})
        media: ({available:false,artist:"",identity:"Fixture",playing:false,selectedPlayer:null,players:[],artwork:"",position:0,duration:0,title:"No player"})
        notifications: ({dnd:false,serverEnabled:true,setDnd:function(){test.mutations++;}})
        senomy: ({message:"Synthetic system assessment",state:"nominal"})
        inputSettings: inputProvider
        desktopSettings: settings
        sessionPolicy: test.sessionProvider
        deviceInventory: inventory
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
    Timer {interval:500;running:true;onTriggered:{try{
        for(const size of [{w:1120,h:800},{w:1280,h:860},{w:680,h:760},{w:390,h:640}]){
            test.width=size.w;test.height=size.h;input.wait(60);state.controlMode=size.w===1280?"full":"compact";panel.navigateId("overview");input.wait(100);test.capture("overview-"+size.w,panel);
            for(const route of ["network/wifi","audio/overview","power/profiles","input/keyboard","devices/inputs","apps","settings/notifications"]){panel.navigateId(route);input.wait(100);test.capture(route.replace(/\//g,"-")+"-"+size.w,panel);}
        }
        test.width=1120;test.height=800;panel.navigateId("overview");input.wait(80);
        const overview=input.findChild(panel,"control-overview"),dnd=input.findChild(panel,"overview-dnd");test.verify(dnd.text.includes("Off"),"DND off visible");dnd.forceActiveFocus(Qt.TabFocusReason);input.wait(30);test.capture("overview-focus",panel);dnd.clicked();test.verify(test.mutations===1,"explicit DND callback once");test.mutations=0;
        const savedNotifications=panel.notifications;panel.notifications=({dnd:true,serverEnabled:true,setDnd:function(){test.mutations++;}});input.wait(30);test.capture("overview-dnd-on",panel);panel.notifications=savedNotifications;
        const savedBattery=panel.battery;panel.battery=Object.assign({},savedBattery,{powerProfileAvailable:false,powerProfileName:"Unavailable",selectionOptions:function(){return [];}});panel.navigateId("power/profiles");input.wait(100);test.capture("power-unsupported",panel);test.verify(!input.findChild(panel,"control-power-profile-"+PowerProfile.PowerSaver).enabled,"unsupported profiles remain disabled");panel.battery=savedBattery;
        panel.navigateId("overview");input.wait(80);panel.navigation.query="wallpaper";input.wait(40);test.verify(panel.navigation.rows.some(n=>n.id==="appearance/backgrounds"),"directory search synonym retained");test.capture("directory-search",panel);panel.navigation.query="";
        test.width=390;test.height=640;input.wait(40);panel.navigationOpen=true;panel.navigation.query="microphone";input.wait(40);panel.navigation.focusSearch();test.capture("directory-narrow-focus",panel);panel.navigation.query="";panel.navigationOpen=false;
        const body=input.findChild(panel,"control-overview");body.contentY=Math.max(0,body.contentHeight-body.height);input.wait(40);test.capture("overview-narrow-bottom",panel);
        const registry=JSON.parse(JSON.stringify(Config.Skin.registry));Config.Skin.registry=Object.assign({},registry,{persona:Object.assign({},registry.persona || {},{uiTextScale:1.5,touchMode:true,highContrast:true,reducedMotion:true})});test.width=760;test.height=720;Config.DirectoryStyle.touchMode=true;input.wait(60);panel.navigateId("overview");input.wait(80);const enlarged=input.findChild(panel,"control-overview");enlarged.contentY=0;input.wait(30);test.capture("overview-large-touch",panel);enlarged.contentY=Math.max(0,enlarged.contentHeight-enlarged.height);input.wait(30);test.capture("overview-large-touch-bottom",panel);Config.DirectoryStyle.touchMode=false;Config.Skin.registry=registry;
        test.width=680;test.height=680;panel.navigateId("appearance/backgrounds");input.wait(100);const source=input.findChild(panel,"backgroundSource");source.forceActiveFocus(Qt.TabFocusReason);input.keyClick(Qt.Key_A);input.wait(30);test.verify(!panel.navigateId("settings/idle"),"dirty form retains route");input.wait(30);test.capture("dirty-review",panel);const keep=input.findChild(panel,"control-keep-editing");keep.forceActiveFocus(Qt.TabFocusReason);input.wait(30);test.capture("dirty-review-focus",panel);keep.clicked();
        test.verify(test.mutations===0,"navigation/filtering/focus never mutates provider");console.log("PASS: actual Control Centre composition/paths, explicit inert DND, truthful supported/unsupported profiles, narrow/large/focus/dirty review; inert providers only");Qt.quit();
    }catch(e){console.error("FAIL: "+e.message);Qt.exit(1);}}}
}
