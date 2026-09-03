import QtQuick
import QtQuick.Controls
import Quickshell
import "../config" as Config

SenomyFrame {
    id: root

    required property var workspace
    readonly property var visibleToplevels: root.workspace
        ? root.workspace.toplevels.values.slice(0, 3) : []

    width: 66
    height: Config.Theme.islandHeight
    motif: "workspace"
    active: workspace && workspace.active

    Column {
        anchors.centerIn: parent
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.workspace ? root.workspace.id : "—"
            color: root.workspace && root.workspace.active ? Config.Theme.foreground : Config.Theme.muted
            font.family: Config.Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Repeater {
                model: ScriptModel {
                    values: root.visibleToplevels
                }
                delegate: AppIndicator {
                    required property var modelData
                    toplevel: modelData
                    emphasized: root.workspace && root.workspace.active
                }
            }
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.workspace)
                root.workspace.activate();
        }
    }

    ToolTip.visible: pointer.containsMouse
    ToolTip.delay: 500
    ToolTip.text: root.workspace
        ? "Workspace " + root.workspace.id + " · " + root.workspace.toplevels.values.length
            + (root.workspace.toplevels.values.length === 1 ? " app" : " apps")
        : "Workspace unavailable"
}
