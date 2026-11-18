import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// PipeWire properties are subscribed to natively; no pactl polling process is
// retained in the Quickshell implementation.
Scope {
    id: root

    property var pipewire: Pipewire
    property bool adapterEnabled: true
    property bool persistenceEnabled: true
    property bool nativeProvider: true
    readonly property bool nativeMetering: nativeProvider
    readonly property bool ready: pipewire.ready
    property bool active: false
    property bool amplification: false
    property var preferences: ({schemaVersion:1,amplification:false,routes:[]})
    property string preferenceMessage: ""
    readonly property bool preferenceBusy: preferenceWriter.running || preferenceReader.running
    function setPreference(key,value) {
        if(key!=="amplification" || typeof value!=="boolean" || preferenceBusy || !persistenceEnabled)return false;
        preferenceMessage="Saving preference…";
        preferenceWriter.exec(["python3",Quickshell.shellDir+"/scripts/audio-preferences.py","save",JSON.stringify({schemaVersion:1,amplification:value,routes:preferences.routes || []})]);return true;
    }
    function appKey(node) {
        if(!liveNode(node) || !node.isStream)return "";
        const p=node.properties,key=p["application.id"]?"id:"+p["application.id"]:p["application.process.binary"]?"binary:"+p["application.process.binary"]:"";
        if(!key || key.length>180)return "";
        // Ambiguous binaries across differently named clients are not auto-grouped.
        if(streams.some(other=>other!==node && (other.properties["application.id"]?"id:"+other.properties["application.id"]:other.properties["application.process.binary"]?"binary:"+other.properties["application.process.binary"]:"")===key && appName(other)!==appName(node)))return "";
        return key;
    }
    function rememberedRoute(node) {
        const key=appKey(node);return key?(preferences.routes || []).find(rule=>rule.appKey===key && rule.direction===(node.isSink?"recording":"playback")) || null:null;
    }
    function rememberedEndpoint(node) {
        const rule=rememberedRoute(node);if(!rule)return null;
        const list=(node.isSink?inputNodes:outputNodes).filter(endpoint=>endpoint.name===rule.endpointName);
        return list.length===1?list[0]:null;
    }
    function saveRoute(node, endpoint, forget) {
        const key=appKey(node);if(!key || preferenceBusy || !persistenceEnabled || (!forget && (!liveNode(endpoint) || !endpoint.name)))return false;
        const direction=node.isSink?"recording":"playback";
        const list=(preferences.routes || []).filter(rule=>!(rule.appKey===key && rule.direction===direction));
        if(!forget)list.push({appKey:key,direction:direction,endpointName:endpoint.name});
        if(list.length>32){preferenceMessage="Remembered route limit reached; forget an unused route first";return false;}
        preferenceWriter.exec(["python3",Quickshell.shellDir+"/scripts/audio-preferences.py","save",JSON.stringify({schemaVersion:1,amplification:amplification,routes:list})]);return true;
    }
    function forgetRule(rule) {
        if(!persistenceEnabled || preferenceBusy || !rule || !(preferences.routes || []).some(x=>x.appKey===rule.appKey && x.direction===rule.direction && x.endpointName===rule.endpointName))return false;
        const list=preferences.routes.filter(x=>!(x.appKey===rule.appKey && x.direction===rule.direction));
        preferenceWriter.exec(["python3",Quickshell.shellDir+"/scripts/audio-preferences.py","save",JSON.stringify({schemaVersion:1,amplification:amplification,routes:list})]);return true;
    }
    Process {
        id:preferenceReader;command:["python3",Quickshell.shellDir+"/scripts/audio-preferences.py","read"];running:root.persistenceEnabled
        stdout:StdioCollector {id:preferenceInput}
        onExited:(code,status)=>{try{const result=JSON.parse(preferenceInput.text);root.preferences=result.preferences;root.amplification=result.preferences.amplification;root.preferenceMessage=result.ok?"":result.message;}catch(e){root.preferenceMessage="Audio preferences unavailable; using safe defaults";}}
    }
    Process {
        id:preferenceWriter;stdout:StdioCollector {id:preferenceOutput}
        onExited:(code,status)=>{try{const result=JSON.parse(preferenceOutput.text);if(result.ok){root.preferences=result.preferences;root.amplification=result.preferences.amplification;}root.preferenceMessage=result.ok?"Audio preference saved":result.message;}catch(e){root.preferenceMessage="Audio preference was not saved";}}
    }
    readonly property real volumeLimit: amplification ? 1.5 : 1.0
    property var graphSnapshot: ({available:false,nodes:[],cards:[],canMove:false,error:"Waiting for audio inventory"})
    property string graphInterpreter: "python3"
    property string graphHelper: Quickshell.shellDir + "/scripts/audio-graph.py"
    property int graphRetryBaseMs: 1000
    property int graphRetryLimit: 5
    property int graphFailures: 0
    property bool graphStarting: false
    property bool graphStarted: false
    property bool graphWritePending: false
    property bool graphWriteStarted: false
    readonly property bool graphWanted: active && adapterEnabled && ready
    readonly property bool graphRetryScheduled: graphRetry.running
    readonly property bool graphCanRetry: graphWanted && !graphStarting && !graphReader.running && !graphWritePending && !advancedActions.locked
    function unavailableGraph(reason) {
        graphSnapshot = {available:false,nodes:[],cards:[],canMove:false,error:reason};
    }
    function startGraph() {
        if (!graphWanted || graphReader.running || graphStarting) return false;
        graphStarting = true; graphStarted = false;
        unavailableGraph("Loading audio inventory…");
        graphReader.exec([graphInterpreter,graphHelper,"watch"]); return true;
    }
    function graphStopped(reason) {
        graphStarting = false;
        if (!graphWanted) { unavailableGraph("Open Audio or Bluetooth to inspect audio devices."); return; }
        graphFailures++;
        const retry = graphFailures <= graphRetryLimit;
        unavailableGraph(reason + (retry ? " Retrying inventory…" : " Automatic retries paused; choose Retry inventory."));
        if (retry) graphRetry.restart();
    }
    function retryGraph() {
        if (!graphWanted || graphStarting || graphReader.running || graphWritePending || advancedActions.locked) return false;
        graphRetry.stop(); graphFailures = 0; return startGraph();
    }
    onGraphWantedChanged: {
        graphRetry.stop();
        if (graphWanted) { graphFailures = 0; startGraph(); }
        else { graphStarting = false; graphReader.running = false; unavailableGraph("Audio inventory is inactive or PipeWire is unavailable."); }
    }
    Component.onCompleted: if (graphWanted) startGraph()
    Timer {
        id: graphRetry
        interval: Math.min(30000, root.graphRetryBaseMs * Math.pow(2,Math.max(0,root.graphFailures-1)))
        onTriggered: root.startGraph()
    }
    Timer {
        interval: 10000
        running: root.graphWanted && graphReader.running && root.graphSnapshot.available === true
        onTriggered: root.graphFailures = 0 // only a stable subscription resets the failure budget
    }
    Timer {
        interval: 200
        running: root.graphStarting && !root.graphStarted && !graphReader.running
        onTriggered: root.graphStopped("Audio inventory adapter could not start. Check Python and the helper installation.")
    }
    Timer {
        interval: 200
        running: root.graphWritePending && !root.graphWriteStarted && !graphWriter.running
        onTriggered: {
            root.graphWritePending = false;
            advancedActions.finish(false,"Audio adapter could not start. No request was submitted; check Python and refresh inventory.");
        }
    }
    property alias graphActions: advancedActions
    readonly property bool actionsLocked: selectionGuard.locked || advancedActions.locked || graphWritePending
    readonly property var nodes: pipewire.nodes.values
    readonly property var sink: pipewire.defaultAudioSink
    readonly property var source: pipewire.defaultAudioSource
    readonly property bool available: ready && sink !== null && sink.ready && sink.audio !== null
    readonly property bool inputAvailable: ready && source !== null && source.ready && source.audio !== null
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property bool muted: available ? sink.audio.muted : false
    readonly property real inputVolume: inputAvailable ? source.audio.volume : 0
    readonly property bool inputMuted: inputAvailable ? source.audio.muted : false
    readonly property var outputNodes: nodes.filter(node => node.ready && node.audio !== null
        && node.isSink && !node.isStream)
    readonly property var inputNodes: nodes.filter(node => node.ready && node.audio !== null
        && !node.isStream && (node.type & PwNodeType.AudioSource) === PwNodeType.AudioSource)
    readonly property var playbackStreams: nodes.filter(node => node.ready && node.audio !== null && node.isStream && !node.isSink)
    readonly property var recordingStreams: nodes.filter(node => node.ready && node.audio !== null && node.isStream && node.isSink)
    readonly property var streams: playbackStreams.concat(recordingStreams)
    readonly property int recordingCount: recordingStreams.filter(node => pipewire.linkGroups.values.some(link => link.target === node && link.state === PwLinkState.Active)).length
    function nodeName(node) { return node ? node.description || node.nickname || node.name || "Audio endpoint" : "Unavailable"; }
    function appName(node) { const p=node ? node.properties : {};return p["application.name"] || p["application.process.binary"] || nodeName(node); }
    function routes(node) {
        return pipewire.linkGroups.values.filter(link => link.source === node || link.target === node).map(link => link.source === node ? link.target : link.source).filter(x => x && !x.isStream);
    }
    function routeName(node) { const list=routes(node); return list.length ? list.map(nodeName).join(" / ") : "No linked endpoint"; }
    function liveNode(node) { return ready && node && node.ready && node.audio && nodes.indexOf(node)>=0; }
    function setNodeVolume(node,value) { if(!liveNode(node) || !Number.isFinite(value))return false;node.audio.volume=Math.max(0,Math.min(volumeLimit,value));return true; }
    function toggleNodeMuted(node) { if(!liveNode(node))return false;node.audio.muted=!node.audio.muted;return true; }
    function stereo(node) { return liveNode(node) && node.audio.channels.indexOf(PwAudioChannel.FrontLeft)>=0 && node.audio.channels.indexOf(PwAudioChannel.FrontRight)>=0; }
    function balance(node) {
        if(!stereo(node))return 0;
        const v=node.audio.volumes, l=v[node.audio.channels.indexOf(PwAudioChannel.FrontLeft)], r=v[node.audio.channels.indexOf(PwAudioChannel.FrontRight)];
        return Math.max(l,r)>0 ? (r-l)/Math.max(l,r) : 0;
    }
    function setBalance(node,value) {
        if(!stereo(node) || !Number.isFinite(value))return false;
        value=Math.max(-1,Math.min(1,value)); const v=node.audio.volumes.slice(), l=node.audio.channels.indexOf(PwAudioChannel.FrontLeft),r=node.audio.channels.indexOf(PwAudioChannel.FrontRight);
        const level=Math.min(volumeLimit,Math.max(v[l],v[r]));v[l]=level*(value>0?1-value:1);v[r]=level*(value<0?1+value:1);node.audio.volumes=v;return true;
    }
    function graphNode(node) { if(!liveNode(node))return null;const serial=node.properties["object.serial"];return serial===undefined?null:graphSnapshot.nodes.find(x => x.id===node.id && x.serial===String(serial)) || null; }
    function requestMove(node,target) { if(!liveNode(node) || !liveNode(target) || !node.isStream || target.isStream)return false;const linked=routes(node);if(linked.length===1 && linked[0]===target)return false;const stream=graphNode(node), endpoint=graphNode(target);return !!stream && !!endpoint && advancedActions.request("move",stream,endpoint.token,nodeName(target)); }
    function applyGraphRequest(request) {
        if(!adapterEnabled || advancedActions.actionState!=="running" || !advancedActions.valid() || graphWriter.running || graphWritePending)return false;
        graphWritePending = true; graphWriteStarted = false;
        graphWriter.exec([graphInterpreter,graphHelper,"apply",JSON.stringify(request)]);return true;
    }
    AudioGraphActions { id:advancedActions;provider:root;context:root.actionContext }
    onGraphSnapshotChanged: advancedActions.revalidate()
    onReadyChanged: advancedActions.revalidate()
    Process {
        id:graphReader
        stdout:SplitParser {
            onRead:data=>{
                try {
                    const value = JSON.parse(data);
                    if (value.available === true && Array.isArray(value.nodes) && Array.isArray(value.cards)) root.graphSnapshot = value;
                    else root.unavailableGraph(value.error || value.message || "Audio inventory is unavailable.");
                } catch(e) { root.unavailableGraph("Audio inventory returned an unreadable response."); }
            }
        }
        onStarted: { root.graphStarted = true; root.graphStarting = false; if (!root.graphWanted) running = false; }
        onExited: root.graphStopped("Audio inventory subscription ended.")
    }
    Process {
        id:graphWriter
        onStarted: root.graphWriteStarted = true
        stdout:StdioCollector { id:graphOutput }
        onExited:(code,status)=>{
            root.graphWritePending = false;
            try {
                const result = JSON.parse(graphOutput.text), ok = code === 0 && result.ok === true;
                advancedActions.finish(ok, ok ? result.message : result.error || (result.ok === true ? "Audio adapter exited unsuccessfully; inspect the current route before retrying." : result.message) || "Audio operation failed");
            } catch(e) { advancedActions.finish(false,"Audio operation returned no verified result; inspect the current route before retrying."); }
        }
    }
    readonly property string outputName: available
        ? (sink.description || sink.nickname || sink.name || "Default output") : "Unavailable"
    readonly property string inputName: inputAvailable
        ? (source.description || source.nickname || source.name || "Default input") : "Unavailable"
    readonly property string label: !available ? "N/A" : muted ? "MUTED" : Math.round(volume * 100) + "%"

    function toggleMuted() {
        return toggleNodeMuted(sink);
    }

    function setVolume(value) {
        if (!available)
            return false;
        return setNodeVolume(sink,value);
    }

    function toggleInputMuted() {
        return toggleNodeMuted(source);
    }

    function setInputVolume(value) {
        if (!inputAvailable)
            return false;
        return setNodeVolume(source,value);
    }

    readonly property var selectionBackend: pipewire
    property string actionContext: ""
    property alias selectionActions: selectionGuard
    SelectionActions { id: selectionGuard; provider: root; context: root.actionContext }

    function selectionAvailable(kind) {
        return pipewire.ready && (kind === "output" || kind === "input");
    }
    function selectionOptions(kind) {
        return kind === "output" ? outputNodes : kind === "input" ? inputNodes : [];
    }
    function selectionCurrent(kind) { return kind === "output" ? sink : kind === "input" ? source : null; }
    function selectionLabel(kind, node) {
        return (kind === "input" ? "Input: " : "Output: ")
            + (node ? node.description || node.nickname || node.name || "Audio endpoint" : "No default");
    }
    function selectionImpact(kind) {
        return kind === "input"
            ? "Change the default microphone/input. Recording and calls may use a different device. Choose the previous input to switch back."
            : "Change the default audio output. Playback and calls may move to another device. Choose the previous output to switch back.";
    }
    function applySelection(kind, node) {
        if (selectionGuard.actionState !== "running" || selectionGuard.kind !== kind
                || selectionGuard.target !== node || !selectionGuard.valid()) return false;
        if (kind === "output") pipewire.preferredDefaultAudioSink = node;
        else if (kind === "input") pipewire.preferredDefaultAudioSource = node;
        else return false;
        return true;
    }
    function selectOutput(node) { if(advancedActions.locked)return false;return selectionGuard.request("output", node); }
    function selectInput(node) { if(advancedActions.locked)return false;return selectionGuard.request("input", node); }

    Loader {
        active: root.nativeProvider
        sourceComponent: Component {
            PwObjectTracker { objects: [root.sink, root.source].concat(root.nodes.filter(node=>node.audio!==null && (!node.isStream || root.active))).filter(node => node !== null) }
        }
    }
}
