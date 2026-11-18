import QtQuick
import ".."
import "../../config" as Config

Column {
    id: root
    required property var audio
    property bool input: false
    property real muteWidth:148
    readonly property bool usable: input ? audio.inputAvailable : audio.available
    readonly property bool muted: input ? audio.inputMuted : audio.muted
    readonly property real level: input ? audio.inputVolume : audio.volume
    readonly property var endpoint: input ? audio.source : audio.sink
    readonly property string deviceName: input ? audio.inputName : audio.outputName
    readonly property real displayedLevel: slider.pressed ? slider.value : level
    readonly property string stateText: !audio.ready ? "Connecting…" : !usable ? "Unavailable" : muted ? "Muted · level retained" : level===0 ? "Volume is zero" : ""
    spacing: Config.QuickPanelStyle.unit * 2
    onEndpointChanged: writeTimer.stop()
    onUsableChanged: if (!usable) writeTimer.stop()
    function setLevel(value) {
        if (!usable) return;
        if (input) audio.setInputVolume(value);
        else audio.setVolume(value);
    }
    Row {
        width: parent.width
        spacing: 12
        Column {
            width: Math.max(0, parent.width - valueLabel.width - parent.spacing)
            spacing: 8
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: root.input ? "Microphone" : "Output"
                color: root.muted ? Config.Theme.warning : root.input ? Config.QuickPanelStyle.secondary : Config.QuickPanelStyle.ink
                font.family: Config.QuickPanelStyle.headingFont
                font.pixelSize: Math.round(13*Config.DirectoryStyle.textScale)
                textFormat: Text.PlainText
            }
            Text {
                width: parent.width
                text: !root.audio.ready ? "Waiting for audio…" : root.usable ? root.deviceName : root.input ? "No input available" : "No output available"
                color: Config.QuickPanelStyle.ink
                font.family: Config.QuickPanelStyle.bodyFont
                font.pixelSize: root.input ? Config.DirectoryStyle.bodySize : Config.QuickPanelStyle.deviceSize
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
            }
        }
        Text {
            id: valueLabel
            objectName: root.input ? "quickInputValue" : "quickOutputValue"
            anchors.verticalCenter: parent.verticalCenter
            text: root.usable ? Math.round(root.displayedLevel * 100) + "%" : "—"
            color: root.muted ? Config.QuickPanelStyle.secondary : Config.QuickPanelStyle.ink
            font.family: Config.QuickPanelStyle.valueFont
            font.pixelSize: Math.round((root.input?21:42)*Config.DirectoryStyle.textScale)
            Accessible.name: (root.input ? "Microphone" : "Output") + " volume " + text + (root.muted ? ", muted" : "")
        }
    }
    Text {
        visible:!!root.stateText;width:parent.width;text:root.stateText
        color:root.muted?Config.Theme.warning:Config.DirectoryStyle.muted
        font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WordWrap
    }
    Flow {
        width: parent.width
        spacing: Config.QuickPanelStyle.gap
        CathedralSlider {
            id: slider
            objectName: root.input ? "quickInputSlider" : "quickOutputSlider"
            width: parent.width<root.muteWidth+100?parent.width:Math.max(24,parent.width-root.muteWidth-parent.spacing)
            height: Config.QuickPanelStyle.target
            from: 0
            to: root.audio.volumeLimit
            stepSize: 0.01
            enabled: root.usable
            Accessible.name: root.input ? "Microphone volume" : "Output volume"
            // Local drag feedback; bounded native writes, final write on release.
            onMoved: {
                writeTimer.pending = value;
                if (!writeTimer.running) writeTimer.start();
            }
            onPressedChanged: if (!pressed && writeTimer.running) {
                writeTimer.stop();
                root.setLevel(value);
            }
            background:Rectangle {
                x:slider.leftPadding;y:slider.topPadding+slider.availableHeight/2-height/2;width:slider.availableWidth;height:3;color:Config.DirectoryStyle.rule
                Rectangle {width:slider.visualPosition*parent.width;height:parent.height;color:root.muted?Config.DirectoryStyle.muted:Config.DirectoryStyle.ink}
            }
            handle:Canvas {
                x:slider.leftPadding+slider.visualPosition*(slider.availableWidth-width);y:slider.topPadding+slider.availableHeight/2-height/2
                width:14;height:22;antialiasing:true
                property color ink:slider.pressed || slider.activeFocus?Config.DirectoryStyle.ink:Config.DirectoryStyle.muted
                onInkChanged:requestPaint()
                onPaint:{const c=getContext("2d");c.reset();c.beginPath();c.moveTo(4,0);c.lineTo(width-4,0);c.lineTo(width,4);c.lineTo(width,height-4);c.lineTo(width-4,height);c.lineTo(4,height);c.lineTo(0,height-4);c.lineTo(0,4);c.closePath();c.fillStyle=ink;c.fill();}
            }
            Rectangle {anchors.fill:parent;color:"transparent";border.width:1;border.color:Config.DirectoryStyle.ink;visible:slider.visualFocus}
        }
        AudioMuteButton {
            id:muteButton
            objectName:root.input?"quickInputMute":"quickOutputMute"
            width:Math.min(root.muteWidth,parent.width);height:Config.QuickPanelStyle.target
            input:root.input;muted:root.muted;enabled:root.usable
            onClicked:root.input?root.audio.toggleInputMuted():root.audio.toggleMuted()
        }
    }
    Binding {
        target: slider
        property: "value"
        value: root.level
        when: !slider.pressed
        restoreMode: Binding.RestoreNone
    }
    Timer {
        id: writeTimer
        property real pending: 0
        interval: 40
        onTriggered: root.setLevel(pending)
    }
}
