import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import ".."
import "../../config" as Config

FocusScrollArea {
    id: root
    required property var network
    property string part: "overview"
    property string deviceKey: ""
    signal destinationRequested(string id)
    readonly property bool networkLocked: network.actions.locked || Boolean(network.profiles && network.profiles.actions.locked) || Boolean(network.connectionAttempt && network.connectionAttempt.busy)
    readonly property var connectedWifi: network.connectedWifi !== undefined ? network.connectedWifi : network.sortedWifiNetworks.find(n => n.connected) || null
    readonly property string connectionStatus: !network.available ? network.detail
        : [network.activeConnection ? "Connected" : network.wifiEnabled ? "Not connected" : "Wi-Fi off",
           connectedWifi ? wifiPercent(connectedWifi.signalStrength) + "% signal" : "",
           !network.activeConnection ? "" : network.connectivity === NetworkConnectivity.Full ? "Internet available"
           : network.connectivity === NetworkConnectivity.Portal ? "Sign-in required"
           : network.connectivity === NetworkConnectivity.Limited ? "Limited connectivity"
           : network.activeConnection ? "Internet access unverified" : ""].filter(Boolean).join(" · ")
    function wifiPercent(value) {
        return Math.round((Number(value) || 0) * (value <= 1 ? 100 : 1));
    }

    ScrollBar.vertical: ShellScrollBar {}
    contentHeight: networkColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Column {
        id: networkColumn
        width: parent.width
        spacing: Config.DirectoryStyle.sectionGap
        Column {
            width: parent.width; spacing: Config.DirectoryStyle.controlGap
            Text { x:Config.DirectoryStyle.controlInset;width:parent.width-2*x; text:root.network.activeConnection || (root.network.available ? "No active connection" : "Network unavailable"); textFormat:Text.PlainText; wrapMode:Text.Wrap; color:Config.DirectoryStyle.ink; font.family:Config.DirectoryStyle.bodyFont; font.pixelSize:Config.DirectoryStyle.bodySize+2; font.weight:Font.DemiBold }
            Text { x:Config.DirectoryStyle.controlInset;width:parent.width-2*x; text:root.connectionStatus; textFormat:Text.PlainText; wrapMode:Text.WordWrap; color:Config.DirectoryStyle.muted; font.family:Config.DirectoryStyle.bodyFont; font.pixelSize:Config.DirectoryStyle.detailSize }
            Flow {
                width:parent.width; spacing:Config.DirectoryStyle.controlGap;visible:root.part!=="advanced" && root.part!=="saved"
                ControlWorkspaceButton {
                    objectName:"wifiToggle"; width:Math.min(parent.width, implicitWidth)
                    text:root.network.wifiEnabled ? "Disable Wi-Fi" : "Enable Wi-Fi";centered:false
                    enabled:root.network.available && root.network.wifiHardwareEnabled && !root.networkLocked
                    onClicked:root.network.toggleWifi()
                }
                ControlWorkspaceButton {
                    width:Math.min(parent.width,implicitWidth);visible:!!root.connectedWifi
                    text:"Disconnect";centered:false;enabled:!root.networkLocked
                    onClicked:root.network.activate(root.connectedWifi)
                }
            }
        }
        NetworkActionReview {
            width: parent.width
            actions: root.network.actions
        }
        Text {
            width: parent.width
            visible: Boolean(root.network.connectionAttempt && root.network.connectionAttempt.message.length > 0)
            text: root.network.connectionAttempt ? root.network.connectionAttempt.actionState.toUpperCase() + " // " + root.network.connectionAttempt.message : ""
            textFormat: Text.PlainText
            color: root.network.connectionAttempt && root.network.connectionAttempt.actionState === "failed" ? Config.Theme.warning : Config.Theme.muted
            font.family: Config.Theme.fontFamily
            wrapMode: Text.WordWrap
        }
        ControlWorkspaceButton {
            text:"OPEN NETWORK SIGN-IN";visible:!!(root.network.profiles && root.network.profiles.status && root.network.profiles.status.connectivity==="portal")
            enabled:visible && !!root.network.profiles.status.portalUri && !root.networkLocked
            onClicked:root.network.openPortal()
        }
        Text {width:parent.width;visible:!!root.network.handoffMessage;text:root.network.handoffMessage||"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.Theme.muted;font.family:Config.Theme.fontFamily}
        ControlRouteTiles {
            width: parent.width
            visible: root.part === "overview"
            entries: [
                {
                    id: "network/wifi",
                    label: "WI-FI",
                    detail: ""
                },
                {
                    id: "network/saved",
                    label: "SAVED CONNECTIONS",
                    detail: ""
                },
                {
                    id: "network/advanced",
                    label: "VPN & ADVANCED",
                    detail: ""
                }
            ]
            onActivated: id => root.destinationRequested(id)
        }
        Column {
            width: parent.width
            spacing: 12
            visible: root.part === "wifi"
            Row {
                width:parent.width;spacing:Config.DirectoryStyle.controlGap
                Text {width:Math.max(0,parent.width-refresh.width-parent.spacing);anchors.verticalCenter:parent.verticalCenter;text:root.network.scanning ? "Scanning…" : "Available networks";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;wrapMode:Text.WordWrap}
                ControlWorkspaceButton {
                    id:refresh;objectName:"networkRefresh";width:Math.min(implicitWidth,parent.width*0.45)
                    text:root.network.scanning ? "Scanning…" : "Refresh";centered:false
                    enabled:root.network.available && root.network.wifiEnabled && root.network.wifiHardwareEnabled && !root.network.scanning && !root.networkLocked
                    onClicked:root.network.refreshNetworks()
                }
            }
            Text {
                width:parent.width
                visible:root.network.available && root.network.wifiEnabled && !root.network.scanning && root.network.sortedWifiNetworks.length===0
                text:"No networks found. Refresh to scan."
                textFormat:Text.PlainText;wrapMode:Text.WordWrap
                font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted
            }
            FocusDeviceList {
                id: wifiList
                width: parent.width
                height: Math.min(340, contentHeight)
                spacing: 7
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.network.sortedWifiNetworks.filter(n => n !== root.connectedWifi)
                delegate: NetworkChoiceRow {
                    required property var modelData
                    width:wifiList.width; network:root.network; choice:modelData; locked:root.networkLocked
                }
            }
        }

        Loader {
            width: parent.width
            active: (root.part === "saved" || root.part === "advanced") && root.network.profiles !== undefined && root.network.profiles !== null
            sourceComponent: NetworkProfilesView {
                profiles: root.network.profiles
                part: root.part
                selectedKey: root.deviceKey
            }
        }
        Column {
            width:parent.width;spacing:Config.DirectoryStyle.controlGap
            visible:root.part==="advanced" && root.network.profiles!==undefined
            Row {
                width:parent.width
                Text {leftPadding:Config.DirectoryStyle.controlInset;width:Math.max(1,parent.width-statusRefresh.width);height:statusRefresh.height;verticalAlignment:Text.AlignVCenter;text:"Network interfaces";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize+2;font.weight:Font.DemiBold;wrapMode:Text.WordWrap}
                ControlWorkspaceButton {id:statusRefresh;width:Math.ceil(minimumContentWidth);text:"Refresh";centered:false;enabled:root.network.profiles && !root.network.profiles.busy;onClicked:root.network.profiles.refresh()}
            }
            Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:"Choose an interface to inspect addresses, gateway, DNS and routes.";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
            Repeater {
                model:root.network.profiles && root.network.profiles.status?root.network.profiles.status.devices || []:[]
                delegate:NetworkInterfaceRow {required property var modelData;width:parent.width;device:modelData}
            }
            Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:"Link activation and internet access are separate results. VPNs managed outside NetworkManager stay with their own tools.";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
        }

    }
}
