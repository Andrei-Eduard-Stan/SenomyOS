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
    property var fakeBluetooth: Array.from({length:24},(_,i)=>({id:"/org/bluez/hci0/dev_"+i,token:"device-"+i,adapter:"/org/bluez/hci0",name:"Bluetooth "+i,icon:"bluetooth",connected:false,paired:true,bonded:true,trusted:false,blocked:false,battery:null,recent:false,group:"paired",expected:{Paired:true,Connected:false}}))
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
    QtObject {id:accountData;property bool available:true;property bool loading:false;property bool locked:false;property string actionState:"idle";property string operation:"";property string proposed:"";property string message:"";property var target:null;property var snapshot:({currentUid:2001,complete:true,message:"Synthetic account provider",passwordAvailable:false});property var accounts:[{uid:2001,name:"Fixture owner",username:"owner",current:true,locked:false,administrator:true,managed:true,avatar:""},{uid:2002,name:"Guest",username:"guest",current:false,locked:false,administrator:false,managed:true,avatar:""}];function cancel(){actionState="idle";}function refresh(){test.mutations++;}function request(){test.mutations++;}}
    QtObject {id:streamGain;property real volume:.55;property bool muted:false}
    QtObject {id:sampleStream;property string app:"Browser";property int id:99;property string description:"Browser playback";property string name:"browser-stream";property bool ready:true;property var audio:streamGain}
    QtObject {id:secondStream;property string app:"Music";property int id:100;property string description:"Music playback";property string name:"music-stream";property bool ready:true;property var audio:streamGain}
    BluetoothService {
        id:bluetoothProvider;transportEnabled:false;actionContext:"fixture"
        snapshot:({available:true,error:"",adapters:[{id:"/org/bluez/hci0",token:"adapter",name:"Fixture adapter",powered:true,discovering:false,powerState:"on",expected:{Powered:true}}],devices:test.fakeBluetooth,operations:{},scan:{state:"idle",owned:false,message:""},prompt:null})
        onTestRequest:request=>test.mutations++
    }
    ControlCentre {
        id: panel
        anchors.fill: parent
        targetScreen: ({name:"fixture"})
        state: state
        metrics: ({ready:true,cpuPercent:17,memoryPercent:28,memoryTotalKib:33554432,uptimeLabel:"3h 14m"})
        audio: ({ready:true,volumeLimit:1.5,setVolume:function(v){test.mutations++;},setInputVolume:function(v){test.mutations++;},toggleMuted:function(){test.mutations++;},toggleInputMuted:function(){test.mutations++;},available:true,inputAvailable:true,inputMuted:false,inputName:"Built-in microphone",inputNodes:test.fakeInputs,inputVolume:.82,label:"48%",muted:false,outputName:"Studio speakers",outputNodes:test.fakeOutputs,volume:.48,sink:null,source:null,selectionActions:actions,preferences:{routes:[]},preferenceMessage:"",playbackStreams:[sampleStream,secondStream],preferenceBusy:false,appName:function(n){return n.app;},appKey:function(n){return n.app;},routeName:function(n){return "Built-in speakers";},routes:function(n){return [];},graphNode:function(n){return null;},rememberedRoute:function(n){return null;},rememberedEndpoint:function(n){return null;},setNodeVolume:function(n,v){test.mutations++;},toggleNodeMuted:function(n){test.mutations++;},recordingStreams:[],actionsLocked:false,graphSnapshot:{canMove:false,available:false,nodes:[],cards:[],error:"Fixture unavailable"},nodeName:function(n){return n.description||n.name;}})
        network: ({profiles:null,connectionAttempt:{message:"",actionState:"idle"},actions:actions,activeConnection:"Studio Wi-Fi",available:true,connectivity:NetworkConnectivity.Full,connectivityName:"Internet available",detail:"Fake unavailable provider",label:"Unavailable",managedDevices:[],primaryDevice:"",scanning:false,sortedWifiNetworks:test.fakeWifi,wifiEnabled:true,wifiHardwareEnabled:true,toggleWifi:function(){test.mutations++;}})
        bluetooth:bluetoothProvider
        battery: ({available:true,care:care,batteries:[],charging:false,count:0,detail:"On battery · 2 packs",label:"76%",onBattery:true,powerProfile:PowerProfile.Balanced,powerProfileAvailable:true,powerProfileName:"Balanced",selectionActions:actions,selectionOptions:function(){return [PowerProfile.PowerSaver,PowerProfile.Balanced,PowerProfile.Performance];},setPowerProfile:function(v){test.mutations++;return true;},timeLabel:"4h 20m"})
        media: ({available:false,artist:"",identity:"Fixture",playing:false,selectedPlayer:null,players:[],artwork:"",position:0,duration:0,title:"No player"})
        notifications: ({dnd:false,serverEnabled:true,setDnd:function(){test.mutations++;}})
        senomy: ({message:"Synthetic system assessment",state:"nominal"})
        accounts:accountData
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
    function requireObject(name){let item=null;for(let i=0;i<160&&!item;i++){item=input.findChild(panel,name);if(!item)input.wait(20);}test.verify(!!item,"loaded control: "+name);return item;}
    Timer {interval:500;running:true;onTriggered:{try{
        for(const size of [{w:1120,h:820},{w:680,h:760},{w:390,h:700}]){test.width=size.w;test.height=size.h;input.wait(60);for(const route of ["accounts","audio/mixer","input/methods","devices/bluetooth"]){panel.navigateId(route);input.wait(100);test.capture(route.replace(/\//g,"-")+"-"+size.w,panel);}}
        test.width=1120;test.height=820;panel.navigateId("audio/mixer");input.wait(80);const search=test.requireObject("audioStreamSearch");search.text="browser";input.wait(40);test.capture("audio-mixer-search",panel);search.text="does-not-match";input.wait(40);test.capture("audio-mixer-empty",panel);search.text="";
        panel.navigateId("accounts");input.wait(80);const field=test.requireObject("account-display-name");field.forceActiveFocus(Qt.TabFocusReason);input.keyClick(Qt.Key_End);input.keyClick(Qt.Key_A);input.wait(40);test.verify(!panel.navigateId("input/methods"),"account changes retain navigation guard");test.capture("account-dirty-review",panel);
        test.verify(test.mutations===0,"deep navigation/filtering/drafting never dispatches");console.log("PASS: redesigned deeper account/audio/input/Bluetooth content renders, local stream search and account dirty review; inert providers only");Qt.quit();
    }catch(error){console.error("FAIL: "+error.message+"\n"+(error.stack || ""));Qt.exit(1);}}}
}
