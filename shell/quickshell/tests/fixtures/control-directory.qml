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
        audio: ({ready:true,volumeLimit:1.5,setVolume:function(v){test.mutations++;},setInputVolume:function(v){test.mutations++;},toggleMuted:function(){test.mutations++;},toggleInputMuted:function(){test.mutations++;},available:true,inputAvailable:true,inputMuted:false,inputName:"Built-in microphone",inputNodes:test.fakeInputs,inputVolume:.82,label:"48%",muted:false,outputName:"Studio speakers",outputNodes:test.fakeOutputs,volume:.48,sink:null,source:null,selectionActions:actions,preferences:{routes:[]},preferenceMessage:"",playbackStreams:[],recordingStreams:[],actionsLocked:false,graphSnapshot:{available:false,nodes:[],cards:[],error:"Fixture unavailable"},nodeName:function(n){return n.description||n.name;}})
        network: ({profiles:null,connectionAttempt:{message:"",actionState:"idle"},actions:actions,activeConnection:"Studio Wi-Fi",available:true,connectivity:NetworkConnectivity.Full,connectivityName:"Internet available",detail:"Fake unavailable provider",label:"Unavailable",managedDevices:[],primaryDevice:"",scanning:false,sortedWifiNetworks:test.fakeWifi,wifiEnabled:true,wifiHardwareEnabled:true,toggleWifi:function(){test.mutations++;}})
        bluetooth:bluetoothProvider
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
    Timer {interval:500;running:true;onTriggered:{
        for(const size of [{w:1120,h:820},{w:390,h:640}]){
            test.width=size.w;test.height=size.h;input.wait(80);
            const entries=Directory.all(panel.navigationNodes).filter(n=>!n.dynamic);
            for(const node of entries){test.verify(panel.navigateId(node.id),"Destination rejected "+node.id);input.wait(40);test.verify(panel.routeId===node.id || panel.state.controlSection===node.id,"Incorrect destination");test.capture("directory-"+node.id.replace(/\//g,"-")+"-"+size.w,panel);if(size.w===390)test.checkFocus();}
        }
        test.width=1120;test.height=820;panel.navigateId("devices/displays");input.wait(50);panel.navigateId("devices/inputs");input.wait(50);
        function findDevice(item){if(item.objectName==="control-device-Keyboard%200")return item;for(const child of item.children){const hit=findDevice(child);if(hit)return hit;}return null;}
        const firstDevice=findDevice(panel.contentArea);test.verify(!!firstDevice,"Populated input list missing");const devicePosition=firstDevice.mapToItem(panel.contentArea,0,0);test.verify(devicePosition.y>=0 && devicePosition.y+firstDevice.height<=panel.contentArea.height,"Hidden display loader displaced device list");test.capture("populated-device-transition",panel);
        panel.navigateId("overview");input.wait(50);
        panel.navigation.query="wallpaper";input.wait(50);test.verify(panel.navigation.rows.some(n=>n.id==="appearance/backgrounds"),"Global search synonym missing");test.capture("search-wallpaper",panel);
        panel.navigation.focusSearch();input.wait(30);input.keyClick(Qt.Key_Down);input.wait(30);input.keyClick(Qt.Key_Return);input.wait(40);test.verify(panel.routeId==="appearance/backgrounds","Keyboard search activation failed");
        panel.navigation.query="xyznotfound";input.wait(50);test.verify(panel.navigation.rows.length===0,"No-match search");test.capture("search-empty",panel);
        panel.navigation.focusSearch();input.keyClick(Qt.Key_Escape);input.wait(30);test.verify(panel.navigation.query==="","Escape did not clear search");
        test.width=390;input.wait(40);panel.navigationOpen=true;panel.navigation.query="wallpaper";input.wait(40);test.capture("search-drawer-390",panel);test.width=1120;input.wait(40);test.verify(panel.navigation.query==="wallpaper","Search lost across layout change");
        panel.navigation.query="";
        panel.navigateId("audio/overview/microphone");input.wait(80);
        let ancestor=test.activeFocusItem;while(ancestor && ancestor.objectName!=="control-microphone-volume")ancestor=ancestor.parent;
        test.verify(!!ancestor,"Search destination failed to focus microphone control");
        panel.navigateId("appearance/backgrounds");input.wait(80);
        function find(item,name){if(item.objectName===name)return item;for(const child of item.children){const result=find(child,name);if(result)return result;}return null;}
        const source=find(panel.contentArea,"backgroundSource");test.verify(!!source,"Appearance form missing");source.forceActiveFocus();input.keyClick(Qt.Key_A);input.wait(50);
        test.verify(!panel.navigateId("settings/idle"),"Dirty edits lost through navigation");test.verify(panel.routeId==="appearance/backgrounds","Dirty route changed");test.verify(panel.deferredNode==="settings/idle","Missing discard review");test.capture("appearance-navigation-review",panel);
        const discard=find(panel.contentArea,"control-discard-continue");test.verify(!!discard,"Discard review missing");discard.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(40);test.verify(panel.routeId==="settings/idle","Discard did not complete navigation");test.verify(!state.controlDraftDirty,"Draft guard remained active");panel.togglePin();test.verify(state.controlPins.includes("settings/idle"),"Session pin missing");panel.togglePin();test.verify(state.controlPins.length===0,"Session unpin failed");
        actions.actionState="pending";const reviewedRoute=panel.routeId;test.verify(!panel.navigateId("overview"),"Confirmation navigation must be blocked");input.wait(30);test.verify(test.mutations===0 && panel.routeId===reviewedRoute && actions.actionState==="pending","Rail/navigation canceled confirmation");actions.actionState="idle";
        if(test.mutations!==0){console.error("FAIL: navigating mutated provider");Qt.exit(1);return;}
        console.log("PASS: all nested destinations, search synonym/no-match, portrait focus, dirty-edit navigation review; no provider mutations");Qt.quit();
    }}
}
