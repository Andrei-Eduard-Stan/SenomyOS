import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import ".."
import "../../config" as Config

FocusScrollArea {
    id: root
    required property var notifications
    property var metrics:null
    property var state:null
    property var targetScreen:null
    property var sessionPolicy: null
    property var desktopSettings: null
    property string part: "overview"
    signal destinationRequested(string id)

    ScrollBar.vertical: ShellScrollBar {}
    contentHeight: settingsColumn.implicitHeight
    Column {
        id: settingsColumn
        width: parent.width
        spacing: 12
        ControlRouteTiles {
            width: parent.width
            visible: root.part === "overview"
            entries: [
                {id:"settings/about",label:"ABOUT & RECOVERY",detail:"System identity, updates and independent recovery"},
                {
                    id: "settings/notifications",
                    label: "NOTIFICATIONS",
                    detail: "Do Not Disturb and notification status"
                },
                {
                    id: "settings/idle",
                    label: "IDLE & LOCK",
                    detail: "Lock and display-off timeouts"
                },
                {
                    id: "settings/integration",
                    label: "Desktop integration",
                    detail: "Provider availability and remaining task verification"
                }
            ]
            onActivated: id => root.destinationRequested(id)
        }
        Column {
            width:parent.width;spacing:12;visible:root.part==="about"
            DashboardCard {width:parent.width;title:"SENOMYOS";value:"DEVELOPMENT DESKTOP";detail:"Hyprland and Quickshell · SenomyOS is not yet a released operating-system distribution."}
            DashboardCard {width:parent.width;title:"KERNEL";value:root.metrics && root.metrics.kernelRelease || "Unavailable";detail:root.metrics && root.metrics.hostModel || "Device model unavailable"}
            ControlWorkspaceButton {width:parent.width;text:"UPDATES & MAINTENANCE";enabled:!!root.state && !!root.targetScreen;onClicked:root.state.showPrimary("insights",root.targetScreen.name,"updates")}
            ControlWorkspaceButton {width:parent.width;text:"SYSTEM DIAGNOSTICS";enabled:!!root.state && !!root.targetScreen;onClicked:root.state.showPrimary("insights",root.targetScreen.name,"diagnostics")}
            Text {
                width:parent.width;text:"Recovery: choose Senomy Recovery at login, or use a TTY to inspect journalctl --user -u senomy-quickshell.service and run senomy-shell restart after correcting the source. Boot-theme activation remains gated on verified cold boot and recovery."
                color:Config.Theme.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WordWrap
            }
        }
        Column {
            width: parent.width
            spacing: 12
            visible: root.part === "overview" || root.part === "notifications"
            ControlWorkspaceButton {
                objectName: "control-dnd"
                width: parent.width
                text: root.notifications.dnd ? "DO NOT DISTURB: ON" : "DO NOT DISTURB: OFF"
                active: root.notifications.dnd
                enabled: root.notifications.serverEnabled
                onClicked: root.notifications.setDnd(!root.notifications.dnd)
            }
            Text {
                x:Config.DirectoryStyle.controlInset
                width: parent.width-2*x
                wrapMode: Text.WordWrap
                text: "Do Not Disturb suppresses toasts. Notification history remains available in Senomy Insights."
                color: Config.DirectoryStyle.muted
                font.family: Config.DirectoryStyle.dataFont
                font.pixelSize:Config.DirectoryStyle.detailSize
            }
        }
        Column {
            width: parent.width
            spacing: 12
            visible: root.part === "idle"
            DashboardCard {
                width: parent.width
                title: "IDLE & LOCK POLICY"
                value: root.sessionPolicy && root.sessionPolicy.available && root.sessionPolicy.configured ? root.sessionPolicy.activationRequired ? "SAVED · ACTIVATION SEPARATE" : "CONFIGURED · RUNTIME UNVERIFIED" : root.sessionPolicy && root.sessionPolicy.available ? "DISABLED BY USER POLICY" : "HYPRIDLE UNAVAILABLE"
                detail: root.sessionPolicy ? (root.sessionPolicy.configured ? "Configured proposal: " : "Proposed values only; no active automatic timers: ") + "lock " + Math.round(root.sessionPolicy.lockSeconds / 60) + " min · display off " + Math.round(root.sessionPolicy.displayOffSeconds / 60) + " min · automatic suspend off. Manual session controls remain separate." : "Policy status unavailable"
                valueColor: root.sessionPolicy && root.sessionPolicy.available && root.sessionPolicy.configured ? Config.Theme.accent : Config.Theme.warning
            }
            Loader {
                width:parent.width
                height:item?item.implicitHeight:0
                active:root.part==="idle" && !!root.sessionPolicy && !root.sessionPolicy.available
                visible:active
                source:active?"../ProviderSetupView.qml":""
                onLoaded:{item.provider="idle";item.label="idle policy support";}
            }
            ControlWorkspaceButton {width:Math.min(220,parent.width);text:"Refresh idle availability";enabled:!!root.sessionPolicy && !root.sessionPolicy.busy;onClicked:root.sessionPolicy.refresh()}
            Grid {
                x:Config.DirectoryStyle.controlInset
                width: parent.width-2*x
                columns:width<480*Config.DirectoryStyle.textScale?1:2
                columnSpacing:20;rowSpacing:12
                Column {
                    width:parent.columns===1?parent.width:(parent.width-parent.columnSpacing)/2
                    spacing: 4
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Lock after (minutes)"
                        color:Config.DirectoryStyle.ink
                        font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize
                    }
                    ShellSpinBox {
                        id: idleLockMinutes
                        objectName: "control-lock-timeout"
                        width:Math.min(parent.width,180)
                        from: 1
                        to: 60
                        editable: true
                        value: root.sessionPolicy ? Math.round(root.sessionPolicy.lockSeconds / 60) : 5
                        enabled: root.sessionPolicy && !root.sessionPolicy.busy
                        Accessible.name: "Idle lock timeout in minutes"
                    }
                }
                Column {
                    width:parent.columns===1?parent.width:(parent.width-parent.columnSpacing)/2
                    spacing: 4
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Display off after (minutes)"
                        color:Config.DirectoryStyle.ink
                        font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize
                    }
                    ShellSpinBox {
                        id: idleDisplayMinutes
                        objectName: "control-display-timeout"
                        width:Math.min(parent.width,180)
                        from: 2
                        to: 120
                        editable: true
                        value: root.sessionPolicy ? Math.round(root.sessionPolicy.displayOffSeconds / 60) : 10
                        enabled: root.sessionPolicy && !root.sessionPolicy.busy
                        Accessible.name: "Idle display-off timeout in minutes"
                    }
                }
            }
            ControlWorkspaceButton {
                width:Math.min(parent.width,Math.ceil(minimumContentWidth));centered:false
                text:root.sessionPolicy && root.sessionPolicy.busy?"Saving idle policy…":"Save idle policy"
                enabled: root.sessionPolicy && !root.sessionPolicy.busy && idleDisplayMinutes.value > idleLockMinutes.value
                onClicked: root.sessionPolicy.apply(idleLockMinutes.value, idleDisplayMinutes.value, lidAction.currentIndex === 1 ? "none" : "lock")
            }
            ShellComboBox {
                id: lidAction
                width: parent.width
                model: ["Lock session on lid close", "No additional shell action"]
                currentIndex: root.sessionPolicy && root.sessionPolicy.lidAction === "none" ? 1 : 0
                enabled: root.sessionPolicy && root.sessionPolicy.lidAvailable && !root.sessionPolicy.busy
                Accessible.name: "Lid close shell action"
            }
            Text {
                x:Config.DirectoryStyle.controlInset
                width: parent.width-2*x
                text: root.sessionPolicy && root.sessionPolicy.lidAvailable ? "Lid switch detected. This controls only SenomyOS's additional shell action; system power policy remains separate." : "No lid switch is currently reported. Lid-specific controls are unavailable."
                color: root.sessionPolicy && root.sessionPolicy.lidAvailable ? Config.Theme.muted : Config.Theme.warning
                font.family: Config.DirectoryStyle.bodyFont
                font.pixelSize:Config.DirectoryStyle.detailSize
                wrapMode: Text.WordWrap
            }
            Text {
                x:Config.DirectoryStyle.controlInset
                width: parent.width-2*x
                visible: root.sessionPolicy && (root.sessionPolicy.message.length > 0 || root.sessionPolicy.error.length > 0)
                text: root.sessionPolicy ? root.sessionPolicy.error || root.sessionPolicy.message : ""
                color: root.sessionPolicy && root.sessionPolicy.error.length > 0 ? Config.Theme.danger : Config.Theme.muted
                font.family: Config.DirectoryStyle.bodyFont
                font.pixelSize:Config.DirectoryStyle.detailSize
                wrapMode: Text.WordWrap
            }
            Text {
                x:Config.DirectoryStyle.controlInset
                width: parent.width-2*x
                text: "Saving updates the idle policy. A service restart may be required to apply it; automatic suspend stays disabled."
                color: Config.Theme.dim
                font.family: Config.DirectoryStyle.bodyFont
                font.pixelSize:Config.DirectoryStyle.detailSize
                wrapMode: Text.WordWrap
            }
        }
        Column {
            width: parent.width
            spacing: 12
            visible: root.part === "integration"
            Loader {
                width: parent.width
                active: root.desktopSettings !== null
                sourceComponent: DesktopCapabilitiesView {
                    settings: root.desktopSettings
                    onDestinationRequested:id=>root.destinationRequested(id)
                }
            }
            DashboardCard {
                width: parent.width
                title: "SHELL MODE"
                value: "QUICKSHELL V2"
                detail: "Quickshell runs the desktop shell. Recovery uses the independent Senomy Recovery login session or a TTY."
            }
            DashboardCard {
                width: parent.width
                title: "NOTIFICATIONS"
                value: root.notifications.serverEnabled ? "NATIVE OWNER" : "UNAVAILABLE"
                detail: root.notifications.ownershipMessage || "Ownership is exclusive and controlled by the shell selector."
            }
        }
    }
}
