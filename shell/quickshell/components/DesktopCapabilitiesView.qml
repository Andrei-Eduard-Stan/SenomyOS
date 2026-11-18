import QtQuick
import "../config" as Config
Column {
    id:root
    required property var settings
    readonly property var capabilities:settings.capabilities||({})
    signal destinationRequested(string id)
    spacing:14
    Text {width:parent.width;text:"Desktop integration";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:20;font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
    Text {width:parent.width;text:"These checks show which providers and interfaces are present. They do not open permission prompts or prove that a complete task works.";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
    Text {width:parent.width;text:(root.capabilities.portal||{}).message||root.settings.capabilityError||"No integration snapshot yet.";textFormat:Text.PlainText;color:Config.Theme.warning;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WordWrap}
    DashboardButton {width:Math.min(220,parent.width);text:"Refresh capability checks";onClicked:root.settings.refresh()}
    Text {text:"Desktop services";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:18;color:Config.DirectoryStyle.ink}
    Repeater {
        model:root.capabilities.services||[]
        delegate:Column {
            required property var modelData;width:root.width;spacing:5
            Text {width:parent.width;text:modelData.unit;textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;wrapMode:Text.WrapAnywhere}
            Text {width:parent.width;text:modelData.available?"Service state: "+modelData.state:"Service unavailable";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
            Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
        }
    }
    Text {text:"Application portals";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:18;color:Config.DirectoryStyle.ink}
    Repeater {
        model:(root.capabilities.portal||{}).features||[]
        delegate:Column {
            required property var modelData;width:root.width;spacing:5
            Text {width:parent.width;text:modelData.name+" · "+(modelData.advertised?"Interface advertised":"Interface not advertised");textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
            Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
        }
    }
    Text {text:"Everyday tools";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:18;color:Config.DirectoryStyle.ink}
    Repeater {
        model:root.capabilities.tools||[]
        delegate:Column {
            required property var modelData;width:root.width;spacing:5
            Text {width:parent.width;text:modelData.name+" · "+(modelData.available?"Tool found":"Tool not found");font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
            Text {width:parent.width;text:"Complete task: not tested by this inspection";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
            Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
        }
    }
    Text {width:parent.width;text:root.capabilities.permissionPolicy||"Native application dialogs own permission requests.";textFormat:Text.PlainText;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;wrapMode:Text.WordWrap}
    Text {width:parent.width;text:"Flatpak: "+(root.capabilities.flatpakAvailable?"installed":"not installed")+". This does not establish application permission policy.";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WordWrap}
}
