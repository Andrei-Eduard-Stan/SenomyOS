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
    default property alias bodyData: body.data
    signal closeRequested()
    signal sectionRequested(string section)

    screen: targetScreen
    visible: requestedOpen
    implicitWidth: Math.max(520, Math.min(preferredWidth, targetScreen ? targetScreen.width - 40 : preferredWidth))
    implicitHeight: Math.max(480, Math.min(preferredHeight,
        targetScreen ? targetScreen.height - Config.Theme.railHeight - 34 : preferredHeight))
    color: "transparent"
    exclusiveZone: 0
    focusable: true

    anchors {
        right: true
        bottom: true
    }
    margins {
        right: Config.Theme.screenInset
        bottom: Config.Theme.railHeight + 12
    }

    WlrLayershell.namespace: "senomy-v2-primary"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region {
        Region { item: frame; radius: 26 }
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.requestedOpen
        onCleared: if (root.requestedOpen) root.closeRequested()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.requestedOpen
        Keys.onEscapePressed: root.closeRequested()

        SenomyFrame {
            id: frame
            anchors.fill: parent
            tier: "standard"
            motif: "identity"
            active: true

            Row {
                anchors.fill: parent
                spacing: 16

                Column {
                    width: 190
                    height: parent.height
                    spacing: 12

                    Column {
                        width: parent.width
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
