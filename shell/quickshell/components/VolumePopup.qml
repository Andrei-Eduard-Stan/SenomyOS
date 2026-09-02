import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import "../config" as Config

PopupWindow {
    id: root

    required property var anchorItem
    required property var audio
    required property var media
    property bool requestedOpen: false
    signal dismissRequested()

    implicitWidth: 440
    implicitHeight: 510
    color: "transparent"
    visible: requestedOpen
    grabFocus: false

    anchor.item: anchorItem
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Top | Edges.Left
    anchor.rect.y: -12

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
            motif: "controls"
            active: true

            Column {
                anchors.fill: parent
                spacing: 13

                Row {
                    width: parent.width
                    Text {
                        width: parent.width - closeButton.width
                        text: "AUDIO ROUTING // PIPEWIRE"
                        color: Config.Theme.accent
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                    SurfaceButton {
                        id: closeButton
                        width: 64
                        height: 38
                        text: "CLOSE"
                        onClicked: root.dismissRequested()
                    }
                }

                Text {
                    width: parent.width
                    text: root.audio.outputName
                    color: Config.Theme.foreground
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Row {
                    width: parent.width
                    spacing: 10
                    SurfaceButton {
                        width: 86
                        text: root.audio.muted ? "UNMUTE" : "MUTE"
                        active: root.audio.muted
                        enabled: root.audio.available
                        onClicked: root.audio.toggleMuted()
                    }
                    Slider {
                        id: outputSlider
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 152
                        from: 0
                        to: 1
                        value: root.audio.volume
                        enabled: root.audio.available
                        onMoved: root.audio.setVolume(value)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46
                        horizontalAlignment: Text.AlignRight
                        text: root.audio.label
                        color: Config.Theme.foreground
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                Text {
                    text: "OUTPUT DEVICES"
                    color: Config.Theme.dim
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                }
                ListView {
                    width: parent.width
                    height: Math.min(116, contentHeight)
                    spacing: 5
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.audio.outputNodes
                    delegate: SurfaceButton {
                        required property var modelData
                        width: ListView.view.width
                        height: 44
                        text: modelData.description || modelData.nickname || modelData.name || "Audio output"
                        active: modelData === root.audio.sink
                        onClicked: root.audio.selectOutput(modelData)
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Config.Theme.surfaceHover }

                Text {
                    width: parent.width
                    text: "INPUT // " + root.audio.inputName
                    color: Config.Theme.muted
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
                Row {
                    width: parent.width
                    spacing: 10
                    SurfaceButton {
                        width: 86
                        text: root.audio.inputMuted ? "UNMUTE" : "MUTE"
                        active: root.audio.inputMuted
                        enabled: root.audio.inputAvailable
                        onClicked: root.audio.toggleInputMuted()
                    }
                    Slider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 142
                        from: 0
                        to: 1
                        value: root.audio.inputVolume
                        enabled: root.audio.inputAvailable
                        onMoved: root.audio.setInputVolume(value)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        text: Math.round(root.audio.inputVolume * 100) + "%"
                        color: Config.Theme.muted
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 9
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Config.Theme.surfaceHover }

                Row {
                    width: parent.width
                    spacing: 8
                    SurfaceButton {
                        width: 60
                        text: "PREV"
                        enabled: root.media.available && root.media.selectedPlayer.canGoPrevious
                        onClicked: root.media.previous()
                    }
                    SurfaceButton {
                        width: 76
                        text: root.media.playing ? "PAUSE" : "PLAY"
                        enabled: root.media.available && root.media.selectedPlayer.canTogglePlaying
                        onClicked: root.media.toggle()
                    }
                    SurfaceButton {
                        width: 60
                        text: "NEXT"
                        enabled: root.media.available && root.media.selectedPlayer.canGoNext
                        onClicked: root.media.next()
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 220
                        Text {
                            width: parent.width
                            text: root.media.title
                            color: Config.Theme.foreground
                            font.family: Config.Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.media.artist || root.media.identity
                            color: Config.Theme.dim
                            font.family: Config.Theme.fontFamily
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
