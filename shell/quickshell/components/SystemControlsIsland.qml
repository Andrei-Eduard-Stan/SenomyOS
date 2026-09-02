import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import "../config" as Config

SenomyFrame {
    id: root

    required property var audio
    required property var battery
    required property var network
    property bool trayOpen: false
    property alias trayAnchor: trayButton.anchorItem
    signal toggleTray()
    width: 320
    height: Config.Theme.islandHeight
    motif: "controls"

    function batteryIcon() {
        if (!battery.available)
            return "battery.svg";
        if (battery.charging)
            return "battery-charging.svg";
        const percent = Math.round(battery.percentage * 100);
        if (percent >= 88)
            return "battery-100.svg";
        if (percent >= 63)
            return "battery-75.svg";
        if (percent >= 38)
            return "battery-50.svg";
        return "battery-25.svg";
    }

    Row {
        anchors.fill: parent

        Repeater {
            model: [
                {
                    id: "applications",
                    icon: "applications.svg",
                    badge: "",
                    tooltip: "Open SenomyOS Command Lens"
                },
                {
                    id: "audio",
                    icon: root.audio.muted ? "volume-muted.svg" : "volume.svg",
                    badge: root.audio.label,
                    tooltip: root.audio.available ? "PipeWire output · click to toggle mute" : "PipeWire output unavailable"
                },
                {
                    id: "network",
                    icon: "wifi.svg",
                    badge: root.network.label,
                    tooltip: root.network.detail
                },
                {
                    id: "battery",
                    icon: root.batteryIcon(),
                    badge: root.battery.label,
                    tooltip: root.battery.detail
                }
            ]

            delegate: Item {
                id: control
                required property var modelData
                width: 60
                height: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width: 46
                    height: 42
                    radius: 12
                    color: controlArea.containsMouse ? Config.Theme.surfaceHover : "transparent"
                }
                Image {
                    anchors.centerIn: parent
                    width: 19
                    height: 19
                    source: "../assets/icons/" + modelData.icon
                    fillMode: Image.PreserveAspectFit
                    opacity: modelData.id === "network" && !root.network.available ? 0.45 : 1
                }
                Rectangle {
                    visible: modelData.badge.length > 0
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    height: 14
                    width: Math.max(22, badgeText.implicitWidth + 8)
                    radius: 7
                    color: Config.Theme.surfaceRaised
                    border.width: 1
                    border.color: Config.Theme.dim
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: modelData.badge
                        color: Config.Theme.muted
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 7
                    }
                }
                MouseArea {
                    id: controlArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: modelData.id === "applications" || (modelData.id === "audio" && root.audio.available)
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (modelData.id === "applications")
                            Quickshell.execDetached(["rofi", "-show", "drun"]);
                        else if (modelData.id === "audio")
                            root.audio.toggleMuted();
                    }
                }
                ToolTip.visible: controlArea.containsMouse
                ToolTip.delay: 450
                ToolTip.text: modelData.tooltip
            }
        }

        Item {
            id: trayButton
            property alias anchorItem: trayArea
            width: 60
            height: parent.height

            Rectangle {
                anchors.centerIn: parent
                width: 46
                height: 42
                radius: 12
                color: trayArea.containsMouse || root.trayOpen ? Config.Theme.surfaceHover : "transparent"
            }
            Image {
                anchors.centerIn: parent
                width: 19
                height: 19
                source: "../assets/icons/tray-up.svg"
                fillMode: Image.PreserveAspectFit
            }
            Rectangle {
                visible: SystemTray.items.values.length > 0
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                height: 14
                width: Math.max(22, trayBadge.implicitWidth + 8)
                radius: 7
                color: Config.Theme.surfaceRaised
                border.width: 1
                border.color: Config.Theme.dim
                Text {
                    id: trayBadge
                    anchors.centerIn: parent
                    text: String(SystemTray.items.values.length)
                    color: Config.Theme.muted
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 7
                }
            }
            MouseArea {
                id: trayArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleTray()
            }
            ToolTip.visible: trayArea.containsMouse && !root.trayOpen
            ToolTip.delay: 450
            ToolTip.text: SystemTray.items.values.length + " native tray item(s)"
        }
    }
}
