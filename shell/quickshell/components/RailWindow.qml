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
    required property var power
    required property var uiState
    property var modelData

    readonly property var hyprlandMonitor: Hyprland.monitorFor(root.screen)
    readonly property bool narrow: root.screen ? root.screen.width < 1600 : false
    readonly property bool veryNarrow: root.screen ? root.screen.width < 1180 : false
    readonly property bool ultraNarrow: root.screen ? root.screen.width < 800 : false
    readonly property string popupPrefix: root.screen ? root.screen.name : "unknown"
    readonly property string calendarToken: "calendar:" + popupPrefix
    readonly property string trayToken: "tray:" + popupPrefix

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
            visible: !root.narrow
            width: visible ? 397 : 0
        }

        TelemetryIsland {
            id: telemetryIsland
            visible: !root.veryNarrow
            width: visible ? (root.narrow ? 300 : 392) : 0
            metrics: root.metrics
        }

        SystemControlsIsland {
            id: systemControlsIsland
            audio: root.audio
            battery: root.battery
            network: root.network
            trayOpen: root.uiState.activePopup === root.trayToken
            onToggleTray: root.uiState.activePopup = trayOpen ? "" : root.trayToken
        }

        ClockIsland {
            id: clockIsland
            visible: !root.ultraNarrow
            calendarOpen: root.uiState.activePopup === root.calendarToken
            onToggleCalendar: root.uiState.activePopup = calendarOpen ? "" : root.calendarToken
        }

        PowerIsland {
            id: powerIsland
            powerService: root.power
        }
    }

    CalendarPopup {
        id: calendar
        anchorItem: clockIsland
        requestedOpen: root.uiState.activePopup === root.calendarToken
        onRequestedOpenChanged: if (!requestedOpen && root.uiState.activePopup === root.calendarToken)
            root.uiState.activePopup = ""
    }

    TrayPopup {
        id: trayPopup
        anchorItem: systemControlsIsland.trayAnchor
        requestedOpen: root.uiState.activePopup === root.trayToken
        onRequestedOpenChanged: if (!requestedOpen && root.uiState.activePopup === root.trayToken)
            root.uiState.activePopup = ""
    }

}
