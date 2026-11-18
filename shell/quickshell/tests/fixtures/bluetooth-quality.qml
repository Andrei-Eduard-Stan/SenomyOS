import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "services"
import "components/bluetooth"
import "components"
import "config" as Config
Window {
    id:test;visible:true;width:1000;height:730;color:"#080a0c"
    property var writes:[]
    TestCase {id:keys;when:false}
    BluetoothService {id:service;transportEnabled:false;actionContext:"fixture";onTestRequest:request=>test.writes.push(request)}
    QtObject {id:gain;property real volume:0.5;property bool muted:false;property var channels:[];property var volumes:[]}
    QtObject {id:builtIn;property int id:1;property string name:"builtin";property string description:"Built-in Audio";property bool ready:true;property bool isSink:true;property bool isStream:false;property int type:1;property var audio:gain;property var properties:({"object.serial":1})}
    QtObject {id:earOutput;property int id:2;property string name:"bluez_output";property string description:"CMF Buds Pro 2";property bool ready:true;property bool isSink:true;property bool isStream:false;property int type:1;property var audio:gain;property var properties:({"api.bluez5.path":"/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF","object.serial":2})}
    QtObject {id:pipe;property bool ready:true;property var nodes:({values:[builtIn,earOutput]});property var linkGroups:({values:[]});property var defaultAudioSink:builtIn;property var defaultAudioSource:null;property var preferredDefaultAudioSink:builtIn;property var preferredDefaultAudioSource:null}
    AudioService {id:audio;pipewire:pipe;nativeProvider:false;adapterEnabled:false;persistenceEnabled:false;actionContext:"bluetooth:fixture";
        graphSnapshot:({available:true,error:"",nodes:[],cards:[{id:8,token:"card",revision:"one",bluezPath:"/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF",name:"CMF Buds Pro 2",canProfile:true,profile:0,profiles:[{index:0,name:"High quality stereo (SBC)",available:"yes"},{index:1,name:"Headset with microphone",available:"unknown"}]}]})
    }
    BluetoothPopup {id:popup;bluetooth:service;visible:false;width:implicitWidth;height:implicitHeight;x:20;y:20;onOpenSettingsRequested:test.settingsRequests++}
    property int settingsRequests:0
    BluetoothPage {id:page;audio:audio;x:24;y:24;width:parent.width-48;height:parent.height-48;service:service;full:true}
    property var adapter:({id:"/org/bluez/hci0",token:"a1",name:"Bluetooth adapter",powered:true,powerState:"on",discovering:false,discoverable:false,pairable:false,expected:{Powered:true,Discoverable:false,Pairable:false}})
    property var earbuds:({id:"/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF",token:"d1",adapter:"/org/bluez/hci0",address:"AA:BB:CC:DD:EE:FF",name:"CMF Buds Pro 2",deviceName:"CMF Buds Pro 2",icon:"audio-headset",identified:true,paired:true,bonded:true,connected:false,trusted:true,blocked:false,servicesResolved:false,wakeAllowed:true,class:2360324,appearance:0,modalias:"bluetooth:v02B0p0000d001F",legacyPairing:false,lastObservedAt:null,rssi:null,txPower:null,reconnectMode:null,interfaces:["org.bluez.Device1"],battery:null,recent:false,group:"paired",uuids:["0000110b-0000-1000-8000-00805f9b34fb"],expected:{Paired:true,Connected:false,Trusted:true,Blocked:false,Alias:"CMF Buds Pro 2"}})
    function setup(operation) {
        service.snapshot={available:true,error:"",adapters:[adapter],devices:[earbuds],operations:operation?{[earbuds.id]:operation}:{},scan:{state:"idle",owned:false,message:""},prompt:null};
    }
    function check(value,message){if(!value){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
    function named(name){const item=keys.findChild(page,name);check(!!item,"control "+name);return item;}
    function press(name){const item=named(name);item.forceActiveFocus();keys.keyClick(Qt.Key_Return);keys.wait(80);}
    function capture(name){let done=false;page.grabToImage(result=>{check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"save capture");done=true;});while(!done)keys.wait(20);}
    Timer {
        interval:150;running:true
        onTriggered:{
            test.setup(null);keys.wait(150);
            test.press("bluetoothDetails:"+test.earbuds.id);test.check(test.writes.length===0,"details do not connect");
            test.check(service.selectedDevice.id===test.earbuds.id,"select exact device");test.capture("02-reference-paired");
            test.press("bluetoothPrimary:"+test.earbuds.id);test.check(test.writes.length===1 && test.writes[0].action==="connect","Connect reaches service once");
            test.setup({id:"1",path:test.earbuds.id,token:"d1",action:"connect",phase:"running",message:"Connecting…",errorName:"",errorDetail:""});keys.wait(100);test.capture("03-reference-connecting");
            test.press("bluetoothPrimary:"+test.earbuds.id);test.check(test.writes[1].command==="cancel" && test.writes[1].id==="1","Cancel targets running request");
            test.setup({id:"1",path:test.earbuds.id,token:"d1",action:"connect",phase:"failed",message:"The device did not answer the Bluetooth connection request. Check that it is awake and nearby, and whether another host is using it.",errorName:"org.bluez.Error.Failed",errorDetail:"br-connection-page-timeout"});keys.wait(100);test.capture("04-reference-failed");
            test.press("bluetoothInspectorClose");test.check(!service.selectedDevice,"details close after failure");
            test.press("bluetoothPrimary:"+test.earbuds.id);test.check(test.writes[2].action==="connect","retry without recreating service");
            test.setup({id:"2",path:test.earbuds.id,token:"d1",action:"connect",phase:"cancelling",message:"Cancelling; waiting for BlueZ…",errorName:"",errorDetail:""});
            service.selectDevice(test.earbuds);keys.wait(80);test.capture("05-cancelling");
            const row=test.named("bluetoothPrimary:"+test.earbuds.id);test.check(!row.enabled,"Cancel cannot dispatch repeatedly during cleanup");
            test.press("bluetoothInspectorClose");test.check(!service.selectedDeviceId,"close while connecting remains possible");
            test.earbuds=Object.assign({},test.earbuds,{connected:true,group:"connected",servicesResolved:true,battery:73,expected:{Paired:true,Connected:true,Trusted:true,Blocked:false,Alias:"CMF Buds Pro 2"}});test.setup(null);service.selectDevice(test.earbuds);keys.wait(100);test.capture("06-connected-audio-not-default");
            test.check(test.named("bluetoothAudioState").text.indexOf("Built-in Audio")>=0,"connected differs from active audio output");
            test.press("bluetoothOutput:2");test.check(audio.selectionActions.actionState==="pending","audio route retains confirmation");test.check(pipe.preferredDefaultAudioSink===builtIn,"preview makes no audio change");
            audio.selectionActions.confirm();test.check(pipe.preferredDefaultAudioSink===earOutput,"confirm writes exact native endpoint");pipe.defaultAudioSink=earOutput;audio.selectionActions.observe();keys.wait(100);
            test.check(test.named("bluetoothAudioState").text.indexOf("Default output is CMF")>=0,"default output is observed");test.capture("07-connected-audio-default");
            const combo=test.named("bluetoothAudioProfile");combo.forceActiveFocus();keys.keyClick(Qt.Key_Space);keys.keyClick(Qt.Key_Down);keys.keyClick(Qt.Key_Return);keys.wait(60);test.check(audio.graphActions.actionState==="pending","reported profile reaches existing review");audio.graphActions.cancel();
            test.press("bluetoothTab:details");keys.wait(80);const primaryBefore=test.named("bluetoothPrimary:"+test.earbuds.id);test.setup(null);keys.wait(80);test.check(primaryBefore===test.named("bluetoothPrimary:"+test.earbuds.id),"state events preserve device controls");test.check(test.named("bluetoothTab:details").active,"state events preserve inspector view");
            test.press("bluetoothTab:overview");
            test.press("bluetoothTab:manage");keys.wait(80);test.capture("16-device-management");
            const alias=test.named("bluetoothAlias");alias.forceActiveFocus();keys.keyClick(Qt.Key_A,Qt.ControlModifier);for(const key of [Qt.Key_S,Qt.Key_T,Qt.Key_U,Qt.Key_D,Qt.Key_I,Qt.Key_O])keys.keyClick(key);keys.wait(60);
            test.check(alias.text==="studio","name editing uses keyboard input");test.setup(null);keys.wait(60);test.check(alias.text==="studio","live state preserves unsaved alias draft");
            test.press("bluetoothSaveAlias");test.check(service.actions.actionState==="pending" && service.actions.requestData.value==="studio","rename captures reviewed alias");service.actions.cancel();
            for(const control of ["bluetoothTrust","bluetoothBlock","bluetoothWake","bluetoothForget"]){const count=test.writes.length;test.press(control);test.check(service.actions.actionState==="pending","management action requires review");service.actions.cancel();test.check(test.writes.length===count,"cancelled management does not write");}
            test.press("bluetoothTab:details");test.named("bluetoothPropertySearch").text="trusted";keys.wait(60);test.capture("17-properties-filtered");test.named("bluetoothPropertySearch").text="";
            test.check(!JSON.stringify(service.deviceReport(test.earbuds,false)).includes(test.earbuds.address),"diagnostic report hides full address");test.check(JSON.stringify(service.deviceReport(test.earbuds,true)).includes(test.earbuds.address),"report identifiers are explicit opt-in");
            const reportMenu=test.named("context-menu-trigger").parent;test.check(reportMenu.actions.every(a=>a.id!=="snapshot"),"device diagnostics never offer identifying snapshots");test.check(!reportMenu.invoke("snapshot") && !reportMenu.busy,"unknown snapshot action cannot run");
            test.capture("18-properties-and-services");
            test.setup({id:"redaction",token:"d1",action:"connect",phase:"failed",message:"Error for AA:BB:CC:DD:EE:FF",errorName:"org.bluez.Error.Failed",errorDetail:"/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"});keys.wait(50);
            const privateReport=JSON.stringify(service.deviceReport(test.earbuds,false));test.check(!privateReport.includes("AA:BB:CC:DD:EE:FF") && !privateReport.includes("dev_AA_BB_CC_DD_EE_FF"),"backend errors are redacted in copied report");test.setup(null);test.press("bluetoothTab:overview");
            const other=Object.assign({},test.earbuds,{id:"/org/bluez/hci0/dev_11_22_33_44_55_66",token:"d2",address:"11:22:33:44:55:66",paired:false,bonded:false,connected:false,battery:null,recent:true,group:"nearby"});
            service.snapshot=Object.assign({},service.snapshot,{devices:[test.earbuds,other]});keys.wait(80);test.capture("19-same-name-identities");test.check(test.named("bluetoothIdentity:"+test.earbuds.id).visible,"same names show distinguishing identity");
            test.press("bluetoothCompare:"+other.id);test.check(service.selectedDevice.id===other.id,"comparison selects exact alternate identity without pairing it");
            test.press("bluetoothTab:manage");test.check(test.named("bluetoothForget").text.indexOf("Remove discovery")===0,"unpaired cache removal differs from forgetting a pairing");
            test.press("bluetoothForget");test.check(service.actions.requestData.action==="remove","unpaired removal is an exact reviewed action");service.actions.cancel();
            test.setup(null);service.selectDevice(test.earbuds);test.press("bluetoothTab:overview");
            service.snapshot=Object.assign({},service.snapshot,{prompt:{id:"auth1",path:test.earbuds.id,name:"Bluetooth keyboard",kind:"RequestConfirmation",code:"123456",entered:0}});keys.wait(100);test.capture("08-pairing-confirmation");test.press("bluetoothPairingReject");test.check(test.writes[test.writes.length-1].command==="answer" && !test.writes[test.writes.length-1].accept,"authentication requires explicit decision");
            test.setup(null);service.selectDevice(null);test.earbuds=Object.assign({},test.earbuds,{connected:false,group:"paired",battery:null});test.adapter=Object.assign({},test.adapter,{powered:false,powerState:"off"});test.setup(null);keys.wait(100);test.capture("09-disabled");test.press("bluetoothDetails:"+test.earbuds.id);test.press("bluetoothTab:manage");test.check(test.named("bluetoothForget").enabled,"saved records remain manageable while radio is off");test.capture("20-radio-off-management");service.selectDevice(null);
            test.adapter=Object.assign({},test.adapter,{powered:true,powerState:"on"});test.setup(null);service.snapshot=Object.assign({},service.snapshot,{devices:[]});keys.wait(100);test.capture("10-enabled-empty");
            test.setup(null);service.snapshot=Object.assign({},service.snapshot,{scan:{state:"running",owned:true,message:"Scanning for devices · stops after 30 seconds"}});keys.wait(80);test.capture("11-scanning");
            test.setup(null);test.width=460;test.height=740;service.selectDevice(test.earbuds);keys.wait(100);test.check(!page.split,"narrow layout uses one region");test.capture("12-narrow-inspector");test.press("bluetoothInspectorClose");test.capture("13-narrow-list");
            Config.DirectoryStyle.touchMode=true;test.width=428;keys.wait(100);test.check(test.named("bluetoothPrimary:"+test.earbuds.id).height>=44,"touch target");test.capture("14-touch-list");
            Config.DirectoryStyle.touchMode=false;test.width=1000;page.visible=false;popup.visible=true;keys.wait(100);let done=false;popup.grabToImage(result=>{test.check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/15-quick-popover.png"),"popup capture");done=true;});while(!done)keys.wait(20);
            console.log("PASS: Bluetooth row, inspector, cancel, retry, audio identity/default/profile review, auth, stable controls, narrow/touch and quick layout; fake devices only");Qt.quit();
        }
    }
}
