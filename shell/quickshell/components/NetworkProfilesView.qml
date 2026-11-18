import QtQuick
import "../config" as Config
Column {
    id:root
    required property var profiles
    property string part:"saved"
    property string selectedKey:""
    readonly property var displayedProfiles:part==="advanced"?profiles.items.filter(item=>["vpn","wireguard"].includes(item.type)):selectedKey?profiles.items.filter(n=>n.uuid===selectedKey):profiles.items
    spacing:Config.DirectoryStyle.controlGap
    Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:root.part==="advanced"?"VPN connections":"Saved connections";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize+2;font.weight:Font.DemiBold;wrapMode:Text.WordWrap}
    Flow {
        width:parent.width;spacing:Config.DirectoryStyle.controlGap
        DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Refresh";centered:false;enabled:!root.profiles.busy;onClicked:root.profiles.refresh()}
        DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Network editor…";centered:false;enabled:root.profiles.editorAvailable&&!root.profiles.busy;onClicked:root.profiles.openEditor("all","")}
        DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"VPN editor…";centered:false;enabled:root.profiles.editorAvailable&&!root.profiles.busy;onClicked:root.profiles.openEditor("vpn","")}
    }
    Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;visible:!!text;text:root.profiles.error || root.profiles.message || "";textFormat:Text.PlainText;color:root.profiles.error?Config.Theme.warning:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WordWrap}
    SelectionActionReview {width:parent.width;actions:root.profiles.actions}
    Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;visible:root.selectedKey.length>0&&!root.profiles.items.some(n=>n.uuid===root.selectedKey);text:"This connection is no longer available. Choose another in the directory.";wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
    Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;visible:root.displayedProfiles.length===0;text:root.profiles.loading?"Loading connections…":!root.profiles.available?"Connection profiles are unavailable.":root.part==="advanced"?"No VPN profiles. Use the VPN editor to add one.":"No saved connections.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
    Repeater {
        model:root.displayedProfiles
        delegate:Column {
            required property var modelData
            objectName:"control-device-"+encodeURIComponent(modelData.uuid)
            width:root.width;spacing:4
            Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
            DashboardCard {width:parent.width;title:parent.modelData.type;value:parent.modelData.name;detail:(parent.modelData.active?"Connected":"Not connected")+" · Autoconnect "+(parent.modelData.autoconnect?"on":"off")}
            Flow {
                width:parent.width;spacing:Config.DirectoryStyle.controlGap
                DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Edit…";centered:false;accessibleLabel:"Edit connection, DNS and proxy settings";enabled:root.profiles.editorAvailable&&!root.profiles.busy;onClicked:root.profiles.openEditor("edit",modelData.uuid)}
                DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:modelData.autoconnect?"Autoconnect off":"Autoconnect on";centered:false;enabled:modelData.mutable&&!root.profiles.busy;onClicked:root.profiles.actions.request("autoconnect",modelData)}
                DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Connect";centered:false;visible:!modelData.active;enabled:modelData.mutable&&!root.profiles.busy;onClicked:root.profiles.actions.request("connect",modelData)}
                DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:modelData.active?"Disconnect":"Forget…";centered:false;enabled:modelData.mutable&&!root.profiles.busy;onClicked:root.profiles.actions.request(modelData.active?"disconnect":"forget",modelData)}
            }
        }
    }
}
