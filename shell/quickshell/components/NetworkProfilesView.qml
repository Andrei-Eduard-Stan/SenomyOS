import QtQuick
import "../config" as Config
Column {
    id:root
    required property var profiles
    spacing:10
    DashboardCard {width:parent.width;title:"SAVED CONNECTIONS";value:root.profiles.loading?"LOADING":root.profiles.available?root.profiles.items.length+" PROFILES":"UNAVAILABLE";detail:"Wi-Fi, wired and VPN profiles · DNS and connection proxy settings in the native editor"}
    Flow {
        width:parent.width;spacing:8
        DashboardButton {width:160;text:"REFRESH PROFILES";enabled:!root.profiles.busy;onClicked:root.profiles.refresh()}
        DashboardButton {width:160;text:"NETWORK EDITOR";enabled:root.profiles.editorAvailable&&!root.profiles.busy;onClicked:root.profiles.openEditor("all","")}
        DashboardButton {width:160;text:"VPN EDITOR";enabled:root.profiles.editorAvailable&&!root.profiles.busy;onClicked:root.profiles.openEditor("vpn","")}
    }
    Text {width:parent.width;visible:root.profiles.error.length>0;text:root.profiles.error;textFormat:Text.PlainText;color:Config.Theme.warning;font.family:Config.Theme.fontFamily;wrapMode:Text.WordWrap}
    Text {width:parent.width;text:root.profiles.message;textFormat:Text.PlainText;color:Config.Theme.muted;font.family:Config.Theme.fontFamily;wrapMode:Text.WordWrap}
    SelectionActionReview {width:parent.width;actions:root.profiles.actions}
    Repeater {
        model:root.profiles.items
        delegate:Column {
            required property var modelData
            width:root.width;spacing:5
            DashboardCard {width:parent.width;title:parent.modelData.type.toUpperCase();value:parent.modelData.name;detail:(parent.modelData.active?"ACTIVE":"INACTIVE")+" · autoconnect "+(parent.modelData.autoconnect?"on":"off")}
            Flow {
                width:parent.width;spacing:6
                DashboardButton {width:140;text:"EDIT / DNS / PROXY";enabled:root.profiles.editorAvailable&&!root.profiles.busy;onClicked:root.profiles.openEditor("edit",modelData.uuid)}
                DashboardButton {width:140;text:modelData.autoconnect?"AUTOCONNECT OFF":"AUTOCONNECT ON";enabled:modelData.mutable&&!root.profiles.busy;onClicked:root.profiles.actions.request("autoconnect",modelData)}
                DashboardButton {width:140;text:modelData.active?"DISCONNECT":"FORGET";enabled:modelData.mutable&&!root.profiles.busy;onClicked:root.profiles.actions.request(modelData.active?"disconnect":"forget",modelData)}
            }
        }
    }
}
