import QtQuick
import Quickshell.Networking
import "../config" as Config
Item {
    id:root
    required property var network
    required property var choice
    property bool locked:false
    readonly property bool stacked:width < 340 * Config.DirectoryStyle.textScale
    implicitHeight: stacked ? labels.implicitHeight + action.implicitHeight + 3 * Config.DirectoryStyle.controlGap
        : Math.max(labels.implicitHeight,action.implicitHeight) + 2 * Config.DirectoryStyle.controlGap
    height:implicitHeight
    Column {
        id:labels;x:Config.DirectoryStyle.controlInset;y:Config.DirectoryStyle.controlGap
        width:Math.max(1,root.width-2*x-(root.stacked?0:action.width+Config.DirectoryStyle.controlGap));spacing:4
        Text {width:parent.width;text:root.choice.name || "Hidden network";textFormat:Text.PlainText;wrapMode:Text.Wrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
        Text {width:parent.width;text:[root.choice.connected?"Connected":"",Math.round((Number(root.choice.signalStrength)||0)*(root.choice.signalStrength<=1?100:1))+"% signal",WifiSecurityType.toString(root.choice.security),root.choice.known?"Saved":"",root.choice.stateChanging?"Connecting…":""].filter(Boolean).join(" · ");textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
    }
    DashboardButton {
        id:action;objectName:"networkConnect"
        x:root.stacked?Config.DirectoryStyle.controlInset:root.width-width-Config.DirectoryStyle.controlInset
        y:root.stacked?labels.y+labels.implicitHeight+Config.DirectoryStyle.controlGap:Config.DirectoryStyle.controlGap
        width:Math.min(96*Config.DirectoryStyle.textScale,root.width-2*Config.DirectoryStyle.controlInset);centered:false
        text:root.choice.stateChanging?"Connecting…":root.choice.connected?"Disconnect":"Connect"
        enabled:root.network.wifiEnabled && !root.locked && !root.choice.stateChanging && (root.choice.connected || root.choice.known || root.choice.security===WifiSecurityType.Open || root.network.authenticationAvailable!==false)
        onClicked:{if(root.choice.connected || root.choice.known || root.choice.security===WifiSecurityType.Open)root.network.activate(root.choice);else root.network.openSecurePrompt(root.choice);}
    }
    Rectangle {width:parent.width;height:1;anchors.bottom:parent.bottom;color:Config.DirectoryStyle.rule}
}
