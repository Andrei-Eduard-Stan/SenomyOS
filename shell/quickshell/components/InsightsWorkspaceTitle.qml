import QtQuick
import "../config" as Config
Item {
 id:root
 property string title:""
 property string detail:""
 property alias actions:tools.data
 implicitHeight:Math.max(Config.QuickPanelStyle.target,labels.implicitHeight)
 Column {id:labels;width:Math.max(1,parent.width-(tools.width>0?tools.width+16:0));spacing:6
  Text {width:parent.width;text:root.title;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Math.round(19*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink}
  Text {width:parent.width;visible:!!root.detail;text:root.detail;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
 }
 Row {id:tools;anchors.right:parent.right;spacing:8}
}
