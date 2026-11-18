import QtQuick
import QtQuick.Controls
import ".."
import "../bluetooth" as BluetoothUi
import "../../config" as Config

FocusScrollArea {
    id: root
    property var inventory: null
    required property var bluetooth
    required property var network
    required property var battery
    required property var audio
    property string part: "overview"
    property bool fullSettings:false
    property string deviceKey: ""
    signal destinationRequested(string id)
    signal monitorSelected(string name)
    readonly property var snapshot: inventory ? inventory.snapshot || {} : {}
    onPartChanged:contentY=0
    contentHeight: part === "bluetooth" ? height : body.implicitHeight
    Loader {
        width:root.width;height:root.height;active:root.part === "bluetooth"
        sourceComponent:BluetoothUi.BluetoothPage {service:root.bluetooth;audio:root.audio;full:root.fullSettings;onAudioRequested:root.destinationRequested("audio/devices")}
    }
    ScrollBar.vertical: ShellScrollBar {}
    Column {
        id: body
        visible:root.part !== "bluetooth"
        width: parent.width
        spacing: 12
        ControlRouteTiles {
            width: parent.width
            visible: root.part === "overview"
            entries: [
                {
                    id: "devices/displays",
                    label: "DISPLAYS",
                    detail: "Monitor layout and configuration"
                },
                {
                    id: "devices/bluetooth",
                    label: "BLUETOOTH",
                    detail: "Discover and connect devices"
                },
                {
                    id: "devices/inputs",
                    label: "INPUT DEVICES",
                    detail: "Inspect keyboards, pointers and touch"
                },
                {
                    id: "devices/audio",
                    label: "AUDIO ENDPOINTS",
                    detail: "Open sound device settings"
                },
                {
                    id: "devices/network",
                    label: "NETWORK INTERFACES",
                    detail: "Inspect managed adapters"
                },
                {
                    id: "devices/batteries",
                    label: "BATTERIES",
                    detail: "Inspect battery packs"
                }
            ]
            onActivated: id => root.destinationRequested(id)
        }
        Text {
            x:Config.DirectoryStyle.controlInset
            width: parent.width-2*x
            visible: root.part === "inputs" || root.part === "displays"
            text: root.inventory ? (root.inventory.error || (root.inventory.loading ? "Refreshing devices…" : "Reported device inventory; available controls are shown below.")) : "Device inventory unavailable"
            wrapMode: Text.WordWrap
            color: Config.DirectoryStyle.muted
            font.family: Config.DirectoryStyle.dataFont
            font.pixelSize:Config.DirectoryStyle.detailSize
        }
        Loader {
            width: parent.width
            active: root.part === "displays" && !!root.inventory && !!root.inventory.displayActions
            visible:active
            height:active?implicitHeight:0
            sourceComponent: Column {
                width: parent.width
                spacing: 12
                DisplaySettings {
                    width: parent.width
                    inventory: root.inventory
                    selectedName: root.deviceKey
                    onSelectionRequested: name => root.monitorSelected(name)
                }

            }
        }
        Column {
            width: parent.width
            visible: root.part === "inputs"
            spacing: 12
            ControlWorkspaceButton {
                width:Math.min(parent.width,Math.ceil(minimumContentWidth));centered:false
                text:"Keyboard & pointer settings ›"
                onClicked: root.destinationRequested("input")
            }
            ControlInventoryList {
                width: parent.width
                items: (root.snapshot.inputs || {}).items || []
                selectedKey: root.deviceKey
            }
        }
        Column {
            width: parent.width
            visible: root.part === "audio"
            spacing: 12
            DashboardCard {
                width: parent.width
                title: "AUDIO ENDPOINTS"
                value: root.audio.outputNodes.length + " OUTPUT / " + root.audio.inputNodes.length + " INPUT"
                detail: root.audio.outputName
            }
            ControlWorkspaceButton {
                width: parent.width
                text: "OPEN AUDIO DEVICE SETTINGS"
                onClicked: root.destinationRequested("audio/devices")
            }
        }
        Column {
            width: parent.width
            visible: root.part === "network"
            spacing: 12
            DashboardCard {
                width: parent.width
                title: "NETWORK INTERFACES"
                value: root.network.managedDevices.length + " MANAGED"
                detail: root.network.primaryDevice || "No active primary interface"
            }
            Repeater {
                model: root.network.managedDevices
                delegate: ControlWorkspaceButton {
                    required property var modelData
                    width: body.width
                    text: modelData.interface || modelData.name || "Network adapter"
                    detail: "Manage connections in Network"
                    onClicked: root.destinationRequested("network")
                }
            }
            ControlWorkspaceButton {
                width: parent.width
                text: "OPEN NETWORK SETTINGS"
                onClicked: root.destinationRequested("network")
            }
        }
        Column {
            width: parent.width
            visible: root.part === "batteries"
            spacing: 12
            DashboardCard {
                width: parent.width
                title: "BATTERY PACKS"
                value: root.battery.count + " PRESENT"
                detail: root.battery.detail
            }
            ControlWorkspaceButton {
                width: parent.width
                text: "OPEN BATTERY PACK DETAILS"
                onClicked: root.destinationRequested("power/batteries")
            }
        }
    }
}
