import QtQuick
import Quickshell
import Quickshell.Wayland
import "../config" as Config

PanelWindow {
    id: root

    required property var targetScreen
    required property var notifications
    property bool placementEnabled: false
    property bool shown: false

    screen: targetScreen
    visible: placementEnabled && notifications.serverEnabled && shown && notifications.latest !== null
    implicitWidth: 430
    implicitHeight: 170
    color: "transparent"
    exclusiveZone: 0
    aboveWindows: true

    anchors {
        right: true
        top: true
    }
    margins {
        right: Config.Theme.screenInset
        top: Config.Theme.screenInset
    }

    WlrLayershell.namespace: "senomy-v2-notification-toast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        Region { item: frame; radius: 24 }
    }

    Connections {
        target: root.notifications
        function onToastGenerationChanged() {
            if (root.notifications.latest && !root.notifications.dnd) {
                root.shown = true;
                hideTimer.restart();
            }
        }
    }

    Timer {
        id: hideTimer
        interval: root.notifications.latest && root.notifications.latest.urgency === "Critical" ? 12000 : 6000
        onTriggered: root.shown = false
    }

    SenomyFrame {
        id: frame
        anchors.fill: parent
        tier: "standard"
        motif: "clock-notification"
        active: true

        Column {
            anchors.fill: parent
            spacing: 7
            Row {
                width: parent.width
                Text {
                    width: parent.width - 72
                    text: root.notifications.latest
                        ? root.notifications.latest.appName + " // " + root.notifications.latest.urgency : "NOTIFICATION"
                    color: root.notifications.latest && root.notifications.latest.urgency === "Critical"
                        ? Config.Theme.danger : Config.Theme.accent
                    font.family: Config.Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                SurfaceButton {
                    width: 72
                    height: 30
                    text: "CLOSE"
                    onClicked: root.shown = false
                }
            }
            Text {
                width: parent.width
                text: root.notifications.latest ? root.notifications.latest.summary : ""
                color: Config.Theme.foreground
                font.family: Config.Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.notifications.latest ? root.notifications.latest.body : ""
                color: Config.Theme.muted
                font.family: Config.Theme.fontFamily
                font.pixelSize: 9
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Row {
                visible: root.notifications.latest && root.notifications.latest.actions
                    && root.notifications.latest.actions.length > 0
                spacing: 6
                Repeater {
                    model: root.notifications.latest ? root.notifications.latest.actions || [] : []
                    delegate: SurfaceButton {
                        required property var modelData
                        width: 96
                        height: 32
                        text: modelData.text || modelData.identifier || "ACTION"
                        onClicked: {
                            root.notifications.invoke(root.notifications.latest, modelData);
                            root.shown = false;
                        }
                    }
                }
            }
        }
    }
}
