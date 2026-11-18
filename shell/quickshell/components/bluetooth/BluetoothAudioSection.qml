pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../audio" as Audio
import "../../config" as Config
Column {
 id:root
 required property var service
 required property var device
 property var audio:null
 signal audioRequested()
 function endpointMatches(node) {
  if(!device || !node || !node.properties)return false;
  const props=node.properties;
  if(props["api.bluez5.path"])return props["api.bluez5.path"]===device.id;
  const address=String(props["api.bluez5.address"] || "").toUpperCase();
  if(address)return address===device.address.toUpperCase() && (service.snapshot.devices || []).filter(item=>item.address.toUpperCase()===address).length===1;
  // Some nodes carry only device.id; the BlueZ identity lives on their card.
  // Require the existing graph's current node serial, not an endpoint name.
  const evidence=audio && typeof audio.graphNode==="function"?audio.graphNode(node):null;
  return !!card && !!evidence && String(evidence.deviceId)===String(card.id);
 }
 readonly property var outputs:audio&&device&&device.connected?audio.outputNodes.filter(endpointMatches):[]
 readonly property var inputs:audio&&device&&device.connected?audio.inputNodes.filter(endpointMatches):[]
 readonly property var matchingCards:!audio || !device || !device.connected || !audio.graphSnapshot?[]:(audio.graphSnapshot.cards || []).filter(item=>item.bluezPath===device.id || (!item.bluezPath && item.bluezAddress && item.bluezAddress.toUpperCase()===device.address.toUpperCase() && (service.snapshot.devices || []).filter(d=>d.address.toUpperCase()===device.address.toUpperCase()).length===1))
 readonly property var card:matchingCards.length===1?matchingCards[0]:null
 readonly property var profiles:card?card.profiles.filter(item=>item.available!=="no"):[]
 readonly property bool audioCapable:device && ((device.uuids || []).some(uuid=>["0000110b","0000111e","0000184e"].some(prefix=>uuid.startsWith(prefix))) || outputs.length>0 || !!card)
 spacing:8
 visible:audioCapable
                BluetoothLabel {text:"AUDIO";font.family:Config.DirectoryStyle.headingFont;color:Config.DirectoryStyle.ink}
                BluetoothLabel {
                    objectName:"bluetoothAudioState"
                    text:!root.device || !root.device.connected?"Connect this device before selecting its audio output.":root.outputs.length===0?"Bluetooth connected. Audio output is not yet available.":root.audio && root.outputs.indexOf(root.audio.sink)>=0?"Connected. Default output is "+root.device.name+".":"Connected. Current default output: "+(root.audio?root.audio.outputName:"unavailable")+"."
                }
                Repeater {
                    model:root.outputs
                    delegate:ControlWorkspaceButton {required property var modelData;objectName:"bluetoothOutput:"+modelData.id;width:root.width;text:root.audio.sink===modelData?"Current output: "+root.audio.nodeName(modelData):"Use output: "+root.audio.nodeName(modelData);enabled:root.audio.sink!==modelData && !root.audio.actionsLocked;onClicked:root.audio.selectOutput(modelData)}
                }
                Repeater {
                    model:root.inputs
                    delegate:ControlWorkspaceButton {required property var modelData;objectName:"bluetoothInput:"+modelData.id;width:root.width;text:root.audio.source===modelData?"Current microphone": "Use microphone: "+root.audio.nodeName(modelData);enabled:root.audio.source!==modelData && !root.audio.actionsLocked;onClicked:root.audio.selectInput(modelData)}
                }
                BluetoothLabel {visible:root.profiles.length===0;text:"No audio profiles are currently exposed for this device."}
                ShellComboBox {
                    objectName:"bluetoothAudioProfile";width:parent.width;visible:root.profiles.length>0
                    model:root.profiles.map(item=>({index:item.index,name:item.name+(item.available==="unknown"?" · availability unknown":"")}));textRole:"name"
                    currentIndex:root.card?root.profiles.findIndex(item=>item.index===root.card.profile):-1
                    enabled:!!root.card && root.card.canProfile && !root.audio.actionsLocked
                    Accessible.name:"Audio profile for "+(root.device?root.device.name:"")
                    onActivated:index=>{const item=root.profiles[index];root.audio.graphActions.request("profile",root.card,item.index,item.name);}
                }
                BluetoothLabel {visible:root.profiles.length>0;text:"Playback and microphone profiles can change audio quality and available endpoints. Only reported profiles are listed."}
                Loader {width:parent.width;active:!!root.audio;sourceComponent:Audio.AudioActionReview {audio:root.audio}}
                ControlWorkspaceButton {width:parent.width;text:"Open Audio Settings";headerControl:true;onClicked:root.audioRequested()}

}
