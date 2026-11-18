pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import ".."
import "../../config" as Config

FocusScope {
    id:root
    required property var service
    property var audio:null
    property bool full:false
    property bool quick:false
    property bool showOther:false
    property string query:""
    property string filter:quick?"saved":"all"
    function matches(device){const text=(device.name+" "+(device.address || "")+" "+(device.icon || "")).toLowerCase();return text.includes(query.trim().toLowerCase()) && (filter==="all" || filter==="saved"&&(device.paired||device.connected) || filter==="connected"&&device.connected || filter==="nearby"&&!device.paired&&device.recent);}
    property bool showAdapter:false
    readonly property bool split:full && width>=780
    readonly property var adapterOperation:service.adapter?service.operation(service.adapter.id):null
    readonly property bool inspecting:!!service.selectedDeviceId
    signal audioRequested()
    signal fullSettingsRequested()
    Keys.onEscapePressed:event=>{
        if(service.prompt){service.answer(false,"");event.accepted=true;}
        else if(service.actions.locked){service.actions.cancel();event.accepted=true;}
        else if(inspecting){service.selectDevice(null);event.accepted=true;}
        else event.accepted=false;
    }

    FocusScrollArea {
        id:headingViewport;width:parent.width
        height:Math.min(heading.implicitHeight,Math.max(1,root.height-footer.height-96))
        contentHeight:heading.implicitHeight
        ScrollBar.vertical:ShellScrollBar {}
    Column {
        id:heading;width:parent.width;spacing:12
        Row {
            width:parent.width;spacing:8
            Column {
                width:Math.max(60,parent.width-power.width-8);spacing:4
                BluetoothLabel {text:root.service.adapter?root.service.adapter.name:"Bluetooth";font.pixelSize:16;color:Config.DirectoryStyle.ink}
                BluetoothLabel {text:!root.service.available?"Unavailable":!root.service.adapter?"No adapter detected":(root.adapterOperation && root.adapterOperation.phase==="running")?(root.adapterOperation.action==="enable"?"Enabling…":root.adapterOperation.action==="disable"?"Disabling…":"Applying adapter setting…"):root.service.adapter.powerState==="off-blocked"?"Radio blocked":root.service.adapter.powerState==="off-enabling"?"Enabling…":root.service.adapter.powerState==="on-disabling"?"Disabling…":root.service.enabled?"On · "+root.service.connectedDevices.length+" connected":"Off"}
            }
            ControlWorkspaceButton {id:power;objectName:"bluetoothPower";width:Math.max(112,Math.ceil(minimumContentWidth));text:root.service.enabled?"Turn off":"Turn on";active:root.service.enabled;enabled:root.service.available && !!root.service.adapter && !root.service.actions.locked && !root.service.isBusy(root.service.adapter.id);onClicked:root.service.setEnabled(!root.service.enabled)}
        }
        Flow {
            width:parent.width;spacing:8
            ControlWorkspaceButton {
                objectName:"bluetoothScan";width:Math.min(parent.width,Math.max(140,Math.ceil(minimumContentWidth)))
                readonly property bool scanning:root.service.scan.owned || ["starting","running","stopping"].includes(root.service.scan.state)
                text:scanning?"Stop scanning":"Scan for devices"
                enabled:root.service.enabled && !root.service.actions.locked && root.service.scan.state!=="stopping"
                onClicked:scanning?root.service.stopScan():root.service.startScan()
            }
            ControlWorkspaceButton {objectName:"bluetoothRefresh";width:Math.max(84,Math.ceil(minimumContentWidth));text:"Refresh";headerControl:true;onClicked:root.service.refresh()}
            ControlWorkspaceButton {width:Math.max(112,Math.ceil(minimumContentWidth));visible:!root.quick;text:"Adapter…";headerControl:true;onClicked:root.showAdapter=!root.showAdapter}
        }
        ControlWorkspaceSearch {objectName:"bluetoothSearch";width:parent.width;placeholderText:"Search devices…";Accessible.name:"Search Bluetooth devices";onTextChanged:root.query=text}
        Flow {width:parent.width;spacing:6
            Repeater {model:[{id:"all",label:"All"},{id:"saved",label:"Saved"},{id:"connected",label:"Connected"},{id:"nearby",label:"Nearby"}]
                QuietButton {required property var modelData;objectName:"bluetoothFilter:"+modelData.id;text:modelData.label;active:root.filter===modelData.id;Accessible.checkable:true;Accessible.checked:active;enabled:!root.service.actions.locked;onClicked:root.filter=modelData.id}
            }
        }
        BluetoothLabel {visible:!!root.service.error || !!root.service.scan.message;text:root.service.error || root.service.scan.message || "";color:root.service.error || root.service.scan.state==="failed"?Config.Theme.warning:Config.DirectoryStyle.muted}
        BluetoothLabel {visible:!!root.adapterOperation && root.adapterOperation.phase!=="running";text:root.adapterOperation?root.adapterOperation.message:"";color:root.adapterOperation && root.adapterOperation.phase==="failed"?Config.Theme.warning:Config.DirectoryStyle.muted}
        Column {
            width:parent.width;spacing:8;visible:root.showAdapter && !root.quick
            ShellComboBox {width:parent.width;model:root.service.adapters;textRole:"name";currentIndex:root.service.adapters.findIndex(item=>item.id===root.service.adapter.id);Accessible.name:"Bluetooth adapter";onActivated:index=>root.service.chooseAdapter(root.service.adapters[index].id)}
            Row {
                width:parent.width;spacing:8
                ControlWorkspaceButton {width:(parent.width-8)/2;text:root.service.adapter && root.service.adapter.discoverable?"Stop discoverability":"Discoverable · 3 min";enabled:root.service.enabled && !root.service.actions.locked;onClicked:root.service.actions.request("discoverable",null,!root.service.adapter.discoverable)}
                ControlWorkspaceButton {width:(parent.width-8)/2;text:root.service.adapter && root.service.adapter.pairable?"Stop incoming pairing":"Allow pairing · 3 min";enabled:root.service.enabled && !root.service.actions.locked;onClicked:root.service.actions.request("pairable",null,!root.service.adapter.pairable)}
            }
            BluetoothLabel {text:root.service.discovering && !root.service.scan.owned?"Discovery is active outside this controller. Scan acquires our own session; Stop releases only ours.":"Device state updates automatically. Refresh reads known state; it does not scan."}
        }
        NetworkActionReview {width:parent.width;actions:root.service.actions}
        BluetoothPairingReview {width:parent.width;service:root.service}
        Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
    }
    }
    Item {
        anchors.top:headingViewport.bottom;anchors.topMargin:16;anchors.bottom:footer.top;anchors.bottomMargin:8;width:parent.width
        FocusScrollArea {
            id:list
            width:root.split?Math.round((parent.width-24)*0.49):parent.width;height:parent.height
            visible:root.split || !root.inspecting
            contentHeight:groups.implicitHeight
            ScrollBar.vertical:ShellScrollBar {}
            Column {
                id:groups;width:parent.width;spacing:16
                BluetoothLabel {visible:!root.service.enabled;text:root.service.adapter?"Bluetooth is off. Saved devices can still be renamed or forgotten. Turn it on to connect or scan.":"No Bluetooth adapter is available. Check the adapter connection and BlueZ service."}
                Repeater {
                    model:["connected","paired","nearby","other"]
                    delegate:Column {
                        id:group;required property string modelData;width:groups.width;spacing:4
                        readonly property var ids:root.service.devices.filter(item=>item.group===modelData && root.matches(item)).map(item=>item.id)
                        visible:(root.service.enabled || modelData==="paired" || modelData==="connected") && (ids.length>0 || modelData==="nearby")
                        BluetoothLabel {text:({connected:"CONNECTED",paired:"PAIRED DEVICES",nearby:"AVAILABLE NEARBY",other:"OTHER / UNIDENTIFIED"})[group.modelData]+(group.modelData==="other"?" · "+group.ids.length:"");font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
                        ControlWorkspaceButton {visible:group.modelData==="other";width:parent.width;text:root.showOther?"Hide other devices":"Show other devices";headerControl:true;onClicked:root.showOther=!root.showOther}
                        BluetoothLabel {visible:group.modelData==="nearby" && group.ids.length===0;text:root.service.scan.state==="running"?"Looking for devices. Put the device into pairing mode.":"No recently observed named devices. Choose Scan to look nearby."}
                        Repeater {
                            model:ScriptModel {values:group.modelData!=="other" || root.showOther?group.ids:[]}
                            delegate:BluetoothRow {
                                required property string modelData
                                readonly property var current:root.service.objectFor(modelData)
                                width:groups.width
                                service:root.service;device:current || ({id:modelData,name:"Device unavailable",paired:false,connected:false,blocked:false,battery:null,adapter:""})
                                selected:root.service.selectedDeviceId===modelData
                                onDetailsRequested:root.service.selectDevice(device)
                            }
                        }
                    }
                }
                BluetoothLabel {visible:root.quick && root.service.enabled && root.service.connectedDevices.length===0 && root.service.devices.filter(item=>item.paired).length===0;text:"No paired devices. Open Bluetooth Settings to pair a device."}
            }
        }
        Rectangle {visible:root.split;x:list.width+12;width:1;height:parent.height;color:Config.DirectoryStyle.rule}
        BluetoothInspector {
            objectName:"bluetoothInlineInspector"
            x:root.split?list.width+24:0;width:root.split?parent.width-list.width-24:parent.width;height:parent.height
            visible:root.split || root.inspecting
            service:root.service;audio:root.audio
            onCloseRequested:root.service.selectDevice(null)
            onAudioRequested:root.audioRequested()
        }
    }
    Item {
        id:footer;anchors.bottom:parent.bottom;width:parent.width;height:root.quick?48:0
        ControlWorkspaceButton {anchors.fill:parent;visible:root.quick;text:"Bluetooth Settings";onClicked:root.fullSettingsRequested()}
    }
}
