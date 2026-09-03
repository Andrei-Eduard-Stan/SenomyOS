import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../config" as Config

PanelWindow {
    id: root

    required property var targetScreen
    property bool requestedOpen: false
    property string title: "SENOMYOS"
    property string eyebrow: "SYSTEM SURFACE"
    property var sections: []
    property string activeSection: ""
    property int preferredWidth: 960
    property int preferredHeight: 720
    property string motif: "identity"
    property real anchorCenterX: targetScreen ? targetScreen.width / 2 : preferredWidth / 2
    property var coexistWindow: null
    property bool surfaceShown: false
    property bool replacementOpening: false
    default property alias bodyData: body.data
    signal closeRequested()
    signal sectionRequested(string section)

    screen: targetScreen
    readonly property real surfaceLeft: Math.max(Config.Theme.screenInset,
        Math.min((targetScreen ? targetScreen.width : implicitWidth) - implicitWidth - Config.Theme.screenInset,
            anchorCenterX - implicitWidth / 2))

    visible: requestedOpen || surfaceShown || (closeTimer.running && !replacementOpening)
    implicitWidth: Math.max(520, Math.min(preferredWidth, targetScreen ? targetScreen.width - 40 : preferredWidth))
    implicitHeight: Math.max(480, Math.min(preferredHeight,
        targetScreen ? targetScreen.height - Config.Theme.railHeight - 34 : preferredHeight))
    color: "transparent"
    exclusiveZone: 0
    focusable: true

    anchors {
        left: true
        bottom: true
    }
    margins {
        left: root.surfaceLeft
        // The Rail's exclusive zone already removes its height from the
        // layershell work area. Zero keeps this frame visually docked above it.
        bottom: 0
    }

    WlrLayershell.namespace: "senomy-v2-primary"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region {
        Region { item: frame; radius: 5 }
    }

    onRequestedOpenChanged: {
        if (requestedOpen) {
            closeTimer.stop();
            revealTimer.restart();
        } else {
            revealTimer.stop();
            surfaceShown = false;
            if (replacementOpening)
                closeTimer.stop();
            else
                closeTimer.restart();
        }
    }

    Timer {
        id: revealTimer
        interval: 1
        onTriggered: {
            root.surfaceShown = root.requestedOpen;
            if (root.surfaceShown)
                surface.forceActiveFocus();
        }
    }

    Timer {
        id: closeTimer
        interval: Config.Theme.popupCloseMs
    }

    HyprlandFocusGrab {
        // The companion is a peer overlay, not a competing primary surface.
        // Treat it as inside the same focus region while it is visible so
        // pointer/keyboard interaction there does not dismiss this surface.
        windows: root.coexistWindow && root.coexistWindow.visible
            ? [root, root.coexistWindow]
            : [root]
        active: root.surfaceShown
        onCleared: if (root.requestedOpen) root.closeRequested()
    }

    FocusScope {
        id: surface
        anchors.fill: parent
        focus: root.surfaceShown
        opacity: root.surfaceShown ? 1 : 0
        scale: root.surfaceShown ? 1 : 0.985
        transform: Translate {
            y: root.surfaceShown ? 0 : 18
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
        Behavior on scale {
            NumberAnimation { duration: Config.Theme.popupOpenMs; easing.type: Easing.OutCubic }
        }
        Keys.onEscapePressed: root.closeRequested()

        SenomyFrame {
            id: frame
            anchors.fill: parent
            tier: "large"
            motif: root.motif
            motifCenterX: root.anchorCenterX - root.surfaceLeft
            active: true

            Row {
                anchors.fill: parent
                spacing: 16

                Column {
                    width: 190
                    height: parent.height
                    spacing: 12

                    Row {
                        width: parent.width
                        spacing: 8
                        Column {
                            width: parent.width - 46
                            spacing: 4
                            Text {
                                width: parent.width
                                text: root.eyebrow
                                color: Config.Theme.accent
                                font.family: Config.Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: root.title
                                color: Config.Theme.foreground
                                font.family: Config.Theme.fontFamily
                                font.pixelSize: 19
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                            }
                        }
                        SurfaceButton {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: 38
                            text: "×"
                            onClicked: root.closeRequested()
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Config.Theme.surfaceHover
                    }

                    ListView {
                        width: parent.width
                        height: parent.height - 112
                        spacing: 6
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.sections
                        delegate: SurfaceButton {
                            required property var modelData
                            width: ListView.view.width
                            text: modelData.label
                            detail: modelData.detail || ""
                            active: root.activeSection === modelData.id
                            onClicked: root.sectionRequested(modelData.id)
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: parent.height
                    color: Config.Theme.surfaceHover
                }

                Item {
                    id: body
                    width: parent.width - 207
                    height: parent.height
                }
            }
        }
    }
}
