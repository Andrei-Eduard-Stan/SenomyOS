import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import "../config" as Config

PrimarySurfaceWindow {
    id: root

    required property var state
    required property var metrics
    required property var audio
    required property var network
    required property var bluetooth
    required property var battery
    required property var media
    required property var notifications
    required property var senomy

    requestedOpen: state.activePrimary === "control"
        && state.primaryScreen === (targetScreen ? targetScreen.name : "")
    title: "CONTROL CENTRE"
    eyebrow: "CONTEXTUAL SYSTEM CONTROL"
    activeSection: state.controlSection
    preferredWidth: 980
    preferredHeight: 720
    sections: [
        {id: "overview", label: "OVERVIEW"},
        {id: "network", label: "NETWORK"},
        {id: "audio", label: "AUDIO"},
        {id: "power", label: "POWER"},
        {id: "calendar", label: "CALENDAR"},
        {id: "input", label: "INPUT"},
        {id: "devices", label: "DEVICE MANAGEMENT"},
        {id: "apps", label: "APPLICATIONS"},
        {id: "appearance", label: "APPEARANCE"},
        {id: "settings", label: "SETTINGS"}
    ]

    onCloseRequested: state.closePrimary()
    onSectionRequested: section => state.controlSection = section

    function wifiPercent(rawValue) {
        const value = Number(rawValue) || 0;
        return Math.round(value <= 1 ? value * 100 : value);
    }

    Binding {
        target: root.bluetooth
        property: "pageActive"
        value: root.requestedOpen && root.state.controlSection === "devices"
    }
    Component.onDestruction: root.bluetooth.pageActive = false

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.state.controlSection) {
            case "network": return networkPage;
            case "audio": return audioPage;
            case "power": return powerPage;
            case "calendar": return calendarPage;
            case "input": return inputPage;
            case "devices": return devicesPage;
            case "apps": return appsPage;
            case "appearance": return appearancePage;
            case "settings": return settingsPage;
            default: return overviewPage;
            }
        }
    }

    Component {
        id: overviewPage
        Flickable {
            contentHeight: overviewColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: overviewColumn
                width: parent.width
                spacing: 14
                Text {
                    width: parent.width
                    text: "SYSTEM OVERVIEW // " + root.senomy.message
                    color: Config.Theme.accent
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Grid {
                    width: parent.width
                    columns: width < 650 ? 2 : 3
                    columnSpacing: 10
                    rowSpacing: 10
                    Repeater {
                        model: [
                            {title: "CPU", value: Math.round(root.metrics.cpuPercent) + "%", detail: "Level 1 live telemetry"},
                            {title: "MEMORY", value: Math.round(root.metrics.memoryPercent) + "%", detail: root.metrics.uptimeLabel + " uptime"},
                            {title: "NETWORK", value: root.network.label, detail: root.network.detail},
                            {title: "AUDIO", value: root.audio.label, detail: root.audio.outputName},
                            {title: "POWER", value: root.battery.label, detail: root.battery.detail},
                            {title: "MEDIA", value: root.media.playing ? "PLAYING" : "IDLE", detail: root.media.title}
                        ]
                        delegate: SurfaceCard {
                            required property var modelData
                            width: (parent.width - (parent.columns - 1) * 10) / parent.columns
                            title: modelData.title
                            value: modelData.value
                            detail: modelData.detail
                        }
                    }
                }
                Text {
                    text: "QUICK ROUTES"
                    color: Config.Theme.dim
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                }
                Flow {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: [
                            {id: "network", label: "NETWORK"},
                            {id: "audio", label: "AUDIO"},
                            {id: "devices", label: "DEVICES"},
                            {id: "apps", label: "APPLICATIONS"}
                        ]
                        delegate: SurfaceButton {
                            required property var modelData
                            width: 148
                            text: modelData.label
                            onClicked: root.state.controlSection = modelData.id
                        }
                    }
                }
                SurfaceCard {
                    width: parent.width
                    title: "SENOMY STATE"
                    value: root.senomy.state.toUpperCase()
                    detail: root.senomy.message
                    valueColor: root.senomy.state === "critical" ? Config.Theme.danger
                        : root.senomy.state === "warning" ? Config.Theme.warning : Config.Theme.accent
                }
            }
        }
    }

    Component {
        id: networkPage
        Column {
            spacing: 12
            Row {
                width: parent.width
                spacing: 10
                SurfaceCard {
                    width: parent.width - 220
                    title: "ACTIVE CONNECTION"
                    value: root.network.activeConnection || "DISCONNECTED"
                    detail: root.network.detail
                }
                SurfaceButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 210
                    text: root.network.wifiEnabled ? "DISABLE WI-FI" : "ENABLE WI-FI"
                    detail: root.network.connectivityName
                    active: root.network.wifiEnabled
                    enabled: root.network.available && root.network.wifiHardwareEnabled
                    onClicked: root.network.toggleWifi()
                }
            }
            Text {
                text: "AVAILABLE NETWORKS // EVENT-DRIVEN NETWORKMANAGER"
                color: Config.Theme.dim
                font.family: Config.Theme.fontFamily
                font.pixelSize: 8
                font.weight: Font.DemiBold
            }
            ListView {
                width: parent.width
                height: parent.height - 150
                spacing: 7
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.network.sortedWifiNetworks
                delegate: Rectangle {
                    id: networkRow
                    required property var modelData
                    width: ListView.view.width
                    height: 58
                    radius: 14
                    color: Config.Theme.surfaceRaised
                    border.width: 1
                    border.color: modelData.connected ? Config.Theme.accent : Config.Theme.surfaceHover
                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 230
                            Text {
                                width: parent.width
                                text: networkRow.modelData.name || "Hidden network"
                                color: Config.Theme.foreground
                                font.family: Config.Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: root.wifiPercent(networkRow.modelData.signalStrength) + "% · "
                                    + WifiSecurityType.toString(networkRow.modelData.security)
                                    + (networkRow.modelData.known ? " · saved" : "")
                                color: Config.Theme.dim
                                font.family: Config.Theme.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }
                        SurfaceButton {
                            width: 104
                            height: 42
                            text: networkRow.modelData.connected ? "DISCONNECT" : "CONNECT"
                            active: networkRow.modelData.connected
                            enabled: !networkRow.modelData.stateChanging
                            onClicked: {
                                if (!root.network.activate(networkRow.modelData))
                                    root.network.openSecurePrompt(networkRow.modelData);
                            }
                        }
                        SurfaceButton {
                            width: 102
                            height: 42
                            text: networkRow.modelData.known ? "SAVED" : "SECURE ASK"
                            enabled: !networkRow.modelData.connected && !networkRow.modelData.known
                                && networkRow.modelData.security !== WifiSecurityType.Open
                            onClicked: root.network.openSecurePrompt(networkRow.modelData)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: audioPage
        Flickable {
            contentHeight: audioColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: audioColumn
                width: parent.width
                spacing: 12
                SurfaceCard {
                    width: parent.width
                    title: "DEFAULT OUTPUT"
                    value: root.audio.label
                    detail: root.audio.outputName
                }
                Row {
                    width: parent.width
                    spacing: 10
                    SurfaceButton {
                        width: 100
                        text: root.audio.muted ? "UNMUTE" : "MUTE"
                        active: root.audio.muted
                        enabled: root.audio.available
                        onClicked: root.audio.toggleMuted()
                    }
                    Slider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 110
                        from: 0; to: 1; value: root.audio.volume
                        enabled: root.audio.available
                        onMoved: root.audio.setVolume(value)
                    }
                }
                Text { text: "OUTPUT DEVICES"; color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 8 }
                Repeater {
                    model: root.audio.outputNodes
                    delegate: SurfaceButton {
                        required property var modelData
                        width: audioColumn.width
                        text: modelData.description || modelData.nickname || modelData.name || "Audio output"
                        detail: modelData === root.audio.sink ? "CURRENT DEFAULT" : "SELECT OUTPUT"
                        active: modelData === root.audio.sink
                        onClicked: root.audio.selectOutput(modelData)
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Config.Theme.surfaceHover }
                SurfaceCard {
                    width: parent.width
                    title: "DEFAULT INPUT"
                    value: root.audio.inputAvailable ? Math.round(root.audio.inputVolume * 100) + "%" : "UNAVAILABLE"
                    detail: root.audio.inputName
                }
                Row {
                    width: parent.width
                    spacing: 10
                    SurfaceButton {
                        width: 100
                        text: root.audio.inputMuted ? "UNMUTE" : "MUTE"
                        active: root.audio.inputMuted
                        enabled: root.audio.inputAvailable
                        onClicked: root.audio.toggleInputMuted()
                    }
                    Slider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 110
                        from: 0; to: 1; value: root.audio.inputVolume
                        enabled: root.audio.inputAvailable
                        onMoved: root.audio.setInputVolume(value)
                    }
                }
                Text { text: "INPUT DEVICES"; color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 8 }
                Repeater {
                    model: root.audio.inputNodes
                    delegate: SurfaceButton {
                        required property var modelData
                        width: audioColumn.width
                        text: modelData.description || modelData.nickname || modelData.name || "Audio input"
                        detail: modelData === root.audio.source ? "CURRENT DEFAULT" : "SELECT INPUT"
                        active: modelData === root.audio.source
                        onClicked: root.audio.selectInput(modelData)
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Config.Theme.surfaceHover }
                Row {
                    width: parent.width
                    spacing: 8
                    SurfaceButton { width: 72; text: "PREV"; enabled: root.media.available && root.media.selectedPlayer.canGoPrevious; onClicked: root.media.previous() }
                    SurfaceButton { width: 82; text: root.media.playing ? "PAUSE" : "PLAY"; enabled: root.media.available && root.media.selectedPlayer.canTogglePlaying; onClicked: root.media.toggle() }
                    SurfaceButton { width: 72; text: "NEXT"; enabled: root.media.available && root.media.selectedPlayer.canGoNext; onClicked: root.media.next() }
                    SurfaceCard { width: parent.width - 250; height: 80; title: root.media.identity; value: root.media.title; detail: root.media.artist }
                }
            }
        }
    }

    Component {
        id: powerPage
        Column {
            spacing: 12
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 10
                rowSpacing: 10
                SurfaceCard { width: (parent.width - 10) / 2; title: "AGGREGATE"; value: root.battery.label; detail: root.battery.detail }
                SurfaceCard { width: (parent.width - 10) / 2; title: root.battery.charging ? "TIME TO FULL" : "TIME REMAINING"; value: root.battery.timeLabel; detail: root.battery.onBattery ? "ON BATTERY" : "EXTERNAL POWER" }
            }
            Text { text: "BATTERY PACKS // UPOWER"; color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 8 }
            Repeater {
                model: root.battery.batteries
                delegate: SurfaceCard {
                    required property var modelData
                    width: parent.width
                    title: modelData.model || modelData.nativePath || "BATTERY PACK"
                    value: Math.round(modelData.percentage * 100) + "%"
                    detail: (modelData.state ? UPowerDeviceState.toString(modelData.state) : "present")
                        + " · " + Math.round(modelData.energy * 10) / 10 + " / "
                        + Math.round(modelData.energyCapacity * 10) / 10 + " Wh"
                }
            }
            Text { text: "POWER PROFILE"; color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 8 }
            Row {
                width: parent.width
                spacing: 8
                Repeater {
                    model: [
                        {label: "POWER SAVER", profile: PowerProfile.PowerSaver},
                        {label: "BALANCED", profile: PowerProfile.Balanced},
                        {label: "PERFORMANCE", profile: PowerProfile.Performance}
                    ]
                    delegate: SurfaceButton {
                        required property var modelData
                        width: (parent.width - 16) / 3
                        text: modelData.label
                        active: root.battery.powerProfileAvailable && root.battery.powerProfile === modelData.profile
                        enabled: root.battery.powerProfileAvailable
                        onClicked: root.battery.setPowerProfile(modelData.profile)
                    }
                }
            }
            Text {
                width: parent.width
                text: root.battery.powerProfileAvailable
                    ? "Current profile: " + root.battery.powerProfileName
                    : "Power Profiles daemon is not available on this machine; controls are truthfully disabled."
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 9
                wrapMode: Text.WordWrap
            }
        }
    }

    Component {
        id: calendarPage
        Column {
            SystemClock { id: controlClock; precision: SystemClock.Seconds }
            spacing: 14
            SurfaceCard {
                width: parent.width
                height: 150
                title: "LOCAL TIME"
                value: Qt.formatDateTime(controlClock.date, "HH:mm:ss")
                detail: Qt.formatDate(controlClock.date, "dddd, dd MMMM yyyy")
            }
            Text {
                width: parent.width
                text: "The Rail calendar provides month navigation, current-day state, source-monitor anchoring, outside-click dismissal, and Escape dismissal."
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }
    }

    Component {
        id: inputPage
        Column {
            spacing: 12
            SurfaceCard { width: parent.width; title: "AUDIO INPUT"; value: root.audio.inputMuted ? "MUTED" : root.audio.inputAvailable ? "ACTIVE" : "UNAVAILABLE"; detail: root.audio.inputName }
            SurfaceButton { width: parent.width; text: root.audio.inputMuted ? "UNMUTE MICROPHONE" : "MUTE MICROPHONE"; enabled: root.audio.inputAvailable; active: root.audio.inputMuted; onClicked: root.audio.toggleInputMuted() }
            Text {
                width: parent.width
                text: "Keyboard, pointer, and touch device inventory is consolidated under Device Management. Gesture-only actions are not introduced here."
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
            SurfaceButton { width: parent.width; text: "OPEN DEVICE MANAGEMENT"; onClicked: root.state.controlSection = "devices" }
        }
    }

    Component {
        id: devicesPage
        Column {
            spacing: 12
            Row {
                width: parent.width
                spacing: 10
                SurfaceCard { width: parent.width - 220; title: "BLUETOOTH ADAPTER"; value: root.bluetooth.available ? root.bluetooth.enabled ? "ENABLED" : "DISABLED" : "UNAVAILABLE"; detail: root.bluetooth.discovering ? "DISCOVERING" : root.bluetooth.devices.length + " known/visible device(s)" }
                SurfaceButton { anchors.verticalCenter: parent.verticalCenter; width: 210; text: root.bluetooth.enabled ? "DISABLE BLUETOOTH" : "ENABLE BLUETOOTH"; active: root.bluetooth.enabled; enabled: root.bluetooth.available; onClicked: root.bluetooth.setEnabled(!root.bluetooth.enabled) }
            }
            Text { text: "BLUETOOTH DEVICES // DISCOVERY RUNS ONLY ON THIS PAGE"; color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 8 }
            ListView {
                width: parent.width
                height: Math.min(260, contentHeight)
                spacing: 7
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.bluetooth.devices
                delegate: SurfaceButton {
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.name || modelData.deviceName || "Bluetooth device"
                    detail: modelData.connected ? "CONNECTED" : modelData.paired ? "PAIRED" : "AVAILABLE"
                    active: modelData.connected
                    enabled: root.bluetooth.enabled && !modelData.pairing
                    onClicked: root.bluetooth.toggleConnection(modelData)
                }
            }
            Text {
                visible: root.bluetooth.devices.length === 0
                text: root.bluetooth.enabled ? "No Bluetooth devices are currently visible." : "Enable Bluetooth to discover devices."
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 9
            }
            Rectangle { width: parent.width; height: 1; color: Config.Theme.surfaceHover }
            SurfaceCard { width: parent.width; title: "NETWORK DEVICES"; value: root.network.managedDevices.length + " MANAGED"; detail: root.network.primaryDevice || "No active primary device" }
            SurfaceCard { width: parent.width; title: "BATTERIES"; value: root.battery.count + " PRESENT"; detail: root.battery.detail }
            Text { text: "Audio endpoint routing is available on the Audio page."; color: Config.Theme.dim; font.family: Config.Theme.fontFamily; font.pixelSize: 9 }
        }
    }

    Component {
        id: appsPage
        Column {
            spacing: 12
            SurfaceCard { width: parent.width; title: "COMMAND LENS"; value: "EXTERNAL BOUNDARY"; detail: "The deployed SenomyOS Rofi launcher remains the approved launcher." }
            Flow {
                width: parent.width
                spacing: 8
                SurfaceButton { width: 170; text: "APPLICATIONS"; onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/senomy-command-lens", "--mode", "apps"]) }
                SurfaceButton { width: 170; text: "FILES"; onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/senomy-command-lens", "--mode", "files"]) }
                SurfaceButton { width: 170; text: "WINDOWS"; onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/senomy-command-lens", "--mode", "windows"]) }
                SurfaceButton { width: 170; text: "ACTIONS"; onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/senomy-command-lens", "--mode", "actions"]) }
            }
            Text {
                width: parent.width
                text: "Quickshell invokes the installed wrapper directly with fixed arguments. It does not interpolate widget text into a shell command."
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 9
                wrapMode: Text.WordWrap
            }
        }
    }

    Component {
        id: appearancePage
        Column {
            spacing: 12
            SurfaceCard { width: parent.width; title: "APPEARANCE PROFILE"; value: "LUMINOUS RELIQUARY"; detail: "Shared generated QML tokens and frame assets are active." }
            Text {
                width: parent.width
                text: "Milestone 3 intentionally freezes broad visual redesign. Appearance foundations are shared with Eww, while a dedicated shell-wide UI/UX review follows functional parity."
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }
    }

    Component {
        id: settingsPage
        Column {
            spacing: 12
            SurfaceCard { width: parent.width; title: "SHELL MODE"; value: "QUICKSHELL V2"; detail: "Login-time ownership remains Eww until explicit later promotion." }
            SurfaceCard { width: parent.width; title: "NOTIFICATIONS"; value: root.notifications.serverEnabled ? "NATIVE OWNER" : "SWAYNC OWNER"; detail: "Ownership is exclusive and controlled by the shell selector." }
            SurfaceButton { width: parent.width; text: "OPEN COMMAND LENS ACTIONS"; onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/senomy-command-lens", "--mode", "actions"]) }
            Text {
                width: parent.width
                text: "Recovery, shell switching, deployment, and login-default changes remain outside the ordinary Control Centre to prevent accidental system mutation."
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 9
                wrapMode: Text.WordWrap
            }
        }
    }
}
