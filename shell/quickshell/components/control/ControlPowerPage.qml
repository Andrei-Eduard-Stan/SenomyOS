import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import ".."
import "../../config" as Config

FocusScrollArea {
    id: root
    required property var battery
    property bool compact: false
    property string part: "overview"
    property bool diagnosticsExpanded: false
    readonly property var energy: root.battery.energy || null
    readonly property var diagnostics: energy ? energy.diagnostics : ({})
    Connections {
        target: root.battery.care || null
        function onActionStateChanged() { if (root.battery.care.actionState === "pending") root.contentY = 0; }
    }
    signal destinationRequested(string id)
    function valueOrUnknown(value, suffix) { return value !== null && value !== undefined && Number.isFinite(Number(value)) && Number(value) >= 0 ? Math.round(Number(value) * 10) / 10 + suffix : "Unavailable"; }

    ScrollBar.vertical: ShellScrollBar {}

    contentHeight: powerColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Column {
        id: powerColumn
        width: parent.width
        spacing: 12
        SelectionActionReview {
            width: parent.width
            actions: root.battery.selectionActions
        }
        SelectionActionReview {
            width: parent.width
            visible: !!root.battery.care && root.battery.care.actionState !== "idle"
            actions: root.battery.care || root.battery.selectionActions
        }
        PerformanceWorkspaceFacts {
            width:parent.width
            rows:[{label:"Charge",value:root.battery.available?root.battery.label:"Unavailable",detail:root.battery.detail || "",numeric:true},{label:root.battery.charging?"Time to full":"Time remaining",value:root.battery.available?root.battery.timeLabel:"Unavailable",detail:root.battery.available?root.battery.onBattery?"On battery":"External power":"",numeric:true}]
        }
        ControlRouteTiles {
            width: parent.width
            visible: root.part === "overview"
            entries: [
                {
                    id: "power/batteries",
                    label: "BATTERY PACKS",
                    detail: "Inspect each battery"
                },
                {
                    id: "power/profiles",
                    label: "POWER PROFILES",
                    detail: "Review an energy profile change"
                }
            ]
            onActivated: id => root.destinationRequested(id)
        }
        Column {
            width: parent.width
            spacing: 12
            visible: root.part === "batteries"
            Text {
                x:Config.DirectoryStyle.controlInset
                width: parent.width-2*x
                wrapMode: Text.WordWrap
                text: "BATTERY PACKS // UPOWER"
                color: Config.Theme.dim
                font.family: Config.DirectoryStyle.bodyFont
                font.pixelSize:Config.DirectoryStyle.detailSize
            }
            Repeater {
                model: root.battery.batteries
                delegate: DashboardCard {
                    required property var modelData
                    width: parent.width
                    title: modelData.model || modelData.nativePath || "BATTERY PACK"
                    value: root.valueOrUnknown(modelData.percentage * 100, "%")
                    detail: UPowerDeviceState.toString(modelData.state) + " · " + root.valueOrUnknown(modelData.energy, "") + " / " + root.valueOrUnknown(modelData.energyCapacity, " Wh") + " · reported rate " + root.valueOrUnknown(modelData.changeRate, " W")
                }
            }
            BatteryCareEditor {
                width: parent.width
                visible: !!root.battery.care
                care: root.battery.care
            }
        }
        Column {
            width: parent.width
            spacing: 12
            visible: root.part === "profiles"
            Text {
                x:Config.DirectoryStyle.controlInset
                width: parent.width-2*x
                wrapMode: Text.WordWrap
                text: "POWER PROFILE"
                color: Config.Theme.dim
                font.family: Config.DirectoryStyle.bodyFont
                font.pixelSize:Config.DirectoryStyle.detailSize
            }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: [
                        {
                            label: "POWER SAVER",
                            profile: PowerProfile.PowerSaver
                        },
                        {
                            label: "BALANCED",
                            profile: PowerProfile.Balanced
                        },
                        {
                            label: "PERFORMANCE",
                            profile: PowerProfile.Performance
                        }
                    ]
                    delegate: ControlWorkspaceButton {
                        required property var modelData
                        objectName: "control-power-profile-" + modelData.profile
                        width: parent.width < 450 ? parent.width : Math.floor((parent.width - 16) / 3)
                        text: modelData.label.charAt(0)+modelData.label.slice(1).toLowerCase()+(active?" · current":"")
                        Accessible.checkable:true
                        Accessible.checked:active
                        opacity:enabled || active?1:0.42
                        active: root.energy ? root.energy.profile !== "" && root.battery.powerProfile === modelData.profile : root.battery.powerProfileAvailable && root.battery.powerProfile === modelData.profile
                        enabled: !root.battery.selectionActions.locked && root.battery.selectionOptions("profile").indexOf(modelData.profile) >= 0 && root.battery.powerProfile !== modelData.profile
                        onClicked: if (root.battery.setPowerProfile(modelData.profile))
                            root.contentY = 0
                    }
                }
            }
            Text {
                x:Config.DirectoryStyle.controlInset
                width: parent.width-2*x
                text: root.energy && root.energy.profile ? "Current profile: " + root.battery.powerProfileName + " · " + root.energy.backend.kind + (root.battery.powerProfileAvailable ? "" : " · " + (root.energy.error || root.energy.backend.reason || "Changes unavailable")) : root.energy ? root.energy.error || root.energy.backend.reason || "Checking power-policy owner…" : root.battery.powerProfileAvailable ? "Current profile: " + root.battery.powerProfileName : "Power-policy provider unavailable."
                color: Config.Theme.muted
                font.family: Config.DirectoryStyle.bodyFont
                font.pixelSize:Config.DirectoryStyle.detailSize
                wrapMode: Text.WordWrap
            }
            Text {
                x:Config.DirectoryStyle.controlInset
                width: parent.width-2*x
                text: root.energy ? (root.energy.backend.semantics || "No power preference is saved.") + (root.energy.backend.degraded ? " Degraded: " + root.energy.backend.degraded : "") + " Application holds: " + (root.energy.backend.kind === "tlp" ? "unavailable without tlp-pd" : (root.energy.backend.holds || []).length) : ""
                color: Config.Theme.muted; font.family: Config.DirectoryStyle.bodyFont; font.pixelSize:Config.DirectoryStyle.detailSize; wrapMode: Text.WordWrap
            }
            Repeater {
                model: root.energy ? root.energy.backend.holds || [] : []
                delegate: Text {
                    required property var modelData
                    width: parent.width; wrapMode: Text.WordWrap; color: Config.Theme.muted
                    font.family: Config.DirectoryStyle.bodyFont; font.pixelSize:Config.DirectoryStyle.detailSize
                    text: String(modelData.ApplicationId || "Application") + " · " + String(modelData.Profile || "profile") + " · " + String(modelData.Reason || "Reason not supplied")
                }
            }
        }
        ControlWorkspaceButton {
            width: Math.min(parent.width,Math.ceil(minimumContentWidth));centered:false
            text:"Refresh power status"
            enabled: !!root.energy && !root.energy.busy && !root.battery.selectionActions.locked
            onClicked: root.energy.refresh()
        }
        Text {
            x:Config.DirectoryStyle.controlInset
            width: parent.width-2*x; visible: !root.compact
            text: root.diagnostics.observedAt ? "Read-only diagnostics captured " + new Date(root.diagnostics.observedAt * 1000).toLocaleString() + ". Refresh after external changes." : root.diagnostics.error || "Open Power Settings or refresh to read hardware diagnostics."
            textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: Config.Theme.muted
            font.family: Config.DirectoryStyle.bodyFont; font.pixelSize:Config.DirectoryStyle.detailSize
        }
        ControlWorkspaceButton {
            objectName:"power-diagnostics-toggle"; width:parent.width
            visible:!root.compact && root.part === "overview"
            text:root.diagnosticsExpanded?"Hide hardware and policy diagnostics":"Hardware and policy diagnostics"
            detail:root.diagnosticsExpanded?"Read-only snapshot":"Policy owner, CPU platform and inhibitors"
            wrapLabel:true;wrapDetail:true;active:root.diagnosticsExpanded
            onClicked:root.diagnosticsExpanded=!root.diagnosticsExpanded
        }
        Column {
            width: parent.width; spacing: 12
            visible: !root.compact && root.part === "overview" && root.diagnosticsExpanded
            DashboardCard {
                width: parent.width; title: "POLICY OWNERSHIP"
                implicitHeight: 200; wrapDetail: true
                value: root.energy ? (root.energy.backend.kind || "Unavailable") : "Unavailable"
                detail: root.energy ? "TLP " + (root.energy.snapshot.tlp ? root.energy.snapshot.tlp.version : "unknown") + ". Profile origin: " + (root.energy.snapshot.tlp ? root.energy.snapshot.tlp.mode : "provider managed") + ". No new idle, lid, low-battery or dock automation has been enabled." : "Provider data unavailable."
            }
            DashboardCard {
                width: parent.width; title: "CPU & PLATFORM · READ ONLY"
                implicitHeight: 220; wrapDetail: true
                value: (root.diagnostics.cpus || []).length ? root.diagnostics.cpus[0].driver || "Unavailable" : "Unavailable"
                detail: (root.diagnostics.cpus || []).length ? "Governor: " + root.diagnostics.cpus[0].governor + " · EPP: " + (root.diagnostics.cpus[0].epp || "unavailable") + " · limits " + root.diagnostics.cpus[0].minimumKHz + "–" + root.diagnostics.cpus[0].maximumKHz + " kHz. Platform profile: " + (root.diagnostics.platformProfile || "unavailable") + ". These are distinct policies, not measured speed or power. " + (root.diagnostics.fanControl || "") : "Refresh for detected CPU policies."
            }
            DashboardCard {
                width: parent.width; title: "LOGIND · READ ONLY"
                implicitHeight: 200; wrapDetail: true
                value: root.diagnostics.policy ? "Idle: " + (root.diagnostics.policy.IdleAction || "unavailable") : "Unavailable"
                detail: root.diagnostics.policy ? "Undocked lid: " + (root.diagnostics.policy.HandleLidSwitch || "unavailable") + "; docked: " + (root.diagnostics.policy.HandleLidSwitchDocked || "unavailable") + ". Compositor bindings and inhibitors can affect the outcome. No lid test or policy modification performed. Idle locking is optional; current policy is preserved." : "Logind policy not read."
            }
            Text {
                x:Config.DirectoryStyle.controlInset
                width: parent.width-2*x; wrapMode: Text.WordWrap; color: Config.Theme.muted
                font.family: Config.DirectoryStyle.bodyFont; font.pixelSize:Config.DirectoryStyle.detailSize
                text: "INHIBITORS · " + (root.diagnostics.inhibitors || []).length + " reported. Block and delay apply only to their listed scopes; a delay is not a permanent veto. " + (root.diagnostics.error || "") + " Diagnostics are a snapshot; refresh after external changes."
            }
            Repeater {
                model: root.diagnostics.inhibitors || []
                delegate: DashboardCard {
                    required property var modelData
                    width: parent.width; title: modelData.who + " · " + modelData.mode
                    implicitHeight: 180; wrapDetail: true
                    value: modelData.what
                    detail: modelData.why
                }
            }
        }
    }
}
