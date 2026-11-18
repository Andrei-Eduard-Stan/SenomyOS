import QtQuick
import "../config" as Config
Column {
    id:root
    required property var device
    property bool expanded:false
    objectName:"network-interface-"+device.interface
    spacing:Config.DirectoryStyle.controlGap
    DirectoryButton {
        width:parent.width;text:root.device.interface+"  "+(root.expanded?"⌄":"›")
        detail:[root.device.type,root.device.state,root.device.connection].filter(Boolean).join(" · ")
        wrapLabel:true;wrapDetail:true
        Accessible.description:root.expanded?"Hide interface details":"Show interface addresses, gateway, DNS and routes"
        onClicked:root.expanded=!root.expanded
    }
    Column {
        visible:root.expanded;x:Config.DirectoryStyle.controlInset;width:Math.max(1,parent.width-2*x);spacing:Config.DirectoryStyle.controlGap
        Text {width:parent.width;text:(root.device.managed?"Managed by NetworkManager":"Externally managed")+(root.device.reason && root.device.reason!=="none"?" · "+root.device.reason:"");textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
        Repeater {
            model:[{label:"IPv4",data:root.device.ipv4 || {}},{label:"IPv6",data:root.device.ipv6 || {}}]
            delegate:Column {
                required property var modelData;width:parent.width;spacing:4
                Text {text:parent.modelData.label;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:Font.DemiBold}
                Repeater {
                    model:[{label:"Address",value:(modelData.data.addresses || []).join(", ") || "Not reported"},{label:"Gateway",value:modelData.data.gateway || "Not reported"},{label:"DNS",value:(modelData.data.dns || []).join(", ") || "Not reported"},{label:"Routes",value:(modelData.data.routes || []).map(r=>r.destination+"/"+r.prefix+" via "+(r.nextHop || "on-link")+" · metric "+(r.metric<0?"auto":r.metric)).join("; ") || "Not reported"}]
                    delegate:Column {
                        required property var modelData;width:parent.width;spacing:2
                        Text {width:parent.width;text:parent.modelData.label;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                        Text {width:parent.width;text:parent.modelData.value;textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                    }
                }
            }
        }
    }
    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
}
