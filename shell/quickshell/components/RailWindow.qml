import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../config" as Config

PanelWindow {
    id: root

    required property var metrics
    required property var battery
    required property var audio
    required property var network
    required property var bluetooth
    required property var media
    required property var notifications
    required property var performance
    required property var insights
    required property var senomy
    required property var power
    required property var uiState
    property var modelData
    property bool notificationToastEnabled: false

    readonly property var hyprlandMonitor: Hyprland.monitorFor(root.screen)
    readonly property bool narrow: root.screen ? root.screen.width < 1600 : false
    readonly property bool veryNarrow: root.screen ? root.screen.width < 1180 : false
    readonly property bool ultraNarrow: root.screen ? root.screen.width < 800 : false
    readonly property string popupPrefix: root.screen ? root.screen.name : "unknown"
    readonly property string calendarToken: "calendar:" + popupPrefix
    readonly property string trayToken: "tray:" + popupPrefix
    readonly property string volumeToken: "volume:" + popupPrefix
    readonly property string notificationsToken: "notifications:" + popupPrefix
    readonly property string powerToken: "power:" + popupPrefix

    screen: modelData
    implicitHeight: Config.Theme.railHeight
    color: "transparent"
    exclusiveZone: Config.Theme.railHeight

    anchors {
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.namespace: "senomy-v2-rail"

    mask: Region {
        Region {
            item: workspaceRail
            radius: 16
        }
        Region {
            item: statusIsland
            radius: 16
        }
        Region {
            item: telemetryIsland
            radius: 16
        }
        Region {
            item: systemControlsIsland
            radius: 16
        }
        Region {
            item: clockIsland
            radius: 16
        }
        Region {
            item: powerIsland
            radius: 16
        }
    }

    WorkspaceRail {
        id: workspaceRail
        x: Config.Theme.screenInset
        y: 4
        width: implicitWidth
        height: Config.Theme.islandHeight
        monitor: root.hyprlandMonitor
        capacity: root.ultraNarrow ? 1 : root.narrow ? 3 : 4
    }

    Row {
        id: rightRail
        x: root.width - width - Config.Theme.screenInset
        y: 4
        height: Config.Theme.islandHeight
        spacing: root.narrow ? 14 : Config.Theme.islandGap

        StatusCompanionIsland {
            id: statusIsland
            width: root.narrow ? 110 : 397
            senomy: root.senomy
            insightsOpen: root.uiState.activePrimary === "insights"
                && root.uiState.primaryScreen === root.popupPrefix
            companionOpen: root.uiState.companionMode !== "closed"
                && root.uiState.companionScreen === root.popupPrefix
            onToggleInsights: root.uiState.togglePrimary("insights", root.popupPrefix, "briefing")
            onToggleCompanion: root.uiState.toggleCompanion(root.popupPrefix)
        }

        TelemetryIsland {
            id: telemetryIsland
            visible: !root.veryNarrow
            width: visible ? (root.narrow ? 300 : 392) : 0
            metrics: root.metrics
            dashboardOpen: root.uiState.activePrimary === "performance"
                && root.uiState.primaryScreen === root.popupPrefix
            onTogglePerformance: root.uiState.togglePrimary("performance", root.popupPrefix, "overview")
        }

        SystemControlsIsland {
            id: systemControlsIsland
            audio: root.audio
            battery: root.battery
            network: root.network
            trayOpen: root.uiState.activePopup === root.trayToken
            volumeOpen: root.uiState.activePopup === root.volumeToken
            controlOpen: root.uiState.activePrimary === "control"
                && root.uiState.primaryScreen === root.popupPrefix
            onToggleTray: root.uiState.togglePopup("tray", root.popupPrefix)
            onToggleVolume: root.uiState.togglePopup("volume", root.popupPrefix)
            onOpenControl: section => root.uiState.showPrimary("control", root.popupPrefix, section)
        }

        ClockIsland {
            id: clockIsland
            visible: !root.ultraNarrow
            notifications: root.notifications
            calendarOpen: root.uiState.activePopup === root.calendarToken
            notificationsOpen: root.uiState.activePopup === root.notificationsToken
            onToggleCalendar: root.uiState.togglePopup("calendar", root.popupPrefix)
            onToggleNotifications: root.uiState.togglePopup("notifications", root.popupPrefix)
        }

        PowerIsland {
            id: powerIsland
            powerService: root.power
            panelOpen: root.uiState.activePopup === root.powerToken
            onTogglePower: root.uiState.togglePopup("power", root.popupPrefix)
        }
    }

    CalendarPopup {
        id: calendar
        anchorItem: clockIsland
        requestedOpen: root.uiState.activePopup === root.calendarToken
        onRequestedOpenChanged: if (!requestedOpen && root.uiState.activePopup === root.calendarToken)
            root.uiState.activePopup = ""
        onDismissRequested: if (root.uiState.activePopup === root.calendarToken)
            root.uiState.activePopup = ""
    }

    TrayPopup {
        id: trayPopup
        anchorItem: systemControlsIsland.trayAnchor
        requestedOpen: root.uiState.activePopup === root.trayToken
        onRequestedOpenChanged: if (!requestedOpen && root.uiState.activePopup === root.trayToken)
            root.uiState.activePopup = ""
        onDismissRequested: if (root.uiState.activePopup === root.trayToken)
            root.uiState.activePopup = ""
    }

    VolumePopup {
        id: volumePopup
        anchorItem: systemControlsIsland.volumeAnchor
        audio: root.audio
        media: root.media
        requestedOpen: root.uiState.activePopup === root.volumeToken
        onRequestedOpenChanged: if (!requestedOpen && root.uiState.activePopup === root.volumeToken)
            root.uiState.activePopup = ""
        onDismissRequested: if (root.uiState.activePopup === root.volumeToken)
            root.uiState.activePopup = ""
    }

    NotificationCenter {
        id: notificationCenter
        anchorItem: clockIsland.notificationsAnchor
        notifications: root.notifications
        requestedOpen: root.uiState.activePopup === root.notificationsToken
        onRequestedOpenChanged: if (!requestedOpen && root.uiState.activePopup === root.notificationsToken)
            root.uiState.activePopup = ""
        onDismissRequested: if (root.uiState.activePopup === root.notificationsToken)
            root.uiState.activePopup = ""
    }

    PowerPopup {
        id: powerPopup
        anchorItem: powerIsland.panelAnchor
        powerService: root.power
        requestedOpen: root.uiState.activePopup === root.powerToken
        onRequestedOpenChanged: if (!requestedOpen && root.uiState.activePopup === root.powerToken)
            root.uiState.activePopup = ""
        onDismissRequested: if (root.uiState.activePopup === root.powerToken)
            root.uiState.activePopup = ""
    }

    ControlCentre {
        targetScreen: root.screen
        state: root.uiState
        metrics: root.metrics
        audio: root.audio
        network: root.network
        bluetooth: root.bluetooth
        battery: root.battery
        media: root.media
        notifications: root.notifications
        senomy: root.senomy
    }

    PerformanceDashboard {
        targetScreen: root.screen
        state: root.uiState
        performance: root.performance
        metrics: root.metrics
        battery: root.battery
        network: root.network
    }

    InsightsPanel {
        targetScreen: root.screen
        state: root.uiState
        insights: root.insights
        senomy: root.senomy
        notifications: root.notifications
        battery: root.battery
        network: root.network
        media: root.media
        metrics: root.metrics
    }

    CompanionPanel {
        targetScreen: root.screen
        state: root.uiState
        senomy: root.senomy
        media: root.media
        battery: root.battery
        network: root.network
        metrics: root.metrics
    }

    NotificationToast {
        targetScreen: root.screen
        notifications: root.notifications
        placementEnabled: root.notificationToastEnabled
    }

}
