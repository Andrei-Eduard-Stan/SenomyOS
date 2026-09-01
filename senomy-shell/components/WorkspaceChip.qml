import QtQuick
import QtQuick.Controls
import Quickshell
import "../config" as Config

SenomyFrame {
    id: root

    required property var workspace
    width: 80
    height: Config.Theme.islandHeight
    motif: "workspace"
    active: workspace && workspace.active

    Row {
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.workspace ? root.workspace.id : "—"
            color: root.workspace && root.workspace.active ? Config.Theme.foreground : Config.Theme.muted
            font.family: Config.Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Grid {
            anchors.verticalCenter: parent.verticalCenter
            columns: 2
            rows: 2
            spacing: 2

            Repeater {
                model: ScriptModel {
                    values: root.workspace ? root.workspace.toplevels.values.slice(0, 4) : []
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
        ? "Workspace " + root.workspace.id + " · " + root.workspace.toplevels.values.length + " app"
        : "Workspace unavailable"
}
