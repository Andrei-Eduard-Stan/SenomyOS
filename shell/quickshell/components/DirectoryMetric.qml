import QtQuick
import "../config" as Config
Item {
    id: root
    property bool reportActionsEnabled: true
    property bool compact: false
    property string title:""
    property string value:""
    property string detail:""
    property color valueColor:Config.DirectoryStyle.ink
    property real fraction:-1
    property var extraReport: ({})
    implicitWidth:210;implicitHeight:Math.max(root.compact?0:126,metricColumn.implicitHeight+20)
    Column {
        id:metricColumn
        x:4;y:8;width:parent.width-8;spacing:8
        Text {width:parent.width-(root.reportActionsEnabled?36:0);text:root.title.toUpperCase();color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.headingFont;font.pixelSize: 13;elide:Text.ElideRight}
        Text {width:parent.width;text:root.value;textFormat:Text.PlainText;color:root.valueColor;font.family:Config.DirectoryStyle.valueFont;font.pixelSize:root.height<100?18:24;fontSizeMode:Text.HorizontalFit;minimumPixelSize:12;elide:Text.ElideRight}
        Text {width:parent.width;text:root.detail;textFormat:Text.PlainText;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WordWrap}
        Rectangle {visible:root.fraction>=0;width:parent.width;height:5;color:Config.DirectoryStyle.rule;Rectangle{width:parent.width*Math.max(0,Math.min(1,root.fraction));height:parent.height;color:Config.DirectoryStyle.ink}}
    }
    ComponentReportMenu {visible:root.reportActionsEnabled;anchors.right:parent.right;anchors.top:parent.top;componentKey:root.title.toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/^-|-$/g,"").slice(0,63) || "metric";targetItem:root;report:({title:root.title,value:root.value,detail:root.detail,data:root.extraReport})}
}
