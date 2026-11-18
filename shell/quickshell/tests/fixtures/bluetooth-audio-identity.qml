import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "services"
import "components/bluetooth"
Scope {
 id:test
 QtObject {id:gain;property real volume:.5;property bool muted:false;property var channels:[];property var volumes:[]}
 QtObject {id:output;property int id:2;property string name:"fixture-output";property string description:"Output";property bool ready:true;property bool isSink:true;property bool isStream:false;property int type:PwNodeType.AudioSink;property var audio:gain;property var properties:({"object.serial":2,"device.id":8})}
 QtObject {id:input;property int id:3;property string name:"fixture-input";property string description:"Input";property bool ready:true;property bool isSink:false;property bool isStream:false;property int type:PwNodeType.AudioSource;property var audio:gain;property var properties:({"object.serial":3,"device.id":8})}
 QtObject {id:pipe;property bool ready:true;property var nodes:({values:[output,input]});property var linkGroups:({values:[]});property var defaultAudioSink:output;property var defaultAudioSource:input}
 property var device:({id:"/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF",address:"AA:BB:CC:DD:EE:FF",name:"Fixture headset",connected:true,uuids:[]})
 property var card:({id:8,token:"fixture:card",revision:"one",bluezPath:device.id,canProfile:true,profile:0,profiles:[]})
 QtObject {id:service;property var snapshot:({devices:[test.device]})}
 AudioService {id:audio;pipewire:pipe;nativeProvider:false;adapterEnabled:false;persistenceEnabled:false;graphSnapshot:({available:true,cards:[test.card],nodes:[{id:2,serial:"2",deviceId:8},{id:3,serial:"3",deviceId:8}]})}
 BluetoothAudioSection {id:section;width:500;service:service;audio:audio;device:test.device}
 function check(ok,why){if(!ok)throw new Error(why);}
 Timer {interval:100;running:true;onTriggered:{try{
  check(section.outputs.length===1&&section.inputs.length===1,"card-only BlueZ identity associates output and microphone");
  audio.graphSnapshot=({available:true,cards:[test.card],nodes:[{id:2,serial:"999",deviceId:8},{id:3,serial:"3",deviceId:8}]});check(section.outputs.length===0&&section.inputs.length===1,"reused node ID rejected by serial");
  audio.graphSnapshot=({available:true,cards:[test.card,Object.assign({},test.card,{id:9})],nodes:[{id:2,serial:"2",deviceId:8},{id:3,serial:"3",deviceId:8}]});check(!section.card&&section.outputs.length===0,"ambiguous card cannot acquire node linkage");
  audio.graphSnapshot=({available:true,cards:[test.card],nodes:[{id:2,serial:"2",deviceId:8},{id:3,serial:"3",deviceId:8}]});output.properties=({"object.serial":2,"api.bluez5.path":"/org/bluez/hci1/other"});check(section.outputs.length===0,"explicit different identity wins over fallback");
  console.log("PASS: Bluetooth audio card-linked output/microphone matching, stale serial and ambiguous/foreign identity refusal; no physical routes changed");Qt.quit();
 }catch(e){console.error("FAIL: "+e.message+" "+e.stack);Qt.exit(1);}}}
}
