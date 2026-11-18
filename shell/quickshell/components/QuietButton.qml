import QtQuick
import QtQuick.Controls
import "../config" as Config

// Quiet pointer states; only press, keyboard focus and semantic state change paint.
Button {
    id:root
    property string glyph:""
    property bool active:false
    property bool warning:false
    property bool iconOnly:false
    property string accessibleLabel:text
    property int labelSize:Config.DirectoryStyle.detailSize
    property bool wrapLabel:false
    hoverEnabled:true
    implicitWidth:iconOnly?Config.DirectoryStyle.controlTarget:Math.ceil(measure.advanceWidth)+(glyph?24:0)+2*Config.DirectoryStyle.controlInset
    implicitHeight:Config.DirectoryStyle.controlTarget
    padding:0
    opacity:enabled?1:0.42
    Accessible.name:accessibleLabel
    Keys.onReturnPressed:if(enabled)clicked()
    Keys.onEnterPressed:if(enabled)clicked()
    TextMetrics {id:measure;text:root.text;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:root.labelSize}
    background:Canvas {
        id:back;anchors.fill:parent;antialiasing:true
        property color fillColor:root.warning?Qt.rgba(Config.Theme.warning.r,Config.Theme.warning.g,Config.Theme.warning.b,0.13):Qt.rgba(Config.DirectoryStyle.ink.r,Config.DirectoryStyle.ink.g,Config.DirectoryStyle.ink.b,root.down?0.16:root.active?0.11:0.055)
        Behavior on fillColor {ColorAnimation {duration:root.down?0:Config.Motion.selectionMs}}
        property color lineColor:root.visualFocus?Config.DirectoryStyle.ink:root.warning?Config.Theme.warning:Config.DirectoryStyle.rule
        onFillColorChanged:requestPaint();onLineColorChanged:requestPaint();onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        onPaint:{const c=getContext("2d");c.reset();const i=Config.DirectoryStyle.controlFrameInset,k=Config.DirectoryStyle.controlFrameCorner,r=width-i,b=height-i;c.beginPath();c.moveTo(i+k,i);c.lineTo(r-k,i);c.lineTo(r,i+k);c.lineTo(r,b-k);c.lineTo(r-k,b);c.lineTo(i+k,b);c.lineTo(i,b-k);c.lineTo(i,i+k);c.closePath();c.fillStyle=fillColor;c.fill();c.strokeStyle=lineColor;c.lineWidth=root.visualFocus?1.5:1;c.stroke();}
    }
    contentItem:Item {
        readonly property real iconWidth:root.glyph?16:0
        readonly property real gap:root.glyph && root.text && !root.iconOnly?8:0
        readonly property real groupWidth:root.iconOnly?16:Math.min(width-2*Config.DirectoryStyle.controlInset,iconWidth+gap+measure.advanceWidth)
        Text {x:(parent.width-parent.groupWidth)/2;width:parent.iconWidth;height:parent.height;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignHCenter;visible:!!root.glyph;text:root.glyph;font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:14;color:root.warning?Config.Theme.warning:Config.DirectoryStyle.ink;Accessible.ignored:true}
        Text {x:(parent.width-parent.groupWidth)/2+parent.iconWidth+parent.gap;width:Math.max(0,parent.groupWidth-parent.iconWidth-parent.gap);height:parent.height;visible:!root.iconOnly;text:root.text;textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:root.labelSize;color:root.warning?Config.Theme.warning:Config.DirectoryStyle.ink;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight;wrapMode:root.wrapLabel?Text.WordWrap:Text.NoWrap;Accessible.ignored:true}
    }
    ToolTip.visible:hovered;ToolTip.text:accessibleLabel;ToolTip.delay:650
}
