import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import "../config" as Config

Item {
    id: root

    required property var monitor
    property int offset: 0

    property int capacity: 4
    readonly property int chipWidth: 80
    readonly property int chipGap: 10
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(workspace => workspace.id > 0 && workspace.monitor === root.monitor)
        .sort((left, right) => left.id - right.id)
    readonly property bool overflow: workspaces.length > capacity
    readonly property int visibleCount: Math.min(capacity, workspaces.length)
    readonly property int maximumOffset: Math.max(0, workspaces.length - capacity)
    readonly property int railWidth: visibleCount > 0
        ? visibleCount * chipWidth + (visibleCount - 1) * chipGap
        : chipWidth

    implicitWidth: railWidth + (overflow ? 56 : 0)
    implicitHeight: Config.Theme.islandHeight

    function clampOffset() {
        offset = Math.max(0, Math.min(maximumOffset, offset));
    }

    function revealActiveWorkspace() {
        const index = workspaces.findIndex(workspace => workspace.active);
        if (index < 0)
            return;
        if (index < offset)
            offset = index;
        else if (index >= offset + capacity)
            offset = index - capacity + 1;
        clampOffset();
    }

    onWorkspacesChanged: revealActiveWorkspace()
    onCapacityChanged: revealActiveWorkspace()

    Row {
        anchors.fill: parent
        spacing: 8

        Item {
            width: root.railWidth
            height: Config.Theme.islandHeight
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                orientation: ListView.Horizontal
                interactive: false
                spacing: root.chipGap
                model: ScriptModel {
                    values: root.workspaces
                    objectProp: "id"
                }
                contentX: root.offset * (root.chipWidth + root.chipGap)

                Behavior on contentX {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }

                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
                    NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: 140 }
                }
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 100 }
                }
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 160; easing.type: Easing.OutCubic }
                }

                delegate: WorkspaceChip {
                    required property var modelData
                    workspace: modelData
                }
            }

            Text {
                visible: root.workspaces.length === 0
                anchors.centerIn: parent
                text: "NO WORKSPACE"
                color: Config.Theme.dim
                font.family: Config.Theme.fontFamily
                font.pixelSize: 9
            }
        }

        Column {
            visible: root.overflow
            width: visible ? 48 : 0
            height: parent.height
            spacing: 2

            Repeater {
                model: [
                    { glyph: "󰅁", direction: -1, enabled: root.offset > 0 },
                    { glyph: "󰅂", direction: 1, enabled: root.offset < root.maximumOffset }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: 48
                    height: 27
                    radius: 9
                    color: arrowArea.containsMouse && modelData.enabled
                        ? Config.Theme.surfaceHover : Config.Theme.surface
                    border.width: 1
                    border.color: modelData.enabled ? Config.Theme.dim : Config.Theme.surfaceRaised

                    Text {
                        anchors.centerIn: parent
                        text: modelData.glyph
                        color: modelData.enabled ? Config.Theme.foreground : Config.Theme.dim
                        font.family: Config.Theme.fontFamily
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: arrowArea
                        anchors.fill: parent
                        enabled: modelData.enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.offset += modelData.direction;
                            root.clampOffset();
                        }
                    }
                }
            }
        }
    }
}
