import QtQuick
import QtQuick.Controls
import Quickshell
import "../config" as Config

SenomyFrame {
    frameKey: ""
    fillKey: "context"
    borderType: "none"
    nativeFrameEnabled: false
    fullHeightFrame: true
    stateUnderlineEnabled: false
    id: root
    SilverIslandFrame {
        parent: root
        anchors.fill: parent
        z: -1
        active: root.active
        hovered: root.hovered
    }


    required property var activity
    signal openDestination(string destination)

    width: 230
    height: Config.Theme.islandHeight
    motif: "junction"
    active: activity.kind !== "idle"

    function symbolicIcon() {
        switch (activity.kind) {
        case "benchmark": return "utilities-system-monitor-symbolic";
        case "operation": return "system-run-symbolic";
        case "notification": return "preferences-system-notifications-symbolic";
        default: return "view-grid-symbolic";
        }
    }

    function activate() {
        switch (activity.kind) {
        case "benchmark": root.openDestination("performance"); break;
        case "operation": root.openDestination("insights"); break;
        case "notification": root.openDestination("notifications"); break;
        case "media": root.activity.toggle(); break;
        default: break;
        }
    }

    Row {
        anchors.fill: parent
        spacing: 8

        Item {
            id: artworkStage
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38

            Rectangle {
                anchors.fill: parent
                radius: 7
                color: Config.Theme.glassRaised
                border.width: 1
                border.color: Config.Theme.dim
            }

            Image {
                visible: root.activity.artwork.length > 0
                anchors.fill: parent
                anchors.margins: 1
                source: root.activity.artwork
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                mipmap: true
            }

            Image {
                visible: root.activity.artwork.length === 0
                anchors.centerIn: parent
                width: 19
                height: 19
                source: Quickshell.iconPath(root.symbolicIcon(), true)
                fillMode: Image.PreserveAspectFit
                opacity: root.activity.kind === "idle" ? 0.45 : 0.9
            }
        }

        Item {
            width: parent.width - artworkStage.width - parent.spacing
            height: parent.height

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 1

                Text {
                    width: parent.width
                    text: root.activity.eyebrow
                    color: root.activity.kind === "idle" ? Config.Theme.dim : Config.Theme.accent
                    font.family: "Audiowide"
                    font.pixelSize: 7
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Row {
                    width: parent.width
                    height: 17
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.activity.mediaControlsAvailable ? parent.width - mediaControls.width - 5 : parent.width
                        text: root.activity.title
                        color: Config.Theme.foreground
                        font.family: "Audiowide"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Row {
                        id: mediaControls
                        visible: root.activity.mediaControlsAvailable
                        width: visible ? 51 : 0
                        spacing: 2

                        Repeater {
                            model: [
                                {icon: "media-skip-backward-symbolic", action: "previous"},
                                {icon: root.activity.mediaPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic", action: "toggle"},
                                {icon: "media-skip-forward-symbolic", action: "next"}
                            ]
                            delegate: Item {
                                required property var modelData
                                width: 15
                                height: 15
                                Image {
                                    anchors.centerIn: parent
                                    width: 11
                                    height: 11
                                    source: Quickshell.iconPath(modelData.icon, true)
                                    fillMode: Image.PreserveAspectFit
                                }
                                ButtonHoverFrame { trackPointer: true; anchors.fill: parent }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.action === "previous") root.activity.previous();
                                        else if (modelData.action === "next") root.activity.next();
                                        else root.activity.toggle();
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 4
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: Config.Theme.dim
                        opacity: 0.45
                    }
                    Rectangle {
                        visible: root.activity.progress >= 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * root.activity.progress
                        height: 2
                        color: Config.Theme.foreground
                    }
                }

                Text {
                    width: parent.width
                    text: root.activity.detail
                    color: Config.Theme.muted
                    font.family: "Audiowide"
                    font.pixelSize: 7
                    elide: Text.ElideRight
                }
            }

            ButtonHoverFrame { trackPointer: true; anchors.fill: parent }
            MouseArea {
                anchors.fill: parent
                z: 10
                enabled: root.activity.kind !== "media" && root.activity.kind !== "idle"
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.activate()
            }
        }
    }

}
