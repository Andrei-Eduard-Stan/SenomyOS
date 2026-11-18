import QtQuick
import "audio" as Audio
import "control" as Control
import "ControlDirectory.js" as Directory
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import "../config" as Config

DashboardWindow {
    id: root
    interactionCoordinator: state
    frameKey: "control-center"
    fullSettings: state.controlMode === "full"
    onModeRequested: full => full ? state.showSettings(targetScreen.name, routeId) : state.showPrimary("control", targetScreen.name, routeId)

    required property var state
    required property var metrics
    required property var audio
    required property var network
    readonly property bool networkLocked: network.actions.locked || Boolean(network.profiles && network.profiles.actions.locked) || Boolean(network.connectionAttempt && network.connectionAttempt.busy)
    property var deviceInventory: null
    property var inputSettings: null
    property var sessionPolicy: null
    property var desktopSettings: null
    property var accounts: null
    property var calendarService: null
    required property var bluetooth
    required property var battery
    required property var media
    required property var notifications
    required property var senomy

    Binding {
        target: root.state
        property: "pageModalActive"
        value: !!root.deferredNode || !!(pageLoader.item && (pageLoader.item.review || pageLoader.item.discardReview))
    }
    Connections {
        target: root.state
        function onModalCancelRequested() {
            root.deferredNode = "";
            root.state.deferredPrimary = null;
            if (pageLoader.item && root.state.controlSection === "calendar") {
                pageLoader.item.review = null;
                pageLoader.item.discardReview = false;
            }
        }
    }
    Connections {
        target: root.inputSettings && typeof root.inputSettings.releasePrimaryFocusRequested === "function" ? root.inputSettings : null
        function onReleasePrimaryFocusRequested() {
            if (root.state.activePrimary === "control" && root.state.controlSection === "input")
                root.state.closePrimary();
        }
    }
    requestedOpen: !state.capturePaused && state.activePrimary === "control" && state.primaryScreen === (targetScreen ? targetScreen.name : "")
    replacementOpening: state.activePrimary !== "" && state.activePrimary !== "control"
    title: fullSettings ? "SENOMYOS SETTINGS" : "CONTROL CENTRE"
    eyebrow: (fullSettings ? "SETTINGS / " : "CONTROL CENTRE / ") + (destination ? destination.path : state.controlSection)
    readonly property string routeId: state.controlPath || state.controlSection
    readonly property var destination: Directory.resolve(navigationNodes, routeId)
    readonly property string part: routeId.split("/")[1] || "overview"
    readonly property string deviceKey: destination && destination.deviceKey ? destination.deviceKey : ""
    property string deferredNode: ""
    navigationNodes: Directory.build({
        outputAvailable:audio.available,
        inputAudioAvailable:audio.inputAvailable,
        networkAvailable:network.available,
        inputAvailable:inputSettings?inputSettings.available:false,
        outputs: audio.outputNodes,
        inputs: audio.inputNodes,
        displays: deviceInventory ? deviceInventory.displays : [],
        inputDevices: deviceInventory && deviceInventory.snapshot.inputs ? deviceInventory.snapshot.inputs.items : [],
        defaultRoles:desktopSettings?desktopSettings.defaults:[],
        profiles: network.profiles ? network.profiles.items : []
    })
    activeNode: routeId
    function togglePin() {
        const pins = state.controlPins.slice();
        const i = pins.indexOf(routeId);
        if (i >= 0)
            pins.splice(i, 1);
        else if (pins.length < 8)
            pins.push(routeId);
        state.controlPins = pins;
    }
    readonly property bool pageLoading: pageLoader.status === Loader.Loading
    function dirtyPage() {return pageLoader.item && pageLoader.item.dirty === true;}
    function dirtyAppearance() {
        return pageLoader.item && state.controlSection === "appearance" && pageLoader.item.dirty === true;
    }
    function navigateId(id) {
        if (!state.allowInteraction()) return false;
        const node = Directory.resolve(navigationNodes, id);
        if (!node)
            return false;
        if (dirtyPage() && (node.route !== "appearance" || root.state.controlSection !== "appearance") && node.id !== routeId) {
            deferredNode = id;
            return false;
        }
        if (!state.navigateControl(node.id)) return false;
        Qt.callLater(focusDestination);
        return true;
    }
    function focusDestination() {
        if (!pageLoader.item || !destination)
            return;
        const key = (destination.dynamic && destination.id.startsWith("devices/displays/") ? "control-display-selection" : "") || destination.target || (destination.dynamic ? (destination.route === "audio" ? "control-endpoint-" : "control-device-") + encodeURIComponent(deviceKey) : "");
        function find(item) {
            if (item.objectName === key && key.length)
                return item;
            for (const child of item.children) {
                const found = find(child);
                if (found)
                    return found;
            }
            return null;
        }
        const target = key.length ? find(pageLoader.item) : null;
        if (target && target.visible) {
            function focusable(item) {
                if (item.activeFocusOnTab && item.enabled && item.visible)
                    return item;
                for (const child of item.children) {
                    const found = focusable(child);
                    if (found)
                        return found;
                }
                return null;
            }
            const control = focusable(target);
            if (control)
                control.forceActiveFocus(Qt.TabFocusReason);
        }
    }
    readonly property bool displayContext: routeId === "devices/displays" || routeId.startsWith("devices/displays/")
    readonly property var contextActions: [{
        id: "pin", label: state.controlPins.includes(routeId) ? "Unpin destination" : "Pin destination (session)",
        enabled: state.controlPins.includes(routeId) || state.controlPins.length < 8,
        reason: "Eight destinations are pinned; unpin one first"
    }]
    function connectionEvidence() {
        return {connection: network.activeConnection || null, connectivity: network.connectivityName,
            interface: network.primaryDevice || null, observedAt: new Date().toISOString()};
    }
    function displayEvidence() {
        // Applied inventory only: never serialize the edit draft or stable serial keys.
        return {scope: "Observed display configuration; unsaved edits excluded", observedAt: deviceInventory ? (deviceInventory.snapshot || {}).observed_at || null : null,
            displays: deviceInventory ? deviceInventory.displays.map(d => ({connector:d.name,
                width:d.width,height:d.height,refreshRate:d.refreshRate,scale:d.scale,
                x:d.x,y:d.y,transform:d.transform,disabled:d.disabled,mirrorOf:d.mirrorOf || null})) : []};
    }
    activeSection: state.controlSection
    settingsPreferredWidth:1280
    settingsPreferredHeight:860
    preferredWidth: fullSettings ? 1280 : 1120
    preferredHeight: fullSettings ? 860 : 800
    motif: "controls"
    sections: [
        {
            id: "overview",
            icon: "applications.svg",
            label: "OVERVIEW"
        },
        {
            id: "network",
            icon: "applications.svg",
            label: "NETWORK"
        },
        {
            id: "audio",
            icon: "applications.svg",
            label: "AUDIO"
        },
        {
            id: "power",
            icon: "applications.svg",
            label: "POWER"
        },
        {
            id: "calendar",
            icon: "applications.svg",
            label: "CALENDAR"
        },
        {
            id: "input",
            icon: "applications.svg",
            label: "INPUT"
        },
        {
            id: "devices",
            icon: "applications.svg",
            label: "DEVICE MANAGEMENT"
        },
        {
            id: "apps",
            icon: "applications.svg",
            label: "APPLICATIONS"
        },
        {
            id: "appearance",
            icon: "applications.svg",
            label: "APPEARANCE"
        },
        {
            id: "settings",
            icon: "applications.svg",
            label: "SETTINGS"
        }
    ]

    Shortcut {sequence:"Alt+Left";enabled:root.requestedOpen;onActivated:root.state.travelControl(-1)}
    Shortcut {sequence:"Alt+Right";enabled:root.requestedOpen;onActivated:root.state.travelControl(1)}
    onCloseRequested: state.closePrimary()
    onSectionRequested: section => root.navigateId(section)
    onNodeRequested: node => root.navigateId(node.id)

    function wifiPercent(rawValue) {
        const value = Number(rawValue) || 0;
        return Math.round(value <= 1 ? value * 100 : value);
    }

    Column {
        anchors.fill: parent
        spacing: Config.DirectoryStyle.sectionGap
        Row {
            id: pageHeader
            width: parent.width
            height: Math.max(Config.DirectoryStyle.controlTarget, pageTitle.implicitHeight+8)
            Text {
                id:pageTitle
                leftPadding: Config.DirectoryStyle.controlInset
                width: Math.max(1, parent.width - backButton.width - nextButton.width - contextMenu.width)
                height: pageHeader.height
                verticalAlignment: Text.AlignVCenter
                text: root.navigation.displayLabel(root.destination && root.destination.id.endsWith("/overview") ? (Directory.resolve(root.navigationNodes,root.state.controlSection) || root.destination).label : root.destination ? root.destination.label : root.state.controlSection)
                textFormat: Text.PlainText
                font.family: Config.QuickPanelStyle.headingFont
                font.weight: Font.Normal
                font.pixelSize: Math.round(20*Config.DirectoryStyle.textScale)
                color: Config.DirectoryStyle.ink
                wrapMode:Text.WordWrap
                elide:Text.ElideNone
            }
            QuietButton {
                id:backButton
                width:Config.DirectoryStyle.controlTarget;height:pageHeader.height;iconOnly:true;glyph:"\uf053"
                ToolTip.visible:hovered;ToolTip.text:"Back"
                enabled:root.state.canGoBack
                accessibleLabel:"Back to previous settings page"
                onClicked:root.state.travelControl(-1)
            }
            QuietButton {
                id:nextButton
                width:Config.DirectoryStyle.controlTarget;height:pageHeader.height;iconOnly:true;glyph:"\uf054"
                ToolTip.visible:hovered;ToolTip.text:"Forward"
                enabled:root.state.canGoForward
                accessibleLabel:"Forward to next settings page"
                onClicked:root.state.travelControl(1)
            }
            ContextEvidenceMenu {
                id: contextMenu
                objectName: "control-page-menu"
                ownerActive:root.requestedOpen && !root.state.modalActive
                contextKey: root.routeId
                accessibleLabel: "Actions for " + (root.destination ? root.destination.label : root.routeId)
                // Copy is relevant only to these observed-data contexts. All pages retain session pinning.
                actions: (root.displayContext || root.state.controlSection === "network" ? [{
                    id:"copy", label:root.displayContext ? "Copy display configuration" : "Copy connection details",
                    enabled:clipboardAvailable && (root.displayContext ? !!(root.deviceInventory && !root.deviceInventory.loading && !root.deviceInventory.error && root.deviceInventory.displays.length) : root.network.available),
                    reason:!clipboardAvailable ? "Clipboard unavailable: wl-copy is not installed" : root.displayContext ? "No current display inventory available" : "Network provider unavailable"
                }] : []).concat(root.contextActions)
                allowText: false
                evidenceAvailable: root.displayContext ? !!(root.deviceInventory && !root.deviceInventory.loading && !root.deviceInventory.error && root.deviceInventory.displays.length) : root.network.available
                componentKey: root.displayContext ? "display-configuration" : "network-connection"
                report: root.displayContext ? root.displayEvidence() : root.connectionEvidence()
                onExtraActionRequested: action => { if (action === "pin" && root.state.allowInteraction()) root.togglePin(); }
            }
        }
        Flow {
            width:parent.width;spacing:8
            visible:root.state.controlSection!=="overview" && root.state.controlSection!=="accounts" && root.part!=="overview"
            Repeater {model:((Directory.resolve(root.navigationNodes,root.state.controlSection) || {}).children || []).filter(n=>!n.dynamic)
                QuietButton {required property var modelData;objectName:"control-subview-"+modelData.id;text:root.navigation.displayLabel(modelData.label);active:root.routeId===modelData.id || root.routeId.startsWith(modelData.id+"/");Accessible.checkable:true;Accessible.checked:active;enabled:!root.state.modalActive;width:Math.min(parent.width,implicitWidth);onClicked:root.navigateId(modelData.id)}
            }
        }
        Column {
            width: parent.width
            spacing: 6
            visible: root.deferredNode.length > 0 || !!root.state.deferredPrimary
            Text {
                width: parent.width
                text: "Unsaved "+(root.state.controlSection==="calendar"?"calendar event":root.state.controlSection==="accounts"?"account":"appearance")+" edits. Keep editing, or discard them to continue."
                color: Config.Theme.warning
                font.family: Config.DirectoryStyle.bodyFont
                font.pixelSize: Config.DirectoryStyle.bodySize
                wrapMode: Text.WordWrap
            }
            Row {
                width: parent.width
                spacing: 8
                QuietButton {
                    objectName: "control-keep-editing"
                    width: (parent.width - 8) / 2
                    text: "Keep editing"
                    onClicked: {
                        root.deferredNode = "";
                        root.state.deferredPrimary = null;
                        if(root.calendarService){root.calendarService.requestedEvent=null;root.calendarService.requestedCompose=null;}
                    }
                }
                QuietButton {
                    objectName: "control-discard-continue"
                    width: (parent.width - 8) / 2
                    text: "Discard & continue"
                    onClicked: {
                        if (pageLoader.item && typeof pageLoader.item.load === "function")
                            pageLoader.item.load();
                        root.state.controlDraftDirty = false;
                        const id = root.deferredNode;
                        root.deferredNode = "";
                        if (id.length)
                            root.navigateId(id);
                        else
                            root.state.completeDeferredPrimary();
                    }
                }
            }
        }
        Text {
            width: parent.width
            visible: root.routeId.includes("/item:") && !root.destination
            text: "This device or connection is no longer available. Choose another destination in the directory."
            wrapMode: Text.WordWrap
            color: Config.Theme.warning
            font.family: Config.DirectoryStyle.dataFont
            font.pixelSize: 12
        }
        Text {
            objectName: "control-page-load-status"
            visible: pageLoader.status === Loader.Loading || pageLoader.status === Loader.Error
            width: parent.width
            text: pageLoader.status === Loader.Error ? "This settings page could not be loaded." : "Loading settings…"
            color: Config.DirectoryStyle.muted
            font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.bodySize
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.StaticText; Accessible.name: text
        }
        Loader {
            id: pageLoader
            objectName: "control-page-loader"
            asynchronous: true
            visible: status === Loader.Ready
            active: root.state.activePrimary === "control"
            width: parent.width
            height: Math.max(0, parent.height - y)
            onLoaded: {
                root.revealContent();
                Config.RenderMetrics.pageReady("control-center");
                if (root.requestedOpen && !root.state.modalActive) Qt.callLater(root.focusDestination);
            }
            Connections {
                target: pageLoader.item && ["appearance","calendar","accounts"].includes(root.state.controlSection) ? pageLoader.item : null
                ignoreUnknownSignals: true
                function onDirtyChanged() {
                    if (root.requestedOpen)
                        root.state.controlDraftDirty = root.dirtyPage();
                }
            }
            sourceComponent: {
                switch (root.state.controlSection) {
                case "network":
                    return networkPage;
                case "audio":
                    return audioPage;
                case "power":
                    return powerPage;
                case "calendar":
                    return calendarPage;
                case "input":
                    return inputPage;
                case "devices":
                    return devicesPage;
                case "apps":
                    return appsPage;
                case "appearance":
                    return appearancePage;
                case "accounts":
                    return accountsPage;
                case "settings":
                    return settingsPage;
                default:
                    return overviewPage;
                }
            }
        }
    }

    Component {
        id: overviewPage
        Control.ControlOverview {
            state: root.state
            metrics: root.metrics
            network: root.network
            audio: root.audio
            battery: root.battery
            bluetooth: root.bluetooth
            notifications: root.notifications
            senomy: root.senomy
            media: root.media
            pinnedEntries: root.state.controlPins.map(id => Directory.resolve(root.navigationNodes, id)).filter(node => node !== null)
            onDestinationRequested: route => root.navigateId(route)
            onSettingsRequested: route => root.state.showSettings(root.targetScreen.name, route)
            onPrimaryRequested: (surface, route) => root.state.showPrimary(surface, root.targetScreen.name, route)
        }
    }

    Component {
        id: networkPage
        Control.ControlNetworkPage {
            network: root.network
            part: root.part
            deviceKey: root.deviceKey
            onDestinationRequested: id => root.navigateId(id)
        }
    }

    Component {
        id: audioPage
        Audio.AudioPanel {
            audio: root.audio
            media: root.media
            directoryNavigation: true
            route: root.part
            recordingMode: root.routeId === "audio/mixer/recording"
            onDirectionRequested: recording => root.navigateId(recording ? "audio/mixer/recording" : "audio/mixer/playback")
            onDeviceManagementRequested: root.navigateId("devices/bluetooth")
        }
    }

    Component {
        id: powerPage
        Control.ControlPowerPage {
            battery: root.battery
            part: root.part
            onDestinationRequested: id => root.navigateId(id)
        }
    }

    Component {
        id: calendarPage
        Control.ControlCalendarPage {service:root.calendarService;part:root.part;onRouteRequested:route=>root.navigateId(route)}
    }

    Component {
        id: inputPage
        Control.ControlInputPage {
            inputSettings: root.inputSettings
            part: root.part
            onDestinationRequested: id => root.navigateId(id)
        }
    }

    Component {
        id: devicesPage
        Control.ControlDevicesPage {
            fullSettings:root.fullSettings
            inventory: root.deviceInventory
            audio: root.audio
            bluetooth: root.bluetooth
            network: root.network
            battery: root.battery
            part: root.part
            deviceKey: root.deviceKey
            onMonitorSelected: name => { root.state.controlPath="devices/displays/item:"+encodeURIComponent(name); }
            onDestinationRequested: id => root.navigateId(id)
        }
    }

    Component {
        id: appsPage
        Control.ControlApplicationsPage {
            desktopSettings: root.desktopSettings
            deviceKey:root.deviceKey
            part: root.part
            onDestinationRequested: id => root.navigateId(id)
        }
    }

    Component {
        id: appearancePage
        AppearanceSettings {
            part: root.part
        }
    }

    Component {
        id: accountsPage
        Control.ControlAccountsPage {service:root.accounts}
    }

    Component {
        id: settingsPage
        Control.ControlSettingsPage {
            metrics:root.metrics
            state:root.state
            targetScreen:root.targetScreen
            notifications: root.notifications
            sessionPolicy: root.sessionPolicy
            desktopSettings: root.desktopSettings
            part: root.part
            onDestinationRequested: id => root.navigateId(id)
        }
    }
}
