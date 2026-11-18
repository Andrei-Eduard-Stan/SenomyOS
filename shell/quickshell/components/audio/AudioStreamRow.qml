import QtQuick
import ".."
import "../../config" as Config
Column {
    id:root
    required property var audio
    required property var node
    property bool recording:false
    signal navigate(int direction)
    activeFocusOnTab:true
    Accessible.role:Accessible.ListItem
    Accessible.name:audio.nodeName(node)
    Keys.onDownPressed:navigate(1)
    Keys.onUpPressed:navigate(-1)
    property string groupLabel:""
    readonly property var endpoints:recording?audio.inputNodes:audio.outputNodes
    readonly property var actualRoutes:typeof audio.routes==="function"?audio.routes(node):[]
    readonly property var evidence:typeof audio.graphNode==="function"?audio.graphNode(node):null
    width:parent.width;spacing:6
    AudioLabel {visible:root.groupLabel.length>0;text:root.groupLabel;font.pixelSize:14;color:Config.DirectoryStyle.ink}
    AudioLabel {text:(root.activeFocus?"› ":"")+root.audio.nodeName(root.node);color:Config.DirectoryStyle.ink}
    AudioLabel {text:root.audio.routeName(root.node)}
    AudioVolumeControl {width:parent.width;audio:root.audio;node:root.node;input:root.recording}
    ShellComboBox {
        objectName:"audioStreamRoute"
        width:parent.width
        model:root.endpoints
        textRole:"description"
        currentIndex:root.actualRoutes.length===1?root.endpoints.indexOf(root.actualRoutes[0]):-1
        displayText:currentIndex>=0?root.audio.nodeName(root.endpoints[currentIndex]):"Choose "+(root.recording?"input":"output")+" route"
        enabled:root.evidence!==null && root.evidence.movable && root.audio.graphSnapshot.canMove && !root.audio.actionsLocked
        Accessible.name:"Route for "+root.audio.nodeName(root.node)
        onActivated:index=>root.audio.requestMove(root.node,root.endpoints[index])
    }
    AudioLabel {visible:root.evidence===null || !root.evidence.movable || !root.audio.graphSnapshot.canMove;text:"Route selection unavailable · volume/mute remain native controls"}
    Row {
        width:parent.width;spacing:8
        ControlWorkspaceButton {
            width:(parent.width-8)/2
            text:root.audio.rememberedRoute(root.node)?"Forget route":"Remember route"
            enabled:root.audio.appKey(root.node).length>0 && !root.audio.preferenceBusy && (root.audio.rememberedRoute(root.node)!==null || root.actualRoutes.length===1)
            onClicked:root.audio.saveRoute(root.node,root.actualRoutes.length===1?root.actualRoutes[0]:null,root.audio.rememberedRoute(root.node)!==null)
        }
        ControlWorkspaceButton {
            width:(parent.width-8)/2;text:"Use saved route"
            enabled:root.audio.rememberedEndpoint(root.node)!==null && (root.actualRoutes.length!==1 || root.actualRoutes[0]!==root.audio.rememberedEndpoint(root.node)) && !root.audio.actionsLocked && root.audio.graphSnapshot.canMove
            onClicked:root.audio.requestMove(root.node,root.audio.rememberedEndpoint(root.node))
        }
    }
    AudioLabel {visible:root.audio.rememberedRoute(root.node)!==null;text:root.audio.rememberedEndpoint(root.node)?"Remembered route · apply explicitly with confirmation":"Remembered endpoint is disconnected or ambiguous"}
    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
}
