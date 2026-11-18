import QtQuick
import QtQuick.Controls
import Quickshell.Networking
import "../config" as Config

Button {
    id:root
    required property var choice
    required property real actionWidth
    property bool canConnect:true
    readonly property real strength:Number(choice.signalStrength)
    signal activated()
    objectName:"networkChoice-"+(choice.name || "hidden")
    enabled:canConnect && !choice.stateChanging
    hoverEnabled:true;leftPadding:Config.DirectoryStyle.controlInset;rightPadding:Config.DirectoryStyle.controlInset;topPadding:10;bottomPadding:10
    implicitHeight:Math.max(Config.DirectoryStyle.controlTarget,labels.implicitHeight+20)
    height:implicitHeight
    Accessible.name:(choice.stateChanging?"Connecting to ":"Connect to ")+(choice.name || "Hidden network")
    Accessible.description:meta.text
    Keys.onReturnPressed:if(enabled)clicked()
    Keys.onEnterPressed:if(enabled)clicked()
    onClicked:activated()
    opacity:enabled?1:0.46
    background:Rectangle {color:root.down?Config.DirectoryStyle.selection:"transparent";border.width:root.visualFocus?1:0;border.color:Config.DirectoryStyle.ink}
    contentItem:Item {
        Text {id:glyph;width:20;height:parent.height;text:"\uf1eb";font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:16;color:Config.DirectoryStyle.muted;verticalAlignment:Text.AlignVCenter;Accessible.ignored:true}
        Column {
            id:labels;x:32;width:Math.max(1,parent.width-x-action.width-8);anchors.verticalCenter:parent.verticalCenter;spacing:4
            Text {width:parent.width;text:root.choice.name || "Hidden network";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:Font.Medium}
            Text {id:meta;width:parent.width;text:[root.choice.security===WifiSecurityType.Open?"Open · unsecured":root.choice.known?"Saved · secured":"Secured · Not saved",Number.isFinite(root.strength)?Math.round(root.strength*(root.strength<=1?100:1))+"%":"Signal unavailable"].join(" · ");textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:root.choice.security===WifiSecurityType.Open?Config.Theme.warning:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
        }
        Text {id:action;anchors.right:parent.right;width:Math.min(root.actionWidth,Math.round(80*Config.DirectoryStyle.textScale));height:parent.height;text:root.choice.stateChanging?"Connecting…":"Connect ›";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;wrapMode:Text.WordWrap;Accessible.ignored:true}
    }
}
