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
    property var modelData

    readonly property var hyprlandMonitor: Hyprland.monitorFor(root.screen)
    readonly property bool narrow: root.screen ? root.screen.width < 1600 : false
    readonly property bool veryNarrow: root.screen ? root.screen.width < 1180 : false

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
        capacity: root.narrow ? 3 : 4
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
        }

        ClockIsland {
            id: clockIsland
            calendarOpen: calendar.requestedOpen
            onCalendarOpenChanged: calendar.requestedOpen = calendarOpen
        }

        PowerIsland { id: powerIsland }
    }

    CalendarPopup {
        id: calendar
        anchorItem: clockIsland
        onRequestedOpenChanged: {
            if (clockIsland.calendarOpen !== requestedOpen)
                clockIsland.calendarOpen = requestedOpen;
        }
    }

}
