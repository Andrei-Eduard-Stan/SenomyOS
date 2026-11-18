import QtQuick
import "../config" as Config
QuietButton {
 id:root
 property string detail:""
 property string iconName:""
 property string frameKey:"button"
 property bool headerControl:false
 property bool centered:!detail && !iconName
 property bool wrapDetail:true
 property int detailWrapMode:Text.WordWrap
 property bool artBackground:false
 property color accentColor:Config.DirectoryStyle.ink
 readonly property bool pointerHovered:hovered
 readonly property real minimumContentWidth:Math.ceil(labelMeasure.advanceWidth)+2*Config.DirectoryStyle.controlInset+(iconName?24:0)
 implicitWidth:iconOnly?Config.DirectoryStyle.controlTarget:Math.max(148,minimumContentWidth)
 implicitHeight:Math.max(Config.DirectoryStyle.controlTarget,copy.implicitHeight+2*Config.DirectoryStyle.controlVerticalInset)
 wrapLabel:!headerControl
 accessibleLabel:text+(detail?". "+detail:"")
 TextMetrics {id:labelMeasure;text:root.text;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:root.labelSize}
 contentItem:Item {
  Column {id:copy;x:Config.DirectoryStyle.controlInset;width:Math.max(1,parent.width-2*x);anchors.verticalCenter:parent.verticalCenter;spacing:4
   Text {width:parent.width;text:root.text;textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:root.labelSize;color:root.accentColor;font.weight:root.active?Font.DemiBold:Font.Normal;horizontalAlignment:root.centered?Text.AlignHCenter:Text.AlignLeft;wrapMode:root.wrapLabel?Text.WordWrap:Text.NoWrap;elide:root.wrapLabel?Text.ElideNone:Text.ElideRight;Accessible.ignored:true}
   Text {visible:root.detail.length>0;width:parent.width;text:root.detail;textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;horizontalAlignment:root.centered?Text.AlignHCenter:Text.AlignLeft;wrapMode:root.wrapDetail?root.detailWrapMode:Text.NoWrap;elide:root.wrapDetail?Text.ElideNone:Text.ElideRight;Accessible.ignored:true}
  }
 }
}
