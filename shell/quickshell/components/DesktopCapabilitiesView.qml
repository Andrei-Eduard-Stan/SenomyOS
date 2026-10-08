import QtQuick
import "../config" as Config
Column {
    id:root
    required property var settings
    readonly property var capabilities:settings.capabilities||({})
    spacing:10
    DashboardCard {width:parent.width;title:"DESKTOP PORTALS & PERMISSIONS";value:(root.capabilities.portal||{}).state==="advertised"?"INTERFACES ADVERTISED":"UNVERIFIED";detail:(root.capabilities.portal||{}).message||root.settings.capabilityError||"No desktop integration snapshot yet"}
    Text {width:parent.width;text:root.capabilities.permissionPolicy||"Permission requests remain in native application dialogs.";textFormat:Text.PlainText;color:Config.Theme.muted;font.family:Config.Theme.fontFamily;wrapMode:Text.WordWrap}
    Repeater {
        model:root.capabilities.services||[]
        delegate:DashboardCard {required property var modelData;width:root.width;title:modelData.unit;value:modelData.available?modelData.state.toUpperCase():"UNAVAILABLE";detail:"Reported user-service state; portal journey acceptance is separate"}
    }
    Repeater {
        model:(root.capabilities.portal||{}).features||[]
        delegate:DashboardCard {required property var modelData;width:root.width;title:modelData.name;value:modelData.advertised?"ADVERTISED":"NOT ADVERTISED";detail:"No permission was requested or approved by this inspection"}
    }
    DashboardCard {width:parent.width;title:"APPLICATION PERMISSIONS";value:root.capabilities.flatpakAvailable?"FLATPAK INSTALLED":"FLATPAK UNAVAILABLE";detail:"Native portal dialogs own consent. Flatpak installation is not proof of a permission manager or accepted application policy."}
    Text {width:parent.width;text:root.capabilities.journeys||"File and peripheral journeys require native application acceptance.";textFormat:Text.PlainText;color:Config.Theme.muted;font.family:Config.Theme.fontFamily;wrapMode:Text.WordWrap}
}
