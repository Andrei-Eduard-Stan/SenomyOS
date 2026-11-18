import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import "../config" as Config

Item {
    id: root

    required property var monitor
    property var manager:null
    property int offset: 0
    // Optional model injection keeps the production component independently
    // renderable for visual QA without mutating the compositor workspace state.
    property var workspaceSource: null

    property int capacity: 3
    readonly property int chipWidth: capacity >= 3 ? 54 : 58
    readonly property int chipGap: capacity >= 3 ? 8 : 4
    readonly property int navigationWidth: capacity >= 3 ? 46 : 24
    readonly property var workspaces: (workspaceSource ?? Hyprland.workspaces.values)
        .filter(workspace => workspace.id > 0 && workspace.monitor === root.monitor && (!root.manager || root.manager.workspaceIndicatorVisible(workspace.id,root.monitor?root.monitor.name:"") || workspace.toplevels && workspace.toplevels.values.length>0))
        .sort((left, right) => root.manager ? root.manager.workspaceOrder(left.id)-root.manager.workspaceOrder(right.id) : left.id-right.id)
    readonly property bool moduleVisible: !manager || manager.workspaceModuleVisible(monitor ? monitor.name : "")
    readonly property bool overflow: workspaces.length > capacity
    readonly property int maximumOffset: Math.max(0, workspaces.length - capacity)
    readonly property int visibleCount: Math.max(1, Math.min(capacity, workspaces.length))
    readonly property int railWidth: visibleCount * chipWidth + Math.max(0, visibleCount - 1) * chipGap

    // Unused navigation has zero allocation, including its surrounding gap.
    implicitWidth: moduleVisible ? railWidth + previousSlot.width + nextSlot.width : 0
    implicitHeight: Config.Theme.islandHeight

    function focusIndex(index){
        if(index<0 || index>=workspaces.length)return;
        if(index<offset)offset=index;else if(index>=offset+capacity)offset=index-capacity+1;
        clampOffset();list.currentIndex=index;list.forceLayout();Qt.callLater(()=>{const item=list.itemAtIndex(index);if(item)item.forceActiveFocus(Qt.TabFocusReason);});
    }
    function clampOffset() {
        offset = Math.max(0, Math.min(maximumOffset, offset));
    }

    function revealActiveWorkspace() {
        clampOffset();
        const index = workspaces.findIndex(workspace => workspace.active);
        if (index < 0)
            return;
        if (index < offset)
            offset = index;
        else if (index >= offset + capacity)
            offset = index - capacity + 1;
        clampOffset();
    }

    onWorkspacesChanged: Qt.callLater(revealActiveWorkspace)
    onCapacityChanged: Qt.callLater(revealActiveWorkspace)
    onMaximumOffsetChanged: Qt.callLater(revealActiveWorkspace)
    Connections {
        target: root.monitor
        ignoreUnknownSignals: true
        function onActiveWorkspaceChanged() { Qt.callLater(root.revealActiveWorkspace); }
    }

    Row {
        anchors.fill: parent
        visible:root.moduleVisible
        spacing: 0

        Item {
            id: previousSlot
            activeFocusOnTab: root.overflow && root.offset > 0
            Accessible.role: Accessible.Button
            Accessible.name: "Previous workspace page"
            Keys.onReturnPressed: { root.offset += -1; root.clampOffset(); }
            Keys.onSpacePressed: { root.offset += -1; root.clampOffset(); }
            clip: true
            width: root.overflow ? root.navigationWidth + root.chipGap : 0
            Behavior on width { NumberAnimation { duration: Config.Motion.duration(170); easing.type: Easing.OutCubic } }
            height: parent.height
            opacity: root.overflow ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Config.Motion.duration(120) } }

            Image {
                anchors.centerIn: parent
                width: root.capacity >= 3 ? 18 : 12
                height: root.capacity >= 3 ? 34 : 22
                source: Config.RailStyle.arrowBorderType === "art" && artprevious.status === Image.Ready
                    ? "" : "../assets/icons/workspace-previous.png"
                fillMode: Image.PreserveAspectFit
                opacity: root.offset > 0 ? (previousArea.containsMouse ? 1 : 0.82) : 0.28
            }
            Image {
                id: artprevious
                anchors.centerIn: parent
                width: root.capacity >= 3 ? 24 : 16
                height: root.capacity >= 3 ? 34 : 22
                source: Config.RailStyle.arrowBorderType === "art" ? Config.RailStyle.previousArrowArtSource : ""
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectFit
                opacity: root.offset > 0 ? (previousArea.containsMouse || previousSlot.activeFocus ? 1 : 0.82) : 0.28
            }
            ButtonHoverFrame { anchors.fill: parent; focusTarget:previousSlot;pointerTarget:previousArea;focused:previousSlot.activeFocus;engaged:previousArea.enabled && previousArea.containsMouse }
            MouseArea {
                id: previousArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.overflow && root.offset > 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.offset -= 1;
                    root.clampOffset();
                }
            }
        }

        Item {
            width: root.railWidth
            height: Config.Theme.islandHeight
            clip: true

            ListView {
                id: list
                objectName:"workspace-list"
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
                        duration: Config.Motion.duration(170)
                        easing.type: Easing.OutCubic
                    }
                }

                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Config.Motion.duration(140) }
                    NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: Config.Motion.duration(140) }
                }
                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: Config.Motion.duration(100) }
                }
                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: Config.Motion.duration(160); easing.type: Easing.OutCubic }
                }

                delegate: WorkspaceChip {
                    required property int index
                    onNavigate:direction=>root.focusIndex(index+direction)
                    onBoundary:last=>root.focusIndex(last?root.workspaces.length-1:0)
                    required property var modelData
                    workspace: modelData
                    manager: root.manager
                    preferredWidth: root.chipWidth
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

        Item {
            id: nextSlot
            activeFocusOnTab: root.overflow && root.offset < root.maximumOffset
            Accessible.role: Accessible.Button
            Accessible.name: "Next workspace page"
            Keys.onReturnPressed: { root.offset += 1; root.clampOffset(); }
            Keys.onSpacePressed: { root.offset += 1; root.clampOffset(); }
            clip: true
            width: root.overflow ? root.navigationWidth + root.chipGap : 0
            Behavior on width { NumberAnimation { duration: Config.Motion.duration(170); easing.type: Easing.OutCubic } }
            height: parent.height
            opacity: root.overflow ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Config.Motion.duration(120) } }

            Image {
                anchors.centerIn: parent
                width: root.capacity >= 3 ? 18 : 12
                height: root.capacity >= 3 ? 34 : 22
                source: Config.RailStyle.arrowBorderType === "art" && artnext.status === Image.Ready
                    ? "" : "../assets/icons/workspace-next.png"
                fillMode: Image.PreserveAspectFit
                opacity: root.offset < root.maximumOffset ? (nextArea.containsMouse ? 1 : 0.82) : 0.28
            }
            Image {
                id: artnext
                anchors.centerIn: parent
                width: root.capacity >= 3 ? 24 : 16
                height: root.capacity >= 3 ? 34 : 22
                source: Config.RailStyle.arrowBorderType === "art" ? Config.RailStyle.nextArrowArtSource : ""
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectFit
                opacity: root.offset < root.maximumOffset ? (nextArea.containsMouse || nextSlot.activeFocus ? 1 : 0.82) : 0.28
            }
            ButtonHoverFrame { anchors.fill: parent; focusTarget:nextSlot;pointerTarget:nextArea;focused:nextSlot.activeFocus;engaged:nextArea.enabled && nextArea.containsMouse }
            MouseArea {
                id: nextArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.overflow && root.offset < root.maximumOffset
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.offset += 1;
                    root.clampOffset();
                }
            }
        }
    }
}
