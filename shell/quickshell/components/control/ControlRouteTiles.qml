import QtQuick
import QtQuick.Layouts
import ".."
import "../../config" as Config
GridLayout {
 id:root
 property var entries:[]
 signal activated(string id)
 columns:width<360*Config.DirectoryStyle.textScale?1:width<650*Config.DirectoryStyle.textScale?2:3
 columnSpacing:12;rowSpacing:12
 Repeater {model:root.entries
  QuietButton {
   id:command;required property var modelData
   Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:1
   Layout.preferredHeight:Math.max(64,caption.implicitHeight+24)
   text:modelData.label.charAt(0)+modelData.label.slice(1).toLowerCase().replace(/wi-fi/g,"Wi-Fi").replace(/vpn/g,"VPN").replace(/dns/g,"DNS")
   accessibleLabel:text+(modelData.detail?", "+modelData.detail:"")
   background.visible:visualFocus || down
   onClicked:root.activated(modelData.id)
   contentItem:Item {
    Text {x:16;width:20;anchors.verticalCenter:parent.verticalCenter;text:"\uf105";font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:14;color:Config.DirectoryStyle.muted;Accessible.ignored:true}
    Text {id:caption;x:48;width:Math.max(1,parent.width-x-16);anchors.verticalCenter:parent.verticalCenter;text:command.text;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;Accessible.ignored:true}
   }
  }
 }
}
