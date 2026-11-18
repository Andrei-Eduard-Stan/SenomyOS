pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import ".."
import "../../config" as Config
import "BluetoothServices.js" as Services

FocusScope {
    id:root
    required property var service
    property var audio:null
    readonly property var device:service.selectedDevice
    readonly property var operation:device?service.operation(device):null
    readonly property string identity:device?device.token:""
    readonly property var matches:service.sameNameDevices(device)
    readonly property bool canManage:!!device && service.available && !service.isBusy(device.id) && !service.actions.locked
    readonly property string page:service.inspectorView
    property bool troubleshooting:false
    property bool aliasDirty:false
    property bool includeIdentifiers:false
    property string lastAliasResult:""
    property alias contentY:scroll.contentY
    signal closeRequested()
    signal audioRequested()
    function resetAlias(){aliasInput.text=device?device.name:"";aliasDirty=false;}
    onIdentityChanged:{troubleshooting=false;includeIdentifiers=false;detailFilter.text="";Qt.callLater(resetAlias);}
    onDeviceChanged:if(!aliasDirty)Qt.callLater(resetAlias)
    onOperationChanged:if(operation && operation.action==="rename" && operation.phase==="succeeded" && operation.id!==lastAliasResult){lastAliasResult=operation.id;Qt.callLater(resetAlias);}
    onPageChanged:scroll.contentY=0
    function value(input){return input===undefined || input===null?"Not reported":typeof input==="boolean"?(input?"Yes":"No"):String(input);}
    function hex(input){return input===undefined || input===null?"Not reported":"0x"+Number(input).toString(16).toUpperCase();}
    function date(input){return input?new Date(input).toLocaleString():"Not observed this session";}
    readonly property var properties:!device?[]:[
        {label:"Local alias",value:device.name},{label:"Device name",value:value(device.deviceName || null)},
        {label:"Address",value:value(device.address)},{label:"Address type",value:value(device.addressType)},
        {label:"Adapter",value:value(device.adapter.split("/").pop())},{label:"Device icon/type",value:value(device.icon)},
        {label:"Device class",value:hex(device.class)},{label:"Appearance",value:hex(device.appearance)},
        {label:"Device ID / modalias",value:value(device.modalias)},{label:"Connected",value:value(device.connected)},
        {label:"Paired",value:value(device.paired)},{label:"Bond stored",value:value(device.bonded)},
        {label:"Trusted",value:value(device.trusted)},{label:"Blocked",value:value(device.blocked)},
        {label:"Wake permitted",value:value(device.wakeAllowed)},{label:"Legacy pairing",value:value(device.legacyPairing)},
        {label:"Services resolved",value:value(device.servicesResolved)},{label:"Battery",value:device.battery===null?"Not reported":value(device.battery)+"%"},
        {label:"HID reconnect mode",value:value(device.reconnectMode)},{label:"Last observation",value:date(device.lastObservedAt)},
        {label:"Recent RSSI",value:typeof device.rssi==="number"?device.rssi+" dBm":"Not currently reported"},
        {label:"Recent transmit power",value:typeof device.txPower==="number"?device.txPower+" dBm":"Not currently reported"},
        {label:"Published interfaces",value:(device.interfaces || []).join("\n") || "Not reported"}
    ]
    readonly property var filteredProperties:properties.filter(item=>(item.label+" "+item.value).toLowerCase().includes(detailFilter.text.trim().toLowerCase()))
    Column {
        id:header;width:parent.width-12;spacing:8
        Row {
            width:parent.width;spacing:8
            BluetoothLabel {width:parent.width-84;height:44;text:"Device details";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;verticalAlignment:Text.AlignVCenter}
            ControlWorkspaceButton {objectName:"bluetoothInspectorClose";width:Math.max(76,Math.ceil(minimumContentWidth));text:"Back";headerControl:true;onClicked:root.closeRequested()}
        }
        Text {width:parent.width;text:root.device?root.device.name:"Select a device";textFormat:Text.PlainText;elide:Text.ElideRight;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.titleSize}
        BluetoothLabel {visible:!!root.device;text:root.device?(root.device.connected?"Connected":root.device.paired?"Paired · Not connected":"Not paired")+" · "+root.service.identityHint(root.device):""}
        Row {
            width:parent.width;spacing:4;visible:!!root.device
            Repeater {
                model:[{id:"overview",name:"Overview"},{id:"manage",name:"Manage"},{id:"details",name:"Details"}]
                delegate:ControlWorkspaceButton {required property var modelData;objectName:"bluetoothTab:"+modelData.id;width:(header.width-8)/3;text:modelData.name;active:root.page===modelData.id;headerControl:true;onClicked:root.service.inspectorView=modelData.id}
            }
        }
    }
    FocusScrollArea {
        id:scroll;anchors.top:header.bottom;anchors.topMargin:16;anchors.bottom:parent.bottom;width:parent.width
        contentHeight:body.implicitHeight
        ScrollBar.vertical:ShellScrollBar {}
        Column {
            id:body;width:Math.max(1,root.width-12);spacing:16
            BluetoothLabel {visible:!root.device;text:root.service.selectedDeviceId?"This device disappeared. Close details or select another device.":"Choose a row to preview the device, manage its permissions or inspect its reported properties."}
            Column {
                width:parent.width;spacing:12;visible:!!root.device && root.page==="overview"
                BluetoothLabel {objectName:"bluetoothOperationResult";visible:!!root.operation;text:root.operation?root.operation.message:"";color:root.operation&&root.operation.phase==="failed"?Config.Theme.warning:Config.DirectoryStyle.muted;Accessible.role:Accessible.StaticText;Accessible.name:text}
                ControlWorkspaceButton {
                    objectName:"bluetoothInspectorPrimary";width:parent.width
                    readonly property bool cancellable:root.operation && root.operation.phase==="running" && ["connect","pair"].includes(root.operation.action)
                    readonly property bool busy:root.device && root.service.isBusy(root.device.id)
                    text:cancellable?"Cancel "+root.operation.action:busy?"Resolving attempt…":root.operation&&root.operation.phase==="failed"&&["connect","pair"].includes(root.operation.action)?"Retry "+root.operation.action:root.device&&root.device.connected?"Disconnect":root.device&&root.device.paired?"Connect":"Pair device"
                    enabled:!!root.device && root.service.enabled && !root.device.blocked && !root.service.actions.locked && (!busy || cancellable)
                    onClicked:cancellable?root.service.cancelOperation(root.device):root.service.toggleConnection(root.device)
                }
                Column {
                    width:parent.width;spacing:8;visible:root.matches.length>0
                    BluetoothLabel {text:"SAME NAME, DIFFERENT IDENTITIES";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.Theme.warning}
                    BluetoothLabel {text:"Another device uses this name. Compare its identity before connecting or pairing; the saved record may refer to a different headset."}
                    Repeater {model:root.matches;delegate:ControlWorkspaceButton {required property var modelData;objectName:"bluetoothCompare:"+modelData.id;width:body.width;text:"Inspect "+root.service.identityHint(modelData);detail:modelData.connected?"Connected":modelData.paired?"Saved pairing":modelData.recent?"Recently detected · Not paired":"Cached · Availability unknown";onClicked:root.service.selectDevice(modelData)}}
                }
                BluetoothProperty {width:parent.width;label:"Battery";value:root.device && root.device.battery!==null?root.device.battery+"%":"Not reported"}
                BluetoothProperty {width:parent.width;label:"Services";value:root.device?root.device.servicesResolved===true?"Resolved":root.device.servicesResolved===false?"Not resolved":"Not reported":""}
                ControlWorkspaceButton {width:parent.width;text:root.troubleshooting?"Hide troubleshooting":"Troubleshoot";headerControl:true;onClicked:root.troubleshooting=!root.troubleshooting}
                Column {
                    width:parent.width;spacing:8;visible:root.troubleshooting
                    BluetoothLabel {text:root.service.enabled?"Adapter is powered.":"Bluetooth is off. Enable it to connect; saved-device management remains available."}
                    BluetoothLabel {text:root.device&&root.device.blocked?"This device is blocked. Open Manage to unblock it.":root.device&&root.device.paired?"Pairing is stored. A timeout alone does not justify forgetting it.":"Put the device into pairing mode, then select Pair."}
                    BluetoothLabel {text:root.device&&root.device.recent?"Recently observed by this computer; this does not guarantee connectability.":"This identity has not been observed recently. Scan while the device is discoverable, and compare same-named entries."}
                }
                BluetoothAudioSection {width:parent.width;service:root.service;device:root.device;audio:root.audio;onAudioRequested:root.audioRequested()}
                BluetoothLabel {text:"Closing details leaves a connection attempt managed in the background. Use Cancel to stop it."}
            }
            Column {
                width:parent.width;spacing:12;visible:!!root.device && root.page==="manage"
                BluetoothLabel {text:"LOCAL DISPLAY NAME";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.ink}
                ControlWorkspaceSearch {id:aliasInput;objectName:"bluetoothAlias";width:parent.width;maximumLength:64;Accessible.name:"Local Bluetooth device alias";onTextEdited:root.aliasDirty=true}
                Row {
                    width:parent.width;spacing:8
                    ControlWorkspaceButton {objectName:"bluetoothSaveAlias";width:(parent.width-8)/2;text:"Review name";enabled:root.canManage && !!root.device && aliasInput.text!==root.device.name;onClicked:root.service.actions.request("rename",root.device,aliasInput.text)}
                    ControlWorkspaceButton {objectName:"bluetoothResetAlias";width:(parent.width-8)/2;text:"Reset name…";enabled:root.canManage && !!root.device && root.device.name!==root.device.deviceName;onClicked:root.service.actions.request("rename",root.device,"")}
                }
                BluetoothLabel {text:"The alias applies only on this computer. Reset restores the name supplied by the device."}
                BluetoothLabel {text:"CONNECTION PERMISSIONS";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.ink}
                BluetoothSetting {width:parent.width;title:"Trust this device";detail:"Allow reconnecting without an authorization prompt.";actionName:"bluetoothTrust";actionText:root.device&&root.device.trusted?"Trusted…":"Not trusted…";actionEnabled:root.canManage;onActivated:root.service.actions.request(root.device.trusted?"untrust":"trust",root.device)}
                BluetoothSetting {width:parent.width;title:"Incoming connections";detail:"Blocking rejects incoming connections and can remove device drivers.";actionName:"bluetoothBlock";actionText:root.device&&root.device.blocked?"Blocked…":"Allowed…";actionEnabled:root.canManage;onActivated:root.service.actions.request(root.device.blocked?"unblock":"block",root.device)}
                BluetoothSetting {width:parent.width;title:"Wake from sleep";detail:root.device && typeof root.device.wakeAllowed==="boolean"?"Wake permission; actual behavior depends on hardware support.":"Wake permission is not exposed for this device.";actionName:"bluetoothWake";actionText:!root.device || typeof root.device.wakeAllowed!=="boolean"?"Unavailable":root.device.wakeAllowed?"Allowed…":"Not allowed…";actionEnabled:root.canManage && !!root.device && typeof root.device.wakeAllowed==="boolean";onActivated:root.service.actions.request("wake",root.device,!root.device.wakeAllowed)}
                Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
                BluetoothLabel {text:"REMOVE THIS RECORD";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.Theme.warning}
                BluetoothLabel {text:root.device && (root.device.paired || root.device.bonded)?"Forget removes this computer’s pairing and cached information. It does not reset the physical device or remove its other hosts.":"Remove clears this unpaired discovery record. A nearby device can reappear when it advertises again."}
                ControlWorkspaceButton {objectName:"bluetoothForget";width:parent.width;text:root.device && (root.device.paired || root.device.bonded)?"Forget paired device…":"Remove discovery record…";enabled:root.canManage;onClicked:root.service.actions.request(root.device.paired || root.device.bonded?"forget":"remove",root.device)}
                BluetoothLabel {visible:!!root.operation && ["rename","trust","untrust","block","unblock","wake"].includes(root.operation.action);text:root.operation?root.operation.message:"";color:root.operation&&root.operation.phase==="failed"?Config.Theme.warning:Config.DirectoryStyle.muted}
            }
            Column {
                width:parent.width;spacing:12;visible:!!root.device && root.page==="details"
                ControlWorkspaceSearch {id:detailFilter;objectName:"bluetoothPropertySearch";width:parent.width;placeholderText:"Find a property or service…";Accessible.name:"Filter Bluetooth properties and services"}
                Repeater {model:root.filteredProperties;delegate:BluetoothProperty {required property var modelData;width:body.width;label:modelData.label;value:modelData.value}}
                BluetoothLabel {text:"REPORTED SERVICES · "+(root.device?(root.device.uuids || []).length:0);font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.ink}
                BluetoothLabel {text:root.device&&root.device.servicesResolved?"Service discovery is resolved. Audio controls use the endpoints and profiles reported by the audio system.":"These are recorded capabilities. Current service readiness is not confirmed."}
                Repeater {model:Services.items(root.device?root.device.uuids:[],detailFilter.text);delegate:Column {required property var modelData;width:body.width;spacing:4;BluetoothLabel {text:parent.modelData.name;color:Config.DirectoryStyle.ink}BluetoothLabel {text:parent.modelData.uuid;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WrapAnywhere}Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}}}
                BluetoothLabel {visible:!!root.device && (root.device.uuids || []).length===0;text:"No service identifiers are currently reported."}
                BluetoothLabel {visible:!!root.device && !!root.device.lastDisconnect;text:root.device&&root.device.lastDisconnect?"Last disconnect · "+root.date(root.device.lastDisconnect.at)+"\n"+root.device.lastDisconnect.reason+"\n"+root.device.lastDisconnect.message:""}
                Column {
                    width:parent.width;spacing:8;visible:!!root.operation
                    BluetoothLabel {text:"LAST OPERATION";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.ink}
                    BluetoothProperty {width:parent.width;label:"Action / result";value:root.operation?root.operation.action+" · "+root.operation.phase:""}
                    BluetoothProperty {width:parent.width;label:"Started";value:root.operation?root.date(root.operation.startedAt):""}
                    BluetoothProperty {width:parent.width;label:"Finished";value:root.operation && root.operation.finishedAt?root.date(root.operation.finishedAt):"Pending"}
                    BluetoothLabel {text:root.operation?root.operation.message:""}
                    BluetoothLabel {text:root.operation?root.operation.errorName+"\n"+root.operation.errorDetail:"";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WrapAnywhere}
                }
                Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
                BluetoothLabel {text:"DIAGNOSTIC REPORT";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.ink}
                ShellCheckBox {objectName:"bluetoothReportIdentifiers";width:parent.width;text:"Include full device identifiers";checked:root.includeIdentifiers;onToggled:root.includeIdentifiers=checked}
                Row {width:parent.width;spacing:8;BluetoothLabel {width:parent.width-deviceMenu.width-8;text:root.includeIdentifiers?"Reports include the address shown above.":"Text and copy reports hide full device addresses."}ContextEvidenceMenu {id:deviceMenu;contextKey:root.identity+":"+root.page+":"+root.includeIdentifiers;ownerActive:!!root.device && !root.service.actions.locked;accessibleLabel:"Bluetooth diagnostic actions";copyLabel:"Copy device diagnostics";textLabel:"Save device diagnostics as text";componentKey:"bluetooth-device";report:root.service.deviceReport(root.device,root.includeIdentifiers);}}
                BluetoothLabel {text:"Vendor app controls such as ANC, EQ, firmware updates and separate earbud/case batteries require a supported vendor interface. They are not inferred from a device name."}
            }
        }
    }
}
