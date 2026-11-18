import QtQuick
import QtQuick.Controls
import "../config" as Config
Column {
    id:root
    required property var settings
    property string part:"defaults"
    property string selectedKey:""
    spacing:Config.DirectoryStyle.sectionGap
    component Help: Text {
        x:Config.DirectoryStyle.controlInset;width:Math.max(1,parent.width-2*x)
        textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted
        font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize
    }
    Row {
        width:parent.width
        Help {x:0;leftPadding:Config.DirectoryStyle.controlInset;width:Math.max(1,parent.width-refresh.width);height:refresh.height;verticalAlignment:Text.AlignVCenter;text:root.settings.loading?"Loading applications…":!root.settings.available?"Application preferences unavailable":root.settings.message}
        DashboardButton {id:refresh;width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Refresh";centered:false;enabled:!root.settings.loading&&!root.settings.actions.locked;onClicked:root.settings.refresh()}
    }
    Help {visible:!!text;text:root.settings.error;color:Config.Theme.warning}
    SelectionActionReview {width:parent.width;actions:root.settings.actions}
    Repeater {
        model:root.part==="defaults"?(root.selectedKey?root.settings.defaults.filter(n=>n.mime===root.selectedKey):root.settings.defaults):[]
        delegate:Column {
            id:role
            objectName:"control-device-"+encodeURIComponent(modelData.mime)
            required property var modelData
            width:root.width;spacing:Config.DirectoryStyle.controlGap
            Help {text:role.modelData.label;color:Config.DirectoryStyle.ink;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:Font.DemiBold}
            Flow {
                width:parent.width;spacing:Config.DirectoryStyle.controlGap
                ShellComboBox {
                    id:choice;width:parent.width<540*Config.DirectoryStyle.textScale?parent.width:Math.max(1,parent.width-review.width-parent.spacing)
                    model:role.modelData.options.map(item=>item.name)
                    currentIndex:Math.max(0,role.modelData.options.findIndex(item=>item.id===role.modelData.current))
                    enabled:role.modelData.options.length>0&&!root.settings.actions.locked
                    Accessible.name:"Choose default for "+role.modelData.label
                }
                DashboardButton {
                    id:review;width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Review change…";centered:false
                    enabled:!root.settings.actions.locked&&choice.currentIndex>=0&&choice.currentIndex<role.modelData.options.length
                        && role.modelData.options[choice.currentIndex].id!==role.modelData.current
                    onClicked:root.settings.actions.request("default",role.modelData.mime,role.modelData.options[choice.currentIndex].id)
                }
            }
            Help {visible:choice.currentIndex>=0 && choice.currentIndex<role.modelData.options.length && role.modelData.options[choice.currentIndex].id!==role.modelData.current;text:"Current default: "+role.modelData.currentName}
            Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
        }
    }
    Column {
        width:parent.width;spacing:Config.DirectoryStyle.controlGap;visible:root.part==="autostart"
        DashboardCard {width:parent.width;title:"Future login sessions";value:root.settings.deployment.enabled?"Autostart configured":root.settings.deployment.supported?"Autostart not configured":"Autostart unavailable";detail:root.settings.deployment.message||"Framework status unavailable"}
        DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Review enable autostart…";centered:false;enabled:root.settings.deployment.supported&&!root.settings.deployment.enabled&&!root.settings.actions.locked;onClicked:root.settings.actions.request("enable-autostart","","")}
        Help {text:"Add an application";color:Config.DirectoryStyle.ink;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:Font.DemiBold}
        ShellComboBox {id:newApp;width:parent.width;model:root.settings.apps.filter(item=>!root.settings.autostart.some(entry=>entry.id===item.id)).map(item=>item.name);enabled:model.length>0&&!root.settings.actions.locked;Accessible.name:"Choose an installed application for future autostart"}
        DashboardButton {
            width:Math.min(parent.width,Math.ceil(minimumContentWidth));text:"Review add to autostart…";centered:false
            readonly property var choices:root.settings.apps.filter(item=>!root.settings.autostart.some(entry=>entry.id===item.id))
            enabled:!root.settings.actions.locked&&newApp.currentIndex>=0&&newApp.currentIndex<choices.length
            onClicked:root.settings.actions.request("add-autostart",choices[newApp.currentIndex].id,"")
        }
        Repeater {
            model:root.part==="autostart"?root.settings.autostart:[]
            delegate:Column {
                required property var modelData
                width:root.width;spacing:Config.DirectoryStyle.controlGap
                Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
                DashboardCard {width:parent.width;title:modelData.source==="user"?"User autostart":"System autostart";value:modelData.name;detail:(modelData.enabled?"Enabled at login":"Disabled at login")+" · "+(modelData.eligible?"Eligible for this desktop":"Currently ineligible")+" · Runtime launch unverified"}
                DashboardButton {width:Math.min(parent.width,Math.ceil(minimumContentWidth));centered:false;text:modelData.protected?"Protected session infrastructure":modelData.enabled?"Review disable at login…":"Review enable at login…";enabled:!modelData.protected&&!root.settings.actions.locked;onClicked:root.settings.actions.request("autostart",modelData.id,modelData.enabled?"no":"yes")}
            }
        }
    }
}
