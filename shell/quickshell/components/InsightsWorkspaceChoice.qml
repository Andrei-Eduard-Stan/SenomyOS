import QtQuick
import QtQuick.Controls
import "../config" as Config
QuietButton {
 id:root
 property string detail:""
 property string hint:""
 implicitHeight:Math.max(Config.QuickPanelStyle.target,labels.implicitHeight+20)
 accessibleLabel:text+(detail?". "+detail:"")+(hint?". "+hint:"")
 background.visible:visualFocus || down || active
 ToolTip.visible:false
 contentItem:Item {
  implicitHeight:labels.implicitHeight
  Column {id:labels;x:10;y:10;width:Math.max(1,parent.width-20-(hint.visible?hint.width+12:0));spacing:5
   Text {width:parent.width;text:root.text;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:root.active?Font.DemiBold:Font.Normal;color:Config.DirectoryStyle.ink;Accessible.ignored:true}
   Text {visible:!!root.detail;width:parent.width;text:root.detail;textFormat:Text.PlainText;wrapMode:Text.WordWrap;maximumLineCount:2;elide:Text.ElideRight;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;Accessible.ignored:true}
  }
  Text {id:hint;anchors.right:parent.right;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter;width:Math.min(implicitWidth,parent.width*.3);text:root.hint;visible:!!text;textFormat:Text.PlainText;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignRight;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;Accessible.ignored:true}
 }
}
