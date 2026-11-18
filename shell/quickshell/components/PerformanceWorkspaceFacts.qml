import QtQuick
import QtQuick.Layouts
import "../config" as Config
GridLayout {
 id:root;property var rows:[]
 columns:width>=720*Config.DirectoryStyle.textScale?3:width>=400*Config.DirectoryStyle.textScale?2:1
 columnSpacing:24;rowSpacing:18
 Repeater {model:root.rows
  Column {required property var modelData;Layout.fillWidth:true;Layout.preferredWidth:1;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop;spacing:6
   Text {width:parent.width;text:modelData.label;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
   Text {width:parent.width;text:String(modelData.value ?? "Unavailable");textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;font.family:modelData.numeric?Config.DirectoryStyle.valueFont:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round((modelData.numeric?22:16)*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink}
   Text {visible:!!modelData.detail;width:parent.width;text:modelData.detail || "";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
  }
 }
}
