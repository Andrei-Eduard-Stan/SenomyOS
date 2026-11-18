import QtQuick
import Quickshell.Services.Pipewire
import "../../config" as Config
Column {
    id:root
    required property var node
    width:parent.width;spacing:6
    PwNodePeakMonitor {id:monitor;node:root.node;enabled:root.visible && root.node!==null}
    AudioLabel {text:"LIVE MICROPHONE LEVEL · local meter, no recording file"}
    Rectangle {
        width:parent.width;height:12;color:Config.DirectoryStyle.selection
        Rectangle {width:parent.width*Math.max(0,Math.min(1,monitor.peak));height:parent.height;color:monitor.peak>=0.98?Config.Theme.danger:Config.DirectoryStyle.ink}
    }
    AudioLabel {text:root.node && root.node.audio && root.node.audio.muted?"Input is muted · monitoring is still a capture connection":"Meter creates a temporary capture connection · stop when finished"}
}
