import QtQuick
import "../config" as Config
Item {
    id:root
    property string title:""
    property string value:"Unavailable"
    property string detail:""
    property real fraction:-1
    property string lowLabel:""
    property string highLabel:""
    implicitHeight:148
    Text {x:4;y:8;text:root.title;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.headingFont;font.pixelSize: 13}
    Text {x:4;y:40;width:parent.width-8;text:root.value;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.valueFont;font.pixelSize:26;elide:Text.ElideRight}
    Row {x:4;y:80;spacing:3
        Repeater {model:20;Rectangle {required property int index;width:Math.max(1,(root.width-65)/20);height:9;color:root.fraction>=0 && index<root.fraction*20?Config.DirectoryStyle.ink:Config.DirectoryStyle.rule}}
    }
    Text {x:4;y:100;text:root.lowLabel;color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12}
    Text {anchors.right:parent.right;anchors.rightMargin:4;y:100;text:root.highLabel;color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12}
    Text {x:4;y:122;width:parent.width-8;text:root.detail;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12;elide:Text.ElideRight}
    ComponentReportMenu {anchors.right:parent.right;anchors.top:parent.top;componentKey:root.title.toLowerCase();targetItem:root;report:({title:root.title,value:root.value,detail:root.detail,scaleLow:root.lowLabel,scaleHigh:root.highLabel})}
}
