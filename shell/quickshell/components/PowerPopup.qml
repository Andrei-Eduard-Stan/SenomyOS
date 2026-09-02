import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../config" as Config

PopupWindow {
    id: root

    required property var anchorItem
    required property var powerService
    property bool requestedOpen: false
    signal dismissRequested()

    implicitWidth: 430
    implicitHeight: powerService.state === "pending" ? 350 : 250
    color: "transparent"
    visible: requestedOpen
    grabFocus: false

    anchor.item: anchorItem
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Top | Edges.Left
    anchor.rect.y: -12

    onRequestedOpenChanged: if (!requestedOpen && powerService.state === "pending") powerService.cancel()
    onAnchorItemChanged: if (!anchorItem) dismissRequested()

    HyprlandFocusGrab {
        windows: [root]
        active: root.requestedOpen
        onCleared: if (root.requestedOpen) root.dismissRequested()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.requestedOpen
        Keys.onEscapePressed: root.dismissRequested()

        SenomyFrame {
            anchors.fill: parent
            tier: "standard"
            motif: "power"
            active: true

            Column {
                anchors.fill: parent
                spacing: 13

                Text {
                    text: "SESSION CONTROL // GUARDED"
                    color: Config.Theme.accent
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: powerService.available
                        ? "Choose an action. Session-ending actions require a second confirmation."
                        : "The allowlisted session-action backend is unavailable."
                    color: Config.Theme.muted
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                }

                Grid {
                    visible: powerService.state !== "pending"
                    width: parent.width
                    columns: 3
                    columnSpacing: 8
                    rowSpacing: 8
                    Repeater {
                        model: [
                            {id: "lock", label: "LOCK"},
                            {id: "suspend", label: "SUSPEND"},
                            {id: "logout", label: "LOG OUT"},
                            {id: "reboot", label: "REBOOT"},
                            {id: "poweroff", label: "POWER OFF"}
                        ]
                        delegate: SurfaceButton {
                            required property var modelData
                            width: (parent.width - 16) / 3
                            text: modelData.label
                            enabled: powerService.available && powerService.state !== "running"
                            accentColor: modelData.id === "poweroff" || modelData.id === "reboot"
                                ? Config.Theme.danger : Config.Theme.accent
                            onClicked: powerService.request(modelData.id)
                        }
                    }
                }

                Column {
                    visible: powerService.state === "pending"
                    width: parent.width
                    spacing: 12
                    Text {
                        width: parent.width
                        text: "CONFIRM " + powerService.pendingAction.toUpperCase() + "?"
                        color: Config.Theme.danger
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: "This action changes the live session. Automated validation never activates this confirmation."
                        color: Config.Theme.muted
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                    }
                    Row {
                        width: parent.width
                        spacing: 10
                        SurfaceButton {
                            width: (parent.width - 10) / 2
                            text: "CANCEL"
                            onClicked: powerService.cancel()
                        }
                        SurfaceButton {
                            width: (parent.width - 10) / 2
                            text: "CONFIRM"
                            accentColor: Config.Theme.danger
                            active: true
                            onClicked: powerService.confirm()
                        }
                    }
                }

                Text {
                    visible: powerService.state === "failed"
                    width: parent.width
                    text: powerService.error || "Session action failed"
                    color: Config.Theme.danger
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
