import QtQuick
import QtQuick.Controls
import Quickshell
import "../config" as Config

// A destination with its observed reason, not a generic action button or a card.
AbstractButton {
    id:root
    required property var entry
    readonly property bool narrow:width<560*Config.DirectoryStyle.textScale
    signal destinationRequested(string route)
    hoverEnabled:true
    activeFocusOnTab:enabled
    implicitHeight:Math.max(Config.DirectoryStyle.controlTarget,labels.implicitHeight+32)
    Accessible.name:entry.title+". "+entry.state+". "+entry.action
    Accessible.description:entry.detail
    Keys.onReturnPressed:if(enabled)clicked()
    Keys.onEnterPressed:if(enabled)clicked()
    onClicked:destinationRequested(entry.route)
    background:Item {
        Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:Config.DirectoryStyle.rule}
        ButtonHoverFrame {focused:root.visualFocus;anchors.fill:parent;engaged:root.enabled && root.hovered}
    }
    contentItem:Item {
        Column {
            id:labels;x:Config.DirectoryStyle.controlInset;y:16
            width:Math.max(0,parent.width-x-Config.DirectoryStyle.controlInset-(root.narrow?0:destination.width+24));spacing:7
            Text {width:parent.width;text:root.entry.title;textFormat:Text.PlainText;wrapMode:Text.Wrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(18*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold}
            Text {width:parent.width;text:root.entry.state;textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.entry.tone==="attention"?Config.Theme.warning:Config.DirectoryStyle.ink;font.family:root.entry.id==="notifications"?Config.DirectoryStyle.valueFont:Config.DirectoryStyle.bodyFont;font.pixelSize:root.entry.id==="notifications"?Math.round(24*Config.DirectoryStyle.textScale):Config.DirectoryStyle.bodySize}
            Text {width:parent.width;text:root.entry.detail;textFormat:Text.PlainText;wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;lineHeight:1.25}
            Text {visible:root.narrow;width:parent.width;text:root.entry.action+" ›";wrapMode:Text.Wrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:Font.DemiBold}
        }
        Text {
            id:destination;visible:!root.narrow
            anchors.right:parent.right;anchors.rightMargin:Config.DirectoryStyle.controlInset;anchors.verticalCenter:parent.verticalCenter
            text:root.entry.action+" ›";textFormat:Text.PlainText
            color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize
        }
    }
}
