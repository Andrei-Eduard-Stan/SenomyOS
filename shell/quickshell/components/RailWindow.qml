import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../config" as Config
import "lens" as Lens
import "../services/ScreenLifecycle.js" as Screens

PanelWindow {
    id: root

    required property var metrics
    required property var battery
    required property var audio
    required property var network
    property var deviceInventory: null
    property var inputSettings: null
    property var sessionPolicy: null
    property var desktopSettings: null
    property var accounts: null
    property var calendarService: null
    required property var bluetooth
    required property var media
    required property var notifications
    required property var performance
    required property var insights
    required property var senomy
    required property var power
    required property var uiState
    property var modelData
    readonly property real controlAnchorX: rightRail.x+systemControlsIsland.x+(systemControlsIsland.controlAnchor ? systemControlsIsland.controlAnchor.mapToItem(systemControlsIsland,systemControlsIsland.controlAnchor.width/2,0).x : systemControlsIsland.width/2)
    function quickAnchor(item) {
        // Compact Rails omit some status triggers. IPC/keyboard entry still
        // has a real, visible anchor on the output that owns the request.
        return item && item.visible ? item : systemControlsIsland.controlAnchor;
    }
    function openCommandLens(mode, trigger) {
        if (!uiState.allowInteraction()) return false;
        const sameMode = uiState.lensMode === mode;
        uiState.lensMode = mode;
        if (!sameMode && uiState.activePopup === "lens:" + popupPrefix) return true;
        return uiState.togglePopup("lens", popupPrefix, trigger || null);
    }
    function ownsEscape() {
        return [commandLens,calendar,trayPopup,volumePopup,networkPopup,bluetoothPopup,batteryPopup,notificationCenter,powerPopup].some(p=>p.ownsEscape)
            || performanceDashboard.ownsEscape() || insightsPanel.ownsEscape();
    }
    function interactionState() {
        // Qt maps layer/popup positions using the output origin but omits the
        // native layer offset. QA combines these with compositor layer geometry.
        return {monitor: popupPrefix, visible: visible, qtOriginX:root.contentItem.mapToGlobal(0,0).x, qtOriginY:root.contentItem.mapToGlobal(0,0).y, popups: [commandLens,calendar,trayPopup,volumePopup,networkPopup,bluetoothPopup,batteryPopup,notificationCenter,powerPopup].map(p => ({token:p.popupToken,visible:p.visible,requested:p.requestedOpen,shown:p.cardShown,lease:p.lease,keyboardActive:p.ownsEscape,inputFocused:!!(p.focusTarget && p.focusTarget.activeFocus),qtMappedX:p.visible?p.contentItem.mapToGlobal(0,0).x:null,qtMappedY:p.visible?p.contentItem.mapToGlobal(0,0).y:null,width:p.width,height:p.height}))};
    }
    property bool notificationToastEnabled: false
    property bool machineHoverRequested: false
    property bool machineHoverSuppressed: false
    property bool machineKeyboardRequested: false
    function openSystemDashboard() {
        machineHoverCloseTimer.stop();
        machineHoverSuppressed = true;
        machineKeyboardRequested = false;
        machineHoverRequested = false;
        uiState.showPrimary("performance", popupPrefix, "cpu");
    }

    readonly property var hyprlandMonitor: Hyprland.monitorFor(root.screen)
    readonly property bool narrow: root.screen ? root.screen.width < 1700 : false
    readonly property bool veryNarrow: root.screen ? root.screen.width < 1240 : false
    readonly property bool ultraNarrow: root.screen ? root.screen.width < 820 : false
    readonly property bool microNarrow: root.screen ? root.screen.width < 680 : false
    readonly property int railInset: root.microNarrow ? 6 : Config.Theme.screenInset
    readonly property string popupPrefix: root.screen ? root.screen.name : "unknown"
    readonly property string calendarToken: "calendar:" + popupPrefix
    readonly property string trayToken: "tray:" + popupPrefix
    readonly property string networkToken: "network:" + popupPrefix
    readonly property string batteryToken: "battery:" + popupPrefix
    readonly property string volumeToken: "volume:" + popupPrefix
    readonly property string notificationsToken: "notifications:" + popupPrefix
    readonly property string powerToken: "power:" + popupPrefix

    screen: modelData
    implicitHeight: Config.Theme.railHeight
    color: "transparent"
    // Workspace state is event-driven. Closing a fullscreen client or changing
    // workspaces restores the Rail without a helper process or recovery timer.
    // Reuse the event-refreshed inventory. Native lastIpcObject window states can
    // remain stale across fullscreen/maximize events on the current Hyprland API.
    readonly property bool fullscreenActive: Screens.monitorFullscreen(hyprlandMonitor,
        deviceInventory ? (deviceInventory.error ? [] : deviceInventory.windows) : undefined)
    visible: !fullscreenActive && (!deviceInventory || deviceInventory.railVisible(popupPrefix))
    exclusiveZone: fullscreenActive || (deviceInventory && !deviceInventory.railVisible(popupPrefix)) ? 0 : Config.Theme.railHeight
    Connections {
        target: root.uiState
        function onActivePopupChanged() {
            if(root.uiState.activePopup){root.machineHoverRequested=false;root.machineKeyboardRequested=false;machineHoverCloseTimer.stop();}
        }
    }
    onVisibleChanged: if(!visible && uiState && uiState.activePopup.endsWith(":"+popupPrefix)) {
        uiState.modalCancelRequested();uiState.closePopups(undefined,undefined,true);
    }
    onFullscreenActiveChanged: {
        if (fullscreenActive) {
            machineHoverRequested = false;
            if (uiState.activePopup.endsWith(":" + popupPrefix))
                uiState.closePopups();
            if (uiState.primaryScreen === popupPrefix && uiState.activePrimary !== "control")
                uiState.closePrimary();
        }
    }

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
            item: machineStateIsland
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
        x: root.railInset
        y: 2
        width: implicitWidth
        height: Config.Theme.islandHeight
        monitor: root.hyprlandMonitor
        manager: root.deviceInventory
        capacity: root.veryNarrow ? 1 : 3
    }

    Row {
        id: rightRail
        x: root.width - width - root.railInset
        y: 2
        height: Config.Theme.islandHeight
        spacing: root.microNarrow ? 6 : root.ultraNarrow ? 8 : root.veryNarrow ? 10
            : root.narrow ? 14 : Config.Theme.islandGap

        MachineStateIsland {
            id: machineStateIsland
            parent: root.contentItem
            y: 2
            x: Math.max(workspaceRail.x + workspaceRail.width + 8,
                Math.min((root.width - width) / 2, rightRail.x - width - 8))
            compact: root.veryNarrow
            ultraCompact: root.ultraNarrow
            microCompact: root.microNarrow
            expanded: root.machineHoverRequested
            metrics: root.metrics
            senomy: root.senomy
            performanceOpen: root.uiState.activePrimary === "performance"
                && root.uiState.primaryScreen === root.popupPrefix
            insightsOpen: root.uiState.activePrimary === "insights"
                && root.uiState.primaryScreen === root.popupPrefix
            hoverExpansionEnabled: !root.veryNarrow && !root.machineHoverSuppressed
                && !root.uiState.activePrimary && !root.uiState.activePopup && !root.uiState.modalActive
            onPointerHoveredChanged: {
                if (!pointerHovered) root.machineHoverSuppressed = false;
                if (pointerHovered) machineHoverCloseTimer.stop();
                else machineHoverCloseTimer.restart();
            }
            onHoverExpandRequested: {
                machineHoverCloseTimer.stop();
                root.machineKeyboardRequested = false;
                root.machineHoverRequested = true;
            }
            onToggleExpanded: {
                root.machineHoverSuppressed = true;
                root.machineKeyboardRequested = true;
                machineHoverCloseTimer.stop();
                root.machineHoverRequested = !root.machineHoverRequested;
            }
            onTogglePerformance: root.openSystemDashboard()
            onToggleInsights: {
                root.machineHoverRequested = false;
                root.uiState.togglePrimary("insights", root.popupPrefix, "briefing");
            }
        }

        SystemControlsIsland {
            id: systemControlsIsland
            micro: root.microNarrow
            width: root.microNarrow ? 48 : root.ultraNarrow ? 240 : root.veryNarrow ? 260
                : root.narrow ? 300 : 338
            audio: root.audio
            battery: root.battery
            network: root.network
            trayOpen: root.uiState.activePopup === root.trayToken
            lensOpen: root.uiState.activePopup === "lens:" + root.popupPrefix
            volumeOpen: root.uiState.activePopup === root.volumeToken
            networkOpen: root.uiState.activePopup === root.networkToken
            batteryOpen: root.uiState.activePopup === root.batteryToken
            onToggleLens: root.openCommandLens("apps", systemControlsIsland.lensAnchor)
            onToggleNetwork: root.uiState.togglePopup("network", root.popupPrefix, systemControlsIsland.networkAnchor)
            onToggleBattery: root.uiState.togglePopup("battery", root.popupPrefix, systemControlsIsland.batteryAnchor)
            controlOpen: root.uiState.activePrimary === "control"
                && root.uiState.primaryScreen === root.popupPrefix
            onToggleTray: root.uiState.togglePopup("tray", root.popupPrefix, systemControlsIsland.trayAnchor)
            onToggleVolume: root.uiState.togglePopup("volume", root.popupPrefix, systemControlsIsland.volumeAnchor)
            onOpenSettings: section => root.uiState.showSettings(root.popupPrefix, section)
            onOpenControl: section => root.uiState.togglePrimary("control", root.popupPrefix, root.uiState.controlPath || root.uiState.controlSection, root.uiState.controlMode)
        }

        ClockIsland {
            id: clockIsland
            visible: !root.ultraNarrow
            compact: root.veryNarrow
            width: Math.min(implicitWidth, Math.max(minimumWidth, root.width - 2 * root.railInset - workspaceRail.width - machineStateIsland.width - systemControlsIsland.width - powerIsland.width - 2 * rightRail.spacing - 16))
            notifications: root.notifications
            calendarOpen: root.uiState.activePopup === root.calendarToken
            notificationsOpen: root.uiState.activePopup === root.notificationsToken
            onToggleCalendar: root.uiState.togglePopup("calendar", root.popupPrefix, clockIsland.calendarAnchor)
            onToggleNotifications: root.uiState.togglePopup("notifications", root.popupPrefix, clockIsland.notificationsAnchor)
        }

        PowerIsland {
            id: powerIsland
            width: root.microNarrow ? 44 : root.ultraNarrow ? 56 : root.veryNarrow ? 60 : 64
            powerService: root.power
            panelOpen: root.uiState.activePopup === root.powerToken
            onTogglePower: root.uiState.togglePopup("power", root.popupPrefix, powerIsland.panelAnchor)
        }
    }

    Connections {
        target: root.uiState
        function onActivePrimaryChanged() {
            if (root.uiState.activePrimary) {
                machineHoverCloseTimer.stop();
                root.machineHoverRequested = false;
            }
        }
    }
    Timer {
        id: machineHoverCloseTimer
        interval: 190
        onTriggered: {
            if (!machineStateIsland.pointerHovered && !machineStateOverlay.hovered)
                root.machineHoverRequested = false;
        }
    }

    MachineStateOverlay {
        id: machineStateOverlay
        media: root.media
        targetScreen: root.screen
        anchorCenterX: machineStateIsland.x + machineStateIsland.width / 2
        senomy: root.senomy
        metrics: root.metrics
        requestedOpen: !root.uiState.capturePaused && root.machineHoverRequested
        keyboardRequested: root.machineKeyboardRequested
        onCloseRequested: { root.machineHoverRequested = false; root.machineKeyboardRequested = false; }
        onHoveredChanged: {
            if (hovered && !root.machineHoverSuppressed && !root.uiState.activePrimary) {
                machineHoverCloseTimer.stop();
                root.machineHoverRequested = true;
            } else {
                machineHoverCloseTimer.restart();
            }
        }
        onOpenPerformance: root.openSystemDashboard()
        onOpenInsights: {
            root.machineHoverRequested = false;
            root.uiState.showPrimary("insights", root.popupPrefix, "briefing");
        }
    }

    CalendarPopup {
        id: calendar
        screenName:root.popupPrefix
        calendarService:root.calendarService
        onOpenCalendarRequested: route => root.uiState.showSettings(root.popupPrefix, ["calendar/briefing","calendar/day","calendar/transfer"].includes(route) ? route : "calendar")
        targetScreen: root.screen
        anchorItem: root.quickAnchor(clockIsland.calendarAnchor)
        requestedOpen: !root.uiState.capturePaused && root.uiState.activePopup === root.calendarToken
        coordinator: root.uiState
        popupToken: root.calendarToken
    }

    TrayPopup {
        id: trayPopup
        targetScreen: root.screen
        anchorItem: root.quickAnchor(systemControlsIsland.trayAnchor)
        requestedOpen: !root.uiState.capturePaused && root.uiState.activePopup === root.trayToken
        coordinator: root.uiState
        popupToken: root.trayToken
    }

    VolumePopup {
        id: volumePopup
        targetScreen: root.screen
        anchorItem: root.quickAnchor(systemControlsIsland.volumeAnchor)
        audio: root.audio
        media: root.media
        requestedOpen: !root.uiState.capturePaused && root.uiState.activePopup === root.volumeToken
        onOpenAudioRequested: root.uiState.showSettings(root.popupPrefix, "audio")
        coordinator: root.uiState
        popupToken: root.volumeToken
    }

    Lens.CommandLensPopup {
        id: commandLens
        targetScreen: root.screen
        anchorItem: root.quickAnchor(systemControlsIsland.lensAnchor)
        coordinator: root.uiState
        popupToken: "lens:"+root.popupPrefix
        requestedOpen: !root.uiState.capturePaused && root.uiState.activePopup === popupToken
    }
    NetworkPopup {
        id: networkPopup
        targetScreen: root.screen
        anchorItem: root.quickAnchor(systemControlsIsland.networkAnchor)
        network: root.network
        requestedOpen: !root.uiState.capturePaused && root.uiState.activePopup === root.networkToken
        coordinator: root.uiState
        popupToken: root.networkToken
        onOpenSettingsRequested: route => root.uiState.showSettings(root.popupPrefix, route)
    }
    BluetoothPopup {
        id:bluetoothPopup
        targetScreen:root.screen
        anchorItem:root.quickAnchor(systemControlsIsland.controlAnchor)
        bluetooth:root.bluetooth
        requestedOpen:!root.uiState.capturePaused && root.uiState.activePopup === "bluetooth:"+root.popupPrefix
        coordinator:root.uiState
        popupToken:"bluetooth:"+root.popupPrefix
        onOpenSettingsRequested:root.uiState.showSettings(root.popupPrefix,"devices/bluetooth")
    }
    BatteryPopup {
        id: batteryPopup
        targetScreen: root.screen
        anchorItem: root.quickAnchor(systemControlsIsland.batteryAnchor)
        battery: root.battery
        requestedOpen: !root.uiState.capturePaused && root.uiState.activePopup === root.batteryToken
        coordinator: root.uiState
        popupToken: root.batteryToken
        onOpenSettingsRequested: route => root.uiState.showSettings(root.popupPrefix, route)
        onOpenSessionRequested: root.uiState.togglePopup("power",root.popupPrefix)
    }

    NotificationCenter {
        id: notificationCenter
        onOpenHistoryRequested: root.uiState.showPrimary("insights", root.popupPrefix, "notifications")
        clearContext: root.notificationsToken
        targetScreen: root.screen
        anchorItem: root.quickAnchor(clockIsland.notificationsAnchor)
        notifications: root.notifications
        requestedOpen: !root.uiState.capturePaused && root.uiState.activePopup === root.notificationsToken
        coordinator: root.uiState
        popupToken: root.notificationsToken
    }

    PowerPopup {
        id: powerPopup
        targetScreen: root.screen
        anchorItem: root.quickAnchor(powerIsland.panelAnchor)
        powerService: root.power
        requestedOpen: !root.uiState.capturePaused && root.uiState.activePopup === root.powerToken
        coordinator: root.uiState
        popupToken: root.powerToken
    }

    PerformanceDashboard {
        id: performanceDashboard
        targetScreen: root.screen
        anchorCenterX: machineStateIsland.x + machineStateIsland.width / 2
        state: root.uiState
        performance: root.performance
        insights: root.insights
        metrics: root.metrics
        battery: root.battery
        network: root.network
    }

    InsightsPanel {
        id: insightsPanel
        targetScreen: root.screen
        anchorCenterX: machineStateIsland.x + machineStateIsland.width / 2
        state: root.uiState
        insights: root.insights
        senomy: root.senomy
        notifications: root.notifications
        battery: root.battery
        network: root.network
        media: root.media
        metrics: root.metrics
    }

    NotificationToast {
        targetScreen: root.screen
        notifications: root.notifications
        placementEnabled: root.notificationToastEnabled
    }


}
