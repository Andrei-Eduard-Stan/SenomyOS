import Quickshell
import Quickshell.Services.Pipewire

// PipeWire properties are subscribed to natively; no pactl polling process is
// retained in the Quickshell implementation.
Scope {
    id: root

    readonly property var nodes: Pipewire.nodes.values
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool available: sink !== null && sink.audio !== null
    readonly property bool inputAvailable: source !== null && source.audio !== null
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property bool muted: available ? sink.audio.muted : false
    readonly property real inputVolume: inputAvailable ? source.audio.volume : 0
    readonly property bool inputMuted: inputAvailable ? source.audio.muted : false
    readonly property var outputNodes: nodes.filter(node => node.ready && node.audio !== null
        && node.isSink && !node.isStream)
    readonly property var inputNodes: nodes.filter(node => node.ready && node.audio !== null
        && !node.isStream && (node.type & PwNodeType.AudioSource))
    readonly property string outputName: available
        ? (sink.description || sink.nickname || sink.name || "Default output") : "Unavailable"
    readonly property string inputName: inputAvailable
        ? (source.description || source.nickname || source.name || "Default input") : "Unavailable"
    readonly property string label: !available ? "N/A" : muted ? "MUTED" : Math.round(volume * 100) + "%"

    function toggleMuted() {
        if (available)
            sink.audio.muted = !sink.audio.muted;
    }

    function setVolume(value) {
        if (!available)
            return false;
        sink.audio.volume = Math.max(0, Math.min(1, value));
        return true;
    }

    function toggleInputMuted() {
        if (!inputAvailable)
            return false;
        source.audio.muted = !source.audio.muted;
        return true;
    }

    function setInputVolume(value) {
        if (!inputAvailable)
            return false;
        source.audio.volume = Math.max(0, Math.min(1, value));
        return true;
    }

    function selectOutput(node) {
        if (!node || !node.audio)
            return false;
        Pipewire.preferredDefaultAudioSink = node;
        return true;
    }

    function selectInput(node) {
        if (!node || !node.audio)
            return false;
        Pipewire.preferredDefaultAudioSource = node;
        return true;
    }

    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.outputNodes, root.inputNodes).filter(node => node !== null)
    }
}
