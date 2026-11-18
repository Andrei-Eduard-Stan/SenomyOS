pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../../config" as Config

Rectangle {
    id: root
    required property var service
    required property var device
    property bool selected: false
    signal detailsRequested()
    readonly property var operation: service.operation(device)
    readonly property bool busy: !!operation && ["running","cancelling"].includes(operation.phase)
    readonly property bool cancellable: busy && operation.phase==="running" && ["connect","pair"].includes(operation.action)
    readonly property string status: busy ? operation.message : device.blocked ? "Blocked" : device.connected ? "Connected"
        : operation && operation.phase==="failed" ? "Connection or device action failed"
        : device.paired ? "Paired · Not connected" : device.recent ? "Detected nearby · Not paired" : "Previously detected · Availability unknown"
    readonly property string primaryText: cancellable ? "Cancel" : busy ? "Working…" : device.blocked ? "Blocked" : device.connected ? "Disconnect"
        : operation && operation.phase==="failed" ? "Retry" : device.paired ? "Connect" : "Pair"
    implicitHeight: Math.max(Config.DirectoryStyle.touchMode ? 84 : 76, labels.implicitHeight+20)
    color: selected ? Config.DirectoryStyle.selection : "transparent"
    Rectangle {width:1;height:parent.height-20;y:10;color:Config.DirectoryStyle.ink;visible:root.selected}
    ControlWorkspaceButton {
        id:details
        objectName:"bluetoothDetails:"+root.device.id
        x:4;width:Math.max(100,parent.width-primary.width-12);height:parent.height
        headerControl:true;text:"";accessibleLabel:"Details for "+root.device.name+". "+root.status
        onClicked:root.detailsRequested()
        Text {
            x:Config.DirectoryStyle.controlInset;y:Math.round((parent.height-24)/2);width:24;height:24
            text:root.device.icon==="audio-card"?"\uf028":root.device.icon==="audio-input-microphone"?"\uf130":root.device.icon.startsWith("audio")?"\uf025":root.device.icon.startsWith("input-keyboard")?"\uf11c":root.device.icon.startsWith("input-mouse")?"\uf8cc":root.device.icon.startsWith("phone")?"\uf3cd":root.device.icon.startsWith("input-gaming")?"\uf11b":"\uf2db"
            font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:18;color:Config.DirectoryStyle.ink
            horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
        }
        Column {
            id:labels;x:Config.DirectoryStyle.controlInset+24+Config.DirectoryStyle.controlGap;width:Math.max(1,parent.width-x-Config.DirectoryStyle.controlInset);anchors.verticalCenter:parent.verticalCenter;spacing:4
            Text {width:parent.width;text:root.device.name;textFormat:Text.PlainText;wrapMode:Text.Wrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
            Text {width:parent.width;text:root.status+(root.device.battery!==null?" · "+root.device.battery+"%":"");textFormat:Text.PlainText;elide:Text.ElideRight;color:root.operation && root.operation.phase==="failed"?Config.Theme.warning:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
            Text {objectName:"bluetoothIdentity:"+root.device.id;width:parent.width;visible:root.service.sameNameDevices(root.device).length>0;text:"Identity "+root.service.identityHint(root.device);elide:Text.ElideRight;color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize}
        }
    }
    ControlWorkspaceButton {
        id:primary;objectName:"bluetoothPrimary:"+root.device.id
        anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter
        width:Math.max(Config.DirectoryStyle.touchMode?116:102,Math.ceil(minimumContentWidth));height:Config.QuickPanelStyle.target
        text:root.primaryText;headerControl:true
        accessibleLabel:root.primaryText+" "+root.device.name
        enabled:!!root.service.objectFor(root.device.adapter) && root.service.objectFor(root.device.adapter).powered && !root.service.actions.locked && (!root.busy || root.cancellable) && !root.device.blocked
        onClicked:root.cancellable?root.service.cancelOperation(root.device):root.service.toggleConnection(root.device)
    }
    Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:Config.DirectoryStyle.rule}
}
