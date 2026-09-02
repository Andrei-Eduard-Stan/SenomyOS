import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import "../config" as Config

PopupWindow {
    id: root

    required property var anchorItem
    property bool requestedOpen: false
    property bool cardShown: false
    signal dismissRequested()

    implicitWidth: 330
    implicitHeight: 126
    color: "transparent"
    visible: requestedOpen || cardShown || closeTimer.running
    grabFocus: false

    anchor.item: anchorItem
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Top | Edges.Left
    anchor.rect.y: -12

    function openAnimated() {
        closeTimer.stop();
        revealTimer.restart();
    }

    function closeAnimated() {
        revealTimer.stop();
        cardShown = false;
        closeTimer.restart();
    }

    onRequestedOpenChanged: {
        if (requestedOpen)
            openAnimated();
        else
            closeAnimated();
    }
    onAnchorItemChanged: {
        if (!anchorItem)
            dismissRequested();
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.cardShown
        onCleared: if (root.requestedOpen) root.dismissRequested()
    }

    Timer {
        id: revealTimer
        interval: 1
        onTriggered: {
            root.cardShown = root.requestedOpen;
            if (root.cardShown)
                card.forceActiveFocus();
        }
    }

    Timer {
        id: closeTimer
        interval: Config.Theme.popupCloseMs
    }

    FocusScope {
        id: card
        anchors.fill: parent
        focus: true
        opacity: root.cardShown ? 1 : 0
        transform: Translate {
            y: root.cardShown ? 0 : 10
            Behavior on y {
                NumberAnimation { duration: Config.Theme.popupOpenMs; easing.type: Easing.OutCubic }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: Config.Theme.popupOpenMs; easing.type: Easing.OutCubic }
        }
        Keys.onEscapePressed: root.dismissRequested()

        SenomyFrame {
            anchors.fill: parent
            tier: "standard"
            motif: "controls"
            active: true

            Column {
                anchors.fill: parent
                spacing: 12

                Row {
                    width: parent.width
                    Text {
                        width: parent.width - trayCount.width
                        text: "STATUS RELAY // NATIVE ITEMS"
                        color: Config.Theme.accent
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                    Text {
                        id: trayCount
                        text: String(SystemTray.items.values.length).padStart(2, "0")
                        color: Config.Theme.muted
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 9
                    }
                }

                ListView {
                    visible: SystemTray.items.values.length > 0
                    width: parent.width
                    height: Config.Theme.touchTarget
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    interactive: contentWidth > width
                    boundsBehavior: Flickable.StopAtBounds
                    model: ScriptModel {
                        values: SystemTray.items.values
                        objectProp: "id"
                    }
                    delegate: TrayItemButton {
                        required property var modelData
                        trayItem: modelData
                        parentWindow: root
                    }
                }

                Text {
                    visible: SystemTray.items.values.length === 0
                    width: parent.width
                    height: Config.Theme.touchTarget
                    verticalAlignment: Text.AlignVCenter
                    text: "NO STATUS ITEMS REGISTERED"
                    color: Config.Theme.dim
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 9
                }
            }
        }
    }
}
