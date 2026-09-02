import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../config" as Config

PopupWindow {
    id: root

    required property var anchorItem
    required property var notifications
    property bool requestedOpen: false
    signal dismissRequested()

    implicitWidth: 470
    implicitHeight: 610
    color: "transparent"
    visible: requestedOpen
    grabFocus: false

    anchor.item: anchorItem
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Top | Edges.Left
    anchor.rect.y: -12

    onRequestedOpenChanged: if (requestedOpen) notifications.markRead()
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
            motif: "clock-notification"
            active: true

            Column {
                anchors.fill: parent
                spacing: 12

                Row {
                    width: parent.width
                    spacing: 8
                    Column {
                        width: parent.width - 188
                        Text {
                            text: "NOTIFICATION ARCHIVE"
                            color: Config.Theme.accent
                            font.family: Config.Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: notifications.serverEnabled
                                ? notifications.history.length + " retained record(s)"
                                : "SwayNC retains ownership until migration validation"
                            color: Config.Theme.muted
                            font.family: Config.Theme.fontFamily
                            font.pixelSize: 8
                        }
                    }
                    SurfaceButton {
                        width: 86
                        text: notifications.dnd ? "DND ON" : "DND OFF"
                        active: notifications.dnd
                        enabled: notifications.serverEnabled
                        onClicked: notifications.setDnd(!notifications.dnd)
                    }
                    SurfaceButton {
                        width: 86
                        text: "CLEAR"
                        enabled: notifications.history.length > 0
                        onClicked: notifications.clearAll()
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Config.Theme.surfaceHover }

                ListView {
                    visible: notifications.history.length > 0
                    width: parent.width
                    height: parent.height - 74
                    spacing: 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: notifications.history
                    delegate: Rectangle {
                        id: notificationCard
                        required property var modelData
                        width: ListView.view.width
                        height: Math.max(100, cardContent.implicitHeight + 22)
                        radius: 15
                        color: Config.Theme.surfaceRaised
                        border.width: 1
                        border.color: modelData.urgency === "Critical" ? Config.Theme.danger
                            : modelData.unread ? Config.Theme.accent : Config.Theme.surfaceHover

                        Column {
                            id: cardContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 6
                            Row {
                                width: parent.width
                                Text {
                                    width: parent.width - 68
                                    text: modelData.appName + "  //  " + modelData.urgency
                                    color: Config.Theme.dim
                                    font.family: Config.Theme.fontFamily
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                                SurfaceButton {
                                    width: 68
                                    height: 32
                                    text: "DISMISS"
                                    onClicked: notifications.dismiss(notificationCard.modelData)
                                }
                            }
                            Text {
                                width: parent.width
                                text: modelData.summary
                                color: Config.Theme.foreground
                                font.family: Config.Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                            }
                            Text {
                                visible: modelData.body.length > 0
                                width: parent.width
                                text: modelData.body
                                color: Config.Theme.muted
                                font.family: Config.Theme.fontFamily
                                font.pixelSize: 9
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }
                            Row {
                                visible: modelData.actions && modelData.actions.length > 0
                                spacing: 6
                                Repeater {
                                    model: modelData.actions || []
                                    delegate: SurfaceButton {
                                        required property var modelData
                                        width: Math.max(76, implicitWidth)
                                        height: 34
                                        text: modelData.text || modelData.identifier || "ACTION"
                                        onClicked: notifications.invoke(notificationCard.modelData, modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    visible: notifications.history.length === 0
                    width: parent.width
                    height: parent.height - 74
                    spacing: 8
                    Text {
                        width: parent.width
                        topPadding: 96
                        horizontalAlignment: Text.AlignHCenter
                        text: "NO RETAINED NOTIFICATIONS"
                        color: Config.Theme.foreground
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: notifications.serverEnabled
                            ? "Transient notifications are intentionally not persisted."
                            : "Native history becomes active only when Quickshell owns the notification bus."
                        color: Config.Theme.dim
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
