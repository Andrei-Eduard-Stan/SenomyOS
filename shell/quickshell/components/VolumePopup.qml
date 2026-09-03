import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import "../config" as Config

PopupWindow {
    id: root

    required property var anchorItem
    required property var audio
    property var media
    property bool requestedOpen: false
    property bool cardShown: false
    signal dismissRequested()
    signal openAudioRequested()

    implicitWidth: 420
    implicitHeight: 122
    color: "transparent"
    visible: requestedOpen || cardShown || closeTimer.running
    grabFocus: false

    anchor.item: anchorItem
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Top | Edges.Left
    anchor.rect.y: -12

    onRequestedOpenChanged: {
        if (requestedOpen) {
            closeTimer.stop();
            revealTimer.restart();
        } else {
            revealTimer.stop();
            cardShown = false;
            closeTimer.restart();
        }
    }
    onAnchorItemChanged: if (!anchorItem) dismissRequested()

    Timer {
        id: revealTimer
        interval: 1
        onTriggered: {
            root.cardShown = root.requestedOpen;
            if (root.cardShown)
                card.forceActiveFocus();
        }
    }
    Timer { id: closeTimer; interval: Config.Theme.popupCloseMs }

    HyprlandFocusGrab {
        windows: [root]
        active: root.cardShown
        onCleared: if (root.requestedOpen) root.dismissRequested()
    }

    FocusScope {
        id: card
        anchors.fill: parent
        focus: root.cardShown
        opacity: root.cardShown ? 1 : 0
        scale: root.cardShown ? 1 : 0.98
        transform: Translate {
            y: root.cardShown ? 0 : 12
            Behavior on y {
                NumberAnimation {
                    duration: root.requestedOpen ? Config.Theme.popupOpenMs : Config.Theme.popupCloseMs
                    easing.type: root.requestedOpen ? Easing.OutCubic : Easing.InCubic
                }
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.requestedOpen ? Config.Theme.popupOpenMs : Config.Theme.popupCloseMs
                easing.type: root.requestedOpen ? Easing.OutCubic : Easing.InCubic
            }
        }
        Behavior on scale { NumberAnimation { duration: Config.Theme.popupOpenMs; easing.type: Easing.OutCubic } }
        Keys.onEscapePressed: root.dismissRequested()

        SenomyFrame {
            anchors.fill: parent
            tier: "standard"
            motif: "controls"
            active: true

            Column {
                anchors.fill: parent
                spacing: 9

                Row {
                    width: parent.width
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - closeButton.width - 8
                        text: root.audio.outputName + "  //  " + root.audio.label
                        color: Config.Theme.muted
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 9
                        elide: Text.ElideMiddle
                    }
                    SurfaceButton {
                        id: closeButton
                        width: 34
                        height: 28
                        text: "×"
                        onClicked: root.dismissRequested()
                    }
                }

                Row {
                    width: parent.width
                    height: 48
                    spacing: 8
                    SurfaceButton {
                        width: 58
                        height: 42
                        text: root.audio.muted ? "ON" : "MUTE"
                        active: root.audio.muted
                        enabled: root.audio.available
                        onClicked: root.audio.toggleMuted()
                    }
                    Slider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 58 - 48 - 82 - 24
                        from: 0
                        to: 1
                        value: root.audio.volume
                        enabled: root.audio.available
                        onMoved: root.audio.setVolume(value)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        horizontalAlignment: Text.AlignRight
                        text: root.audio.label
                        color: Config.Theme.foreground
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 10
                    }
                    SurfaceButton {
                        width: 82
                        height: 42
                        text: "AUDIO ›"
                        onClicked: root.openAudioRequested()
                    }
                }
            }
        }
    }
}
