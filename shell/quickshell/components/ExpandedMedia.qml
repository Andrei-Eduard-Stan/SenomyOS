import QtQuick
import QtQuick.Controls
import Quickshell

Item {
    id: root

    property var media: null
    property bool active: false
    readonly property var player: media ? media.selectedPlayer : null
    property real position: 0
    readonly property bool seekable: !!player && player.canSeek && player.positionSupported && player.lengthSupported && player.length > 0

    function refresh() {
        if (!seek.pressed)
            position = player && player.positionSupported ? player.position : 0;

    }

    function clock(s) {
        s = Math.max(0, Math.floor(s || 0));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    onPlayerChanged: refresh()

    Timer {
        interval: 500
        repeat: true
        running: root.active && root.visible && !!root.player
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Image {
        id: cover

        width: root.width * 0.23
        height: Math.min(parent.height, 90)
        source: root.media ? root.media.artwork : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(200, 200)
        visible: status === Image.Ready
    }

    Image {
        anchors.fill: cover
        source: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/lockinthosefirst/2x/sos logo@2x.png"
        fillMode: Image.PreserveAspectFit
        visible: !cover.visible
        opacity: 0.3
    }

    Column {
        x: cover.width + 10
        width: parent.width - x
        spacing: 2

        ExpandedLabel {
            width: parent.width
            text: root.player ? root.media.title : "Nothing playing"
            font.pixelSize: 11
        }

        ExpandedLabel {
            width: parent.width
            text: root.player ? [root.media.artist, root.media.identity].filter((s) => {
                return s;
            }).join(" · ") : "Media appears here"
            font.pixelSize: 9
            color: "#b4b4bf"
        }

        Slider {
            id: seek

            property var dragPlayer: null

            objectName: "mediaSeek"
            width: parent.width
            height: 20
            from: 0
            to: root.player && root.player.lengthSupported ? Math.max(1, root.player.length) : 1
            enabled: root.seekable
            value: root.position
            onPressedChanged: {
                if (pressed) {
                    dragPlayer = root.player;
                } else if (dragPlayer && dragPlayer === root.player && root.seekable) {
                    dragPlayer.position = value;
                    root.position = value;
                    dragPlayer = null;
                }
            }
            onMoved: {
                if (root.seekable && !pressed) {
                    root.player.position = value;
                    root.position = value;
                }
            }
            Accessible.name: "Playback position"

            background: Rectangle {
                x: seek.leftPadding
                y: seek.topPadding + seek.availableHeight / 2 - 1
                width: seek.availableWidth
                height: 2
                color: "#42424a"

                Rectangle {
                    width: seek.visualPosition * parent.width
                    height: 2
                    color: "#e3d9f7"
                }

            }

            handle: Rectangle {
                x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
                y: seek.topPadding + seek.availableHeight / 2 - 3
                width: 6
                height: 6
                radius: 3
                color: seek.enabled ? "white" : "#55555c"
            }

        }

        Row {
            width: parent.width

            ExpandedLabel {
                width: parent.width / 2
                text: root.clock(root.position)
                font.pixelSize: 8
            }

            ExpandedLabel {
                width: parent.width / 2
                horizontalAlignment: Text.AlignRight
                text: root.player && root.player.lengthSupported ? root.clock(root.player.length) : "—"
                font.pixelSize: 8
            }

        }

        Row {
            spacing: 2

            ExpandedButton {
                width: root.width >= 320 ? 44 : 32
                height: root.width >= 320 ? 44 : 40
                text: "−10"
                subtle: true
                enabled: !!root.player && root.player.canSeek
                Accessible.name: "Back ten seconds"
                onClicked: root.player.seek(-10)
            }

            ExpandedButton {
                width: root.width >= 320 ? 44 : 32
                height: root.width >= 320 ? 44 : 40
                objectName: "previousButton"
                symbolic: true
                text: "\uf048"
                subtle: true
                enabled: !!root.player && root.player.canGoPrevious
                Accessible.name: enabled ? "Previous track" : "Previous track unavailable from this player"
                onClicked: root.player.previous()
            }

            ExpandedButton {
                width: root.width >= 320 ? 44 : 32
                height: root.width >= 320 ? 44 : 40
                objectName: "playButton"
                symbolic: true
                text: root.media && root.media.playing ? "\uf04c" : "\uf04b"
                subtle: true
                enabled: !!root.player && root.player.canTogglePlaying
                Accessible.name: root.media && root.media.playing ? "Pause" : "Play"
                onClicked: root.player.togglePlaying()
            }

            ExpandedButton {
                width: root.width >= 320 ? 44 : 32
                height: root.width >= 320 ? 44 : 40
                objectName: "nextButton"
                symbolic: true
                text: "\uf051"
                subtle: true
                enabled: !!root.player && root.player.canGoNext
                Accessible.name: enabled ? "Next track" : "Next track unavailable from this player"
                onClicked: root.player.next()
            }

            ExpandedButton {
                width: root.width >= 320 ? 44 : 32
                height: root.width >= 320 ? 44 : 40
                text: "+10"
                subtle: true
                enabled: !!root.player && root.player.canSeek
                Accessible.name: "Forward ten seconds"
                onClicked: root.player.seek(10)
            }

        }

    }

}
