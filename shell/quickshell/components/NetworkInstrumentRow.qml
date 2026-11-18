import QtQuick
import Quickshell.Networking
import "../config" as Config

Item {
    id:root
    required property var choice
    required property real actionWidth
    property bool canConnect:true
    readonly property real strength:Number(choice.signalStrength)
    readonly property bool stacked:width<actionWidth+144*Config.DirectoryStyle.textScale
    signal activated()
    implicitHeight:stacked?labels.implicitHeight+action.implicitHeight+24:Math.max(labels.implicitHeight,action.implicitHeight)+16
    height:implicitHeight
    Column {
        id:labels;y:8
        width:Math.max(1,root.width-(root.stacked?0:root.actionWidth+8));spacing:5
        Text {width:parent.width;text:root.choice.name || "Hidden network";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:Font.Medium}
        Text {width:parent.width;text:[WifiSecurityType.toString(root.choice.security),root.choice.known?"Saved":"",Number.isFinite(root.strength)?Math.round(root.strength*(root.strength<=1?100:1))+"% signal":"Signal unavailable"].filter(Boolean).join(" · ");textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize}
    }
    DashboardButton {
        id:action;objectName:"networkConnect"
        x:root.stacked?-Config.DirectoryStyle.controlInset:root.width-width+Config.DirectoryStyle.controlInset
        y:root.stacked?labels.y+labels.implicitHeight+4:Math.max(0,(root.implicitHeight-height)/2)
        width:root.actionWidth;centered:false
        text:root.choice.stateChanging?"Connecting…":"Connect"
        enabled:root.canConnect && !root.choice.stateChanging
        accessibleLabel:(root.choice.stateChanging?"Connecting to ":"Connect to ")+(root.choice.name || "hidden network")
        onClicked:root.activated()
    }
}
