pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../../config" as Config

Column {
    id:root
    required property var service
    readonly property var prompt:service.prompt
    readonly property string promptId:prompt?prompt.id:""
    onPromptIdChanged:{entry.text="";if(prompt)Qt.callLater(()=>reject.forceActiveFocus());}
    visible:!!prompt
    spacing:8
    BluetoothLabel {text:root.prompt?"PAIRING · "+root.prompt.name:"";font.family:Config.DirectoryStyle.headingFont;color:Config.DirectoryStyle.ink}
    BluetoothLabel {
        text:!root.prompt?"":root.prompt.kind==="RequestConfirmation"?"Confirm that this code matches the code on the device.":root.prompt.kind==="RequestPinCode"?"Enter the PIN provided by the device.":root.prompt.kind==="RequestPasskey"?"Enter the numeric passkey shown by the device.":root.prompt.kind.startsWith("Display")?"Enter this code on the device, then follow its pairing instructions.":"Allow the requested pairing or service for this device?"
    }
    BluetoothLabel {visible:!!root.prompt && !!root.prompt.code;text:root.prompt?root.prompt.code:"";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:24;color:Config.DirectoryStyle.ink}
    BluetoothLabel {visible:!!root.prompt && root.prompt.kind==="DisplayPasskey";text:root.prompt?root.prompt.entered+" digits entered on the device":""}
    ControlWorkspaceSearch {
        id:entry;objectName:"bluetoothPairingCode";width:parent.width
        visible:!!root.prompt && ["RequestPinCode","RequestPasskey"].includes(root.prompt.kind)
        maximumLength:root.prompt && root.prompt.kind==="RequestPasskey"?6:16
        echoMode:TextInput.PasswordEchoOnEdit
        Accessible.name:"Bluetooth pairing code"
    }
    Row {
        width:parent.width;spacing:8
        ControlWorkspaceButton {id:reject;objectName:"bluetoothPairingReject";width:(parent.width-8)/2;text:"Cancel pairing";onClicked:root.service.answer(false,"")}
        ControlWorkspaceButton {
            objectName:"bluetoothPairingAccept";width:(parent.width-8)/2;text:"Confirm"
            visible:!!root.prompt && !root.prompt.kind.startsWith("Display")
            enabled:!entry.visible || (root.prompt.kind==="RequestPasskey"?/^[0-9]{1,6}$/.test(entry.text):entry.text.length>0)
            onClicked:{root.service.answer(true,entry.text);entry.text="";}
        }
    }
}
