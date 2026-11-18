import QtQuick
import ".."
import "../../config" as Config
Column {
    id:root
    objectName:"control-endpoint-"+encodeURIComponent(node.name || "")
    required property var audio
    required property var node
    property bool input:false
    property bool detailed:false
    readonly property bool current: node===(input?audio.source:audio.sink)
    width:parent.width;spacing:4
    AudioLabel {text:root.node.description || root.node.nickname || root.node.name || "Audio device";color:"#ffffff"}
    DashboardButton {
        width:parent.width;text:root.current?"DEFAULT "+(root.input?"INPUT":"OUTPUT"):"SET DEFAULT "+(root.input?"INPUT":"OUTPUT")
        detail:root.current?"DEFAULT · connected endpoint":"CONNECTED · select as default"
        active:root.current;enabled:!root.current && !(root.audio.actionsLocked || root.audio.selectionActions.locked)
        onClicked:root.input?root.audio.selectInput(root.node):root.audio.selectOutput(root.node)
    }
    AudioVolumeControl {visible:root.detailed;width:parent.width;audio:root.audio;node:root.node;input:root.input;showNumeric:true}
    Column {
        visible:root.detailed && typeof root.audio.stereo==="function" && root.audio.stereo(root.node)
        width:parent.width;spacing:2
        AudioLabel {text:"CHANNEL BALANCE // LEFT — RIGHT"}
        Row {
            width:parent.width;spacing:8
            CathedralSlider {width:Math.max(24,parent.width-98);height:48;from:-1;to:1;stepSize:0.05;value:typeof root.audio.balance==="function"?root.audio.balance(root.node):0;Accessible.name:"Left right channel balance";onMoved:root.audio.setBalance(root.node,value)}
            DashboardButton {width:90;text:"CENTER";onClicked:root.audio.setBalance(root.node,0)}
        }
    }
    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
}
