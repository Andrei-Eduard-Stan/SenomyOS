import QtQuick
import ".."
import "../../config" as Config
Column {
    id: root
    required property var audio
    property var node: null
    property bool input: false
    readonly property var effectiveNode: node || (input ? audio.source : audio.sink) || null
    onEffectiveNodeChanged: writeTimer.stop()
    onVisibleChanged: if(!visible)writeTimer.stop()
    property bool showNumeric: false
    readonly property bool usable: node ? node.ready && node.audio !== null : input ? audio.inputAvailable : audio.available
    readonly property real level: node ? usable ? node.audio.volume : 0 : input ? audio.inputVolume : audio.volume
    readonly property bool muted: node ? usable && node.audio.muted : input ? audio.inputMuted : audio.muted
    readonly property real limit: typeof audio.volumeLimit === "number" ? audio.volumeLimit : 1
    spacing: 4
    function set(value) { if(node)audio.setNodeVolume(node,value);else if(input)audio.setInputVolume(value);else audio.setVolume(value); }
    function toggle() { if(node)audio.toggleNodeMuted(node);else if(input)audio.toggleInputMuted();else audio.toggleMuted(); }
    Row {
        x:Config.DirectoryStyle.controlInset;width:Math.max(1,parent.width-2*x);spacing:Config.DirectoryStyle.controlGap
        CathedralSlider {
            id:slider;width:Math.max(24,parent.width-mute.width-valueLabel.width-2*parent.spacing);height:Config.DirectoryStyle.controlTarget;from:0;to:root.limit;stepSize:0.01
            enabled:root.usable;Accessible.name:root.node?root.audio.nodeName(root.node)+" volume":root.input?"Microphone volume":"Output volume"
            onMoved:{writeTimer.pending=value;if(!writeTimer.running)writeTimer.start();}
            onPressedChanged:if(!pressed && writeTimer.running){writeTimer.stop();root.set(value);}
        }
        AudioLabel {id:valueLabel;width:Math.round(56*Config.DirectoryStyle.textScale);height:Config.DirectoryStyle.controlTarget;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;text:root.usable?Math.round(root.level*100)+"%":"N/A";color:Config.DirectoryStyle.ink;font.pixelSize:Config.DirectoryStyle.bodySize}
        ControlWorkspaceButton {id:mute;width:Math.ceil(minimumContentWidth);height:Config.DirectoryStyle.controlTarget;text:root.muted?"Unmute":"Mute";active:root.muted;enabled:root.usable;accessibleLabel:(root.node?root.audio.nodeName(root.node):root.input?"Microphone":"Output")+" "+text;onClicked:root.toggle()}
    }
    Binding { target:slider;property:"value";value:root.level;when:!slider.pressed;restoreMode:Binding.RestoreNone }
    Timer {id:writeTimer;property real pending:0;interval:40;onTriggered:root.set(pending)}
    Flow {
        visible:root.showNumeric;x:Config.DirectoryStyle.controlInset;width:Math.max(1,parent.width-2*x);spacing:Config.DirectoryStyle.controlGap
        ShellSpinBox {id:numeric;visible:root.level<=root.limit;width:Math.min(parent.width,160);from:0;to:Math.round(root.limit*100);editable:true;value:Math.round(root.level*100);enabled:root.usable;Accessible.name:"Volume percent";onValueModified:root.set(value/100)}
        AudioLabel {visible:root.level>root.limit || root.muted || root.level>1;width:parent.width<420*Config.DirectoryStyle.textScale?parent.width:Math.max(1,parent.width-(numeric.visible?numeric.width+parent.spacing:0));height:Math.max(implicitHeight,numeric.height);verticalAlignment:Text.AlignVCenter;text:root.level>root.limit?"Reported level exceeds the allowed range; use the slider to set "+Math.round(root.limit*100)+"% or less":root.muted?"Muted · level is retained":root.level>1?"Amplified · clipping is possible":"Volume in percent"}
    }
}
