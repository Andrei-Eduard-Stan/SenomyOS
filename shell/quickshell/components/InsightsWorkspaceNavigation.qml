import QtQuick
import QtQuick.Controls
import "../config" as Config
FocusScope {
 id:root
 property var nodes:[]
 property string activeNode:""
 signal activated(var node)
 function focusSection(){const index=Math.max(0,nodes.findIndex(n=>n.id===activeNode));focusRow(index);}
 function focusRow(index){if(index<0 || index>=list.count)return;list.positionViewAtIndex(index,ListView.Contain);list.forceLayout();const row=list.itemAtIndex(index);if(row){row.focusReason=Qt.TabFocusReason;row.forceActiveFocus(Qt.TabFocusReason);}}
 ListView {
  id:list;anchors.fill:parent;clip:true;spacing:4;model:root.nodes;boundsBehavior:Flickable.StopAtBounds
  ScrollBar.vertical:ShellScrollBar {}
  delegate:QuietButton {
   id:route;required property var modelData;required property int index
   objectName:"insights-nav-"+modelData.id
   width:list.width-8;height:Math.max(Config.QuickPanelStyle.target,caption.implicitHeight+16)
   text:modelData.label;active:root.activeNode===modelData.id
   accessibleLabel:modelData.label+(active?", current destination":"")+(modelData.badge?", "+modelData.badge+" unread":"")
   Accessible.selected:active
   background.visible:visualFocus || down
   Keys.onUpPressed:root.focusRow(index-1)
   Keys.onDownPressed:root.focusRow(index+1)
   Keys.onPressed:event=>{if(event.key===Qt.Key_Home){root.focusRow(0);event.accepted=true;}else if(event.key===Qt.Key_End){root.focusRow(list.count-1);event.accepted=true;}}
   onClicked:root.activated(modelData)
   contentItem:Item {
    Rectangle {width:1;height:16;anchors.verticalCenter:parent.verticalCenter;visible:route.active;color:Config.DirectoryStyle.ink}
    Text {x:12;width:18;anchors.verticalCenter:parent.verticalCenter;text:route.modelData.glyph || "";font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:14;color:route.active?Config.DirectoryStyle.ink:Config.DirectoryStyle.muted;Accessible.ignored:true}
    Text {id:caption;x:40;width:Math.max(1,parent.width-x-(badge.visible?badge.width+12:6));anchors.verticalCenter:parent.verticalCenter;text:route.modelData.label;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:route.active?Font.DemiBold:Font.Normal;color:route.active?Config.DirectoryStyle.ink:Config.DirectoryStyle.muted;Accessible.ignored:true}
    Text {id:badge;anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;text:route.modelData.badge || "";visible:!!text;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;Accessible.ignored:true}
   }
  }
 }
}
