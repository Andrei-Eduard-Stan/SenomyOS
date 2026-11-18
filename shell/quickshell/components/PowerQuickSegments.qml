import QtQuick
import "../config" as Config
Item {
    id:root
    property var choices:[]
    property string value:""
    signal chosen(string value)
    FontMetrics {id:metrics;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
    readonly property real cellMin:choices.reduce((a,b)=>Math.max(a,metrics.advanceWidth(b.label)),0)+2*Config.DirectoryStyle.controlInset
    readonly property int columns:width>=choices.length*cellMin+(choices.length-1)*8?Math.max(1,choices.length):1
    implicitHeight:Math.ceil(choices.length/columns)*Config.DirectoryStyle.controlTarget+(Math.ceil(choices.length/columns)-1)*8
    function focusFirst(){for(let i=0;i<segments.count;i++){const item=segments.itemAt(i);if(item && item.enabled){item.forceActiveFocus();return;}}}
    Repeater {
        id:segments;model:root.choices
        QuietButton {
            required property var modelData;required property int index
            objectName:"session-mode-"+modelData.id
            x:(index%root.columns)*(width+8);y:Math.floor(index/root.columns)*(height+8)
            width:(root.width-(root.columns-1)*8)/root.columns;height:Config.DirectoryStyle.controlTarget
            text:modelData.label;active:root.value===modelData.id;enabled:root.enabled && modelData.enabled!==false
            Accessible.checkable:true;Accessible.checked:active
            onClicked:root.chosen(modelData.id)
            Keys.onRightPressed:if(index+1<segments.count)segments.itemAt(index+1).forceActiveFocus()
            Keys.onLeftPressed:if(index>0)segments.itemAt(index-1).forceActiveFocus()
            Rectangle {anchors.bottom:parent.bottom;anchors.bottomMargin:6;anchors.horizontalCenter:parent.horizontalCenter;width:16;height:1;visible:parent.active;color:Config.DirectoryStyle.ink}
        }
    }
}
