import Quickshell
import Quickshell.Services.Pipewire

// PipeWire properties are subscribed to natively; no pactl polling process is
// retained in the Quickshell implementation.
Scope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: sink !== null && sink.audio !== null
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property bool muted: available ? sink.audio.muted : false
    readonly property string label: !available ? "N/A" : muted ? "MUTED" : Math.round(volume * 100) + "%"

    function toggleMuted() {
        if (available)
            sink.audio.muted = !sink.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink]
    }
}
