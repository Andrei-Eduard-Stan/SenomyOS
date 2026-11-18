import QtQuick
import "../config" as Config
Item {
    id:root
    property var cores:[]
    implicitHeight:160
    Text {x:4;y:8;text:"CORE UTILISATION";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.headingFont;font.pixelSize: 13}
    Text {x:4;y:30;text:cores.length+" logical processors · /proc/stat deltas";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12}
    Flow {
        x:4;y:50;width:parent.width-8;spacing:6
        Repeater {
            model:root.cores
            delegate:Item {
                required property var modelData
                width:Math.max(16,Math.min(30,(root.width-12)/Math.max(1,root.cores.length)-6));height:98
                Rectangle {x:2;y:2;width:parent.width-4;height:72;color:"transparent";border.width:1;border.color:Config.DirectoryStyle.rule;Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:parent.height*(modelData.percent===null?0:modelData.percent/100);color:Config.DirectoryStyle.ink}}
                Text {anchors.horizontalCenter:parent.horizontalCenter;y:80;text:modelData.id;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12;color:Config.DirectoryStyle.muted}
                HoverHandler {id:hover}
                // Every bar represents a real logical CPU; warming counters remain null.
                Accessible.name:"CPU "+modelData.id+": "+(modelData.percent===null?"collecting":modelData.percent.toFixed(1)+" percent")
                Text {visible:hover.hovered;z:4;y:12;text:modelData.percent===null?"—":Math.round(modelData.percent)+"%";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12}
            }
        }
    }
    ComponentReportMenu {anchors.right:parent.right;anchors.top:parent.top;componentKey:"core-utilisation";targetItem:root;report:({source:"/proc/stat / logical CPU deltas",cores:root.cores})}
    Text {visible:root.cores.length===0;anchors.centerIn:parent;text:"Per-core data unavailable or collecting";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12}
}
