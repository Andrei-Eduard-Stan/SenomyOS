import QtQuick
import Quickshell
import Quickshell.Wayland
import "../config" as Config

PanelWindow {
    id: root

    required property var targetScreen
    required property var state
    required property var senomy
    required property var media
    required property var battery
    required property var network
    required property var metrics

    readonly property bool onThisScreen: state.companionScreen === (targetScreen ? targetScreen.name : "")
    readonly property bool compact: state.companionMode === "compact"
    readonly property bool expanded: state.companionMode === "expanded"

    screen: targetScreen
    visible: onThisScreen && state.companionMode !== "closed"
    implicitWidth: compact ? 190 : 390
    implicitHeight: compact ? 280 : Math.min(680, targetScreen ? targetScreen.height - Config.Theme.railHeight - 36 : 680)
    color: "transparent"
    exclusiveZone: 0
    focusable: true

    anchors {
        left: state.companionDock === "left"
        right: state.companionDock !== "left"
        bottom: true
    }
    margins {
        left: Config.Theme.screenInset
        right: Config.Theme.screenInset
        bottom: Config.Theme.railHeight + 12
    }

    WlrLayershell.namespace: "senomy-v2-companion"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region {
        Region { item: frame; radius: 26 }
    }

    Timer {
        id: collapseTimer
        interval: 30000
        running: root.expanded && !root.state.companionPinned
        onTriggered: root.state.setCompanionMode("compact", root.targetScreen.name)
    }

    HoverHandler {
        onHoveredChanged: if (hovered && collapseTimer.running) collapseTimer.restart()
    }

    SenomyFrame {
        id: frame
        anchors.fill: parent
        tier: "standard"
        motif: "identity"
        active: true

        Column {
            anchors.fill: parent
            spacing: 11

            Row {
                width: parent.width
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (root.compact ? 116 : 232)
                    text: root.compact ? "SENO" : "SENOMY // LOCAL COMPANION"
                    color: Config.Theme.accent
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                SurfaceButton {
                    visible: !root.compact
                    width: 52
                    height: 34
                    text: root.state.companionPinned ? "UNPIN" : "PIN"
                    active: root.state.companionPinned
                    onClicked: root.state.companionPinned = !root.state.companionPinned
                }
                SurfaceButton {
                    visible: !root.compact
                    width: 52
                    height: 34
                    text: root.state.companionDock === "left" ? "RIGHT" : "LEFT"
                    onClicked: root.state.companionDock = root.state.companionDock === "left" ? "right" : "left"
                }
                SurfaceButton {
                    width: 52
                    height: 34
                    text: root.compact ? "OPEN" : "MIN"
                    onClicked: root.state.setCompanionMode(root.compact ? "expanded" : "compact", root.targetScreen.name)
                }
                SurfaceButton {
                    width: 52
                    height: 34
                    text: "CLOSE"
                    onClicked: root.state.setCompanionMode("closed", root.targetScreen.name)
                }
            }

            Rectangle {
                width: parent.width
                height: root.compact ? 150 : 300
                radius: 22
                color: Config.Theme.surfaceRaised
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.senomy.state === "battery-low" || root.senomy.state === "critical"
                        ? "../assets/senomy/senomy_chibi_lowbattery-v1.png"
                        : root.senomy.state === "listening"
                            ? "../assets/senomy/senomy_chibi_listening-v1.png"
                            : "../assets/senomy/senomy_chibi_browsing.png"
                    fillMode: Image.PreserveAspectCrop
                    mipmap: true
                }
            }

            Text {
                width: parent.width
                text: root.senomy.state.toUpperCase()
                color: root.senomy.state === "critical" ? Config.Theme.danger
                    : root.senomy.state === "warning" ? Config.Theme.warning : Config.Theme.accent
                font.family: Config.Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                width: parent.width
                text: root.senomy.message
                color: Config.Theme.foreground
                font.family: Config.Theme.fontFamily
                font.pixelSize: root.compact ? 9 : 12
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: root.compact ? 2 : 3
                elide: Text.ElideRight
            }

            Column {
                visible: !root.compact
                width: parent.width
                spacing: 8
                SurfaceCard { width: parent.width; height: 76; title: "SYSTEM"; value: "CPU " + Math.round(root.metrics.cpuPercent) + "% · MEM " + Math.round(root.metrics.memoryPercent) + "%"; detail: root.metrics.uptimeLabel + " uptime" }
                SurfaceCard { width: parent.width; height: 76; title: root.media.identity; value: root.media.title; detail: root.media.artist }
                Row {
                    width: parent.width
                    spacing: 8
                    SurfaceButton { width: 68; text: "PREV"; enabled: root.media.available && root.media.selectedPlayer.canGoPrevious; onClicked: root.media.previous() }
                    SurfaceButton { width: 82; text: root.media.playing ? "PAUSE" : "PLAY"; enabled: root.media.available && root.media.selectedPlayer.canTogglePlaying; onClicked: root.media.toggle() }
                    SurfaceButton { width: 68; text: "NEXT"; enabled: root.media.available && root.media.selectedPlayer.canGoNext; onClicked: root.media.next() }
                    SurfaceButton { width: parent.width - 242; text: "INSIGHTS"; onClicked: root.state.showPrimary("insights", root.targetScreen.name, "briefing") }
                }
            }
        }
    }
}
