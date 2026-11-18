import QtQuick
import QtQuick.Controls
import ".."
FocusScrollArea {
    id:root
    required property var audio
    function boundedGraph() {
        const graph=root.audio.graphSnapshot || {available:false,nodes:[],cards:[]};
        return {available:graph.available,generation:graph.generation || "",error:graph.error || "",canMove:graph.canMove,totalNodes:graph.nodes.length,totalCards:graph.cards.length,nodes:graph.nodes.slice(0,24).map(node=>Object.assign({},node,{routes:(node.routes || []).slice(0,16)})),cards:graph.cards.slice(0,4).map(card=>({id:card.id,name:card.name,profile:card.profile,activePorts:card.activePorts.slice(0,16),profiles:card.profiles.slice(0,8),totalProfiles:card.profiles.length,ports:card.ports.slice(0,8).map(port=>Object.assign({},port,{profiles:(port.profiles || []).slice(0,16)})),totalPorts:card.ports.length})),limits:{nodes:24,cards:4,profilesPerCard:8,portsPerCard:8}};
    }
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
        Row {
            width:parent.width;spacing:8
            AudioLabel {width:parent.width-audioMenu.width-8;anchors.verticalCenter:parent.verticalCenter;text:"AUDIO REPORT // BOUNDED LOCAL INVENTORY";color:"#ffffff"}
            ContextEvidenceMenu {id:audioMenu;accessibleLabel:"Audio diagnostic actions";copyLabel:"Copy audio diagnostics";textLabel:"Save audio diagnostics as text";componentKey:"audio-diagnostics";report:({timestamp:new Date().toISOString(),pipewireReady:root.audio.ready===true,output:root.audio.outputName,input:root.audio.inputName,outputVolume:root.audio.available?root.audio.volume:null,inputVolume:root.audio.inputAvailable?root.audio.inputVolume:null,outputMuted:root.audio.available?root.audio.muted:null,inputMuted:root.audio.inputAvailable?root.audio.inputMuted:null,graph:root.boundedGraph(),playbackCount:(root.audio.playbackStreams || []).length,recordingCount:(root.audio.recordingStreams || []).length})}
        }
        AudioLabel {width:parent.width;text:root.audio.ready===true?"PIPEWIRE // connected native provider":"PIPEWIRE // unavailable or starting"}
        AudioLabel {width:parent.width;text:"DEFAULT OUTPUT // "+root.audio.outputName}
        AudioLabel {width:parent.width;text:"DEFAULT INPUT // "+root.audio.inputName}
        AudioLabel {width:parent.width;text:root.audio.graphSnapshot && root.audio.graphSnapshot.available?"GRAPH ADAPTER // subscribed · "+root.audio.graphSnapshot.nodes.length+" audio nodes · "+root.audio.graphSnapshot.cards.length+" cards":"GRAPH ADAPTER // "+(root.audio.graphSnapshot?root.audio.graphSnapshot.error || "unavailable":"unavailable")}
        AudioLabel {width:parent.width;text:root.audio.graphSnapshot && root.audio.graphSnapshot.canMove?"STREAM MOVE // metadata endpoint available; provider policy may still reject a move":"STREAM MOVE // unavailable; native volume/mute can remain usable"}
        AudioLabel {width:parent.width;text:"A profile with no input disables microphone endpoints. An unlinked stream may be idle or awaiting a route. Default changes do not prove every running app has moved."}
        AudioLabel {width:parent.width;text:"If audio is unavailable, check the user PipeWire and WirePlumber services and device connection. This panel never restarts them automatically."}
        AudioLabel {width:parent.width;text:"Remembered app routes are opt-in suggestions, applied explicitly with confirmation. WirePlumber may also restore routes under its own policy. Senomy does not enable DSP. Equalization and noise suppression are optional future integrations."}
        AudioLabel {width:parent.width;text:"Reports exclude raw provider properties, process commands, environment variables and unrestricted logs. They include app/device labels and route identities; review before sharing."}
    }
}
