import QtQuick
import QtQuick.Controls
import ".."
FocusScrollArea {
    id:root
    required property var audio
    signal deviceManagementRequested()
    width:parent.width;height:parent.height;contentHeight:body.implicitHeight
    ScrollBar.vertical:ShellScrollBar {}
    Column {
        id:body;width:parent.width;spacing:12
        DashboardButton {
            objectName: "audio-inventory-retry"; text: "RETRY INVENTORY"
            visible: typeof root.audio.retryGraph === "function" && (!root.audio.graphSnapshot || !root.audio.graphSnapshot.available)
            enabled: visible && root.audio.graphCanRetry === true
            onClicked: root.audio.retryGraph()
        }
        AudioLabel {width:parent.width;text:"OUTPUT DEVICES";font.pixelSize:14;color:"#ffffff"}
        AudioLabel {width:parent.width;visible:root.audio.outputNodes.length===0;text:"No output endpoints available"}
        Repeater {model:root.audio.outputNodes;delegate:AudioEndpointRow {required property var modelData;audio:root.audio;node:modelData;detailed:true}}
        AudioLabel {width:parent.width;text:"INPUT DEVICES";font.pixelSize:14;color:"#ffffff"}
        AudioLabel {width:parent.width;visible:root.audio.inputNodes.length===0;text:"No input endpoints available"}
        Repeater {model:root.audio.inputNodes;delegate:AudioEndpointRow {required property var modelData;audio:root.audio;node:modelData;input:true;detailed:true}}
        AudioLabel {width:parent.width;text:"CARD PROFILES & PORTS";font.pixelSize:14;color:"#ffffff"}
        AudioLabel {width:parent.width;visible:!root.audio.graphSnapshot || !root.audio.graphSnapshot.available;text:root.audio.graphSnapshot?root.audio.graphSnapshot.error || "Card inventory unavailable":"Card inventory unavailable"}
        Repeater {
            model:root.audio.graphSnapshot?root.audio.graphSnapshot.cards || []:[]
            delegate:Column {
                id:card;required property var modelData;width:body.width;spacing:8
                readonly property var supportedProfiles:modelData.profiles.filter(x=>x.available!=="no").map(x=>Object.assign({},x,{name:x.name+(x.available==="unknown"?" · availability unknown":"")}))
                readonly property var supportedPorts:modelData.ports.filter(x=>x.available!=="no" && (!x.profiles.length || x.profiles.indexOf(modelData.profile)>=0))
                AudioLabel {width:parent.width;text:card.modelData.name;color:"#ffffff"}
                AudioLabel {width:parent.width;text:"PROFILE · changing this can remove endpoints and interrupt calls"}
                ShellComboBox {width:parent.width;model:card.supportedProfiles;textRole:"name";enabled:card.modelData.canProfile && !root.audio.actionsLocked;currentIndex:card.supportedProfiles.findIndex(x=>x.index===card.modelData.profile);Accessible.name:"Card profile for "+card.modelData.name;onActivated:index=>{const target=card.supportedProfiles[index];root.audio.graphActions.request("profile",card.modelData,target.index,target.name);}}
                AudioLabel {width:parent.width;text:"PORTS · unavailable ports are excluded; unknown availability remains explicit"}
                Repeater {
                    model:card.supportedPorts
                    delegate:DashboardButton {required property var modelData;width:card.width;text:modelData.name;detail:modelData.direction+" · "+modelData.available+" availability"+(modelData.nodeToken?"":" · no unambiguous endpoint");active:card.modelData.activePorts.some(x=>x.index===modelData.index);enabled:card.modelData.canPort && !!modelData.nodeToken && !active && !root.audio.actionsLocked;onClicked:root.audio.graphActions.request("port",card.modelData,modelData.index,modelData.name)}
                }
                AudioLabel {width:parent.width;visible:card.supportedPorts.length===0;text:"No ports exposed for this profile"}
                Rectangle {width:parent.width;height:1;color:"#28ffffff"}
            }
        }
        DashboardButton {width:parent.width;text:"BLUETOOTH / DEVICE MANAGEMENT ›";onClicked:root.deviceManagementRequested()}
        AudioLabel {width:parent.width;text:"Bluetooth profiles depend on the connected device. Playback-only profiles may disable its microphone; duplex profiles may change sound quality. No codec or latency guarantee is inferred."}
    }
}
