import QtQuick
import QtQuick.Controls
import "../config" as Config
Column {
    id:root
    required property var settings
    spacing:10
    DashboardCard {width:parent.width;title:"APPLICATION PREFERENCES";value:root.settings.loading?"LOADING":root.settings.available?"DESKTOP REGISTRY":"UNAVAILABLE";detail:root.settings.message}
    DashboardButton {width:parent.width;text:"REFRESH DESKTOP STATUS";enabled:!root.settings.loading&&!root.settings.actions.locked;onClicked:root.settings.refresh()}
    Text {width:parent.width;visible:root.settings.error.length>0;text:root.settings.error;textFormat:Text.PlainText;color:Config.Theme.warning;font.family:Config.Theme.fontFamily;wrapMode:Text.WordWrap}
    SelectionActionReview {width:parent.width;actions:root.settings.actions}
    Text {text:"DEFAULT APPLICATIONS";color:Config.Theme.dim;font.family:Config.Theme.fontFamily;font.pixelSize:10}
    Repeater {
        model:root.settings.defaults
        delegate:Column {
            id:role
            required property var modelData
            width:root.width;spacing:5
            DashboardCard {width:parent.width;title:role.modelData.label;value:role.modelData.currentName;detail:"Current registered MIME default"}
            ComboBox {
                id:choice;width:parent.width
                model:role.modelData.options.map(item=>item.name)
                currentIndex:Math.max(0,role.modelData.options.findIndex(item=>item.id===role.modelData.current))
                enabled:role.modelData.options.length>0&&!root.settings.actions.locked
                Accessible.name:"Choose default for "+role.modelData.label
            }
            DashboardButton {
                width:parent.width;text:"REVIEW DEFAULT CHANGE"
                enabled:!root.settings.actions.locked&&choice.currentIndex>=0&&choice.currentIndex<role.modelData.options.length
                    && role.modelData.options[choice.currentIndex].id!==role.modelData.current
                onClicked:root.settings.actions.request("default",role.modelData.mime,role.modelData.options[choice.currentIndex].id)
            }
        }
    }
    Rectangle {width:parent.width;height:1;color:Config.Theme.surfaceHover}
    DashboardCard {width:parent.width;title:"FUTURE XDG AUTOSTART";value:root.settings.deployment.enabled?"CONFIGURED FOR FUTURE SESSIONS":root.settings.deployment.supported?"NOT CONFIGURED":"UNAVAILABLE";detail:root.settings.deployment.message||"Framework status unavailable"}
    DashboardButton {width:parent.width;text:"REVIEW ENABLE FUTURE AUTOSTART";enabled:root.settings.deployment.supported&&!root.settings.deployment.enabled&&!root.settings.actions.locked;onClicked:root.settings.actions.request("enable-autostart","","")}
    ComboBox {id:newApp;width:parent.width;model:root.settings.apps.filter(item=>!root.settings.autostart.some(entry=>entry.id===item.id)).map(item=>item.name);enabled:model.length>0&&!root.settings.actions.locked;Accessible.name:"Choose an installed application for future autostart"}
    DashboardButton {
        width:parent.width;text:"REVIEW ADD TO AUTOSTART"
        readonly property var choices:root.settings.apps.filter(item=>!root.settings.autostart.some(entry=>entry.id===item.id))
        enabled:!root.settings.actions.locked&&newApp.currentIndex>=0&&newApp.currentIndex<choices.length
        onClicked:root.settings.actions.request("add-autostart",choices[newApp.currentIndex].id,"")
    }
    Repeater {
        model:root.settings.autostart
        delegate:Column {
            required property var modelData
            width:root.width;spacing:5
            DashboardCard {width:parent.width;title:modelData.source==="user"?"USER AUTOSTART":"SYSTEM AUTOSTART";value:modelData.name;detail:(modelData.enabled?"CONFIGURED ON":"CONFIGURED OFF")+" · "+(modelData.eligible?"eligible for current desktop":"currently ineligible")+" · runtime launch unverified"}
            DashboardButton {width:parent.width;text:modelData.protected?"PROTECTED SESSION INFRASTRUCTURE":modelData.enabled?"REVIEW DISABLE AT LOGIN":"REVIEW ENABLE AT LOGIN";enabled:!modelData.protected&&!root.settings.actions.locked;onClicked:root.settings.actions.request("autostart",modelData.id,modelData.enabled?"no":"yes")}
        }
    }
}
