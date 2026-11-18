import QtQuick
import QtQuick.Controls
import Quickshell
import "../config" as Config

SenomyFrame {
    frameKey: ""
    fillKey: "workspace"
    nativeFrameEnabled: false
    fullHeightFrame: true
    railBackground: true
    stateUnderlineEnabled: false
    id: root

    required property var workspace
    property var manager:null
    signal navigate(int direction)
    signal boundary(bool last)
    readonly property string workspaceLabel:{if(!workspace)return "—";const label=manager?manager.workspaceLabel(workspace.id):String(workspace.id);return /^\d+$/.test(label)?romanNumeral(Number(label)):label;}
    property int preferredWidth: 54
    readonly property var visibleToplevels: root.workspace
        ? root.workspace.toplevels.values.slice(0, 1) : []
    readonly property bool attention:!!workspace&&!!workspace.urgent
    readonly property int windowCount: workspace ? workspace.toplevels.values.length : 0
    readonly property int remainingCount: Math.max(0, windowCount - 1)

    width: preferredWidth
    height: Config.Theme.islandHeight
    motif: "workspace"
    borderType: "none"
    artSource: ""
    active: workspace && workspace.active
    opacity: active || activeFocus || pointer.containsMouse ? 1 : Config.DirectoryStyle.highContrast ? 0.84 : 0.72
    Behavior on opacity { NumberAnimation { duration: Config.Motion.duration(120) } }
    hovered: pointer.containsMouse || activeFocus
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: workspace ? "Workspace " + root.workspaceLabel + ", " + windowCount + (windowCount === 1 ? " window" : " windows") : "Workspace unavailable"
    Keys.onLeftPressed:navigate(-1)
    Keys.onRightPressed:navigate(1)
    Keys.onPressed:event=>{if(event.key===Qt.Key_Home){boundary(false);event.accepted=true;}else if(event.key===Qt.Key_End){boundary(true);event.accepted=true;}}
    Keys.onReturnPressed: if (workspace) root.focusWorkspace()
    Keys.onSpacePressed: if (workspace) root.focusWorkspace()

    function focusWorkspace(){if(!workspace)return;if(manager&&manager.focusWorkspace)manager.focusWorkspace(workspace.id);else workspace.activate();}

    function romanNumeral(value) {
        const number = Number(value);
        if (!Number.isInteger(number) || number < 1 || number > 3999)
            return String(value);
        const table = [
            [1000, "M"], [900, "CM"], [500, "D"], [400, "CD"],
            [100, "C"], [90, "XC"], [50, "L"], [40, "XL"],
            [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]
        ];
        let remainder = number;
        let result = "";
        for (let index = 0; index < table.length; index++) {
            while (remainder >= table[index][0]) {
                result += table[index][1];
                remainder -= table[index][0];
            }
        }
        return result;
    }

    SilverIslandFrame {
        drawFill: false
        objectName: "workspace-reflective-frame"
        z: -1
        parent: root
        anchors.fill: parent
        hoverGlow: true
        active: false
        hovered: root.enabled && !!root.workspace && root.hovered
    }
    ButtonHoverFrame {anchors.fill:parent;focusTarget:root;pointerTarget:pointer;focused:root.activeFocus;engaged:false}
    Column {
        anchors.centerIn: parent
        width: Math.max(1, parent.width - 12)
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.workspace ? root.workspaceLabel : "—"
            color: root.attention ? Config.Theme.warning : root.workspace && root.workspace.active ? Config.Theme.foreground : "#c9c4d5"
            font.family: "Audiowide"
            font.pixelSize: 16
            font.weight: Font.Normal
            font.letterSpacing: 0
            Behavior on color { ColorAnimation { duration: Config.Motion.duration(140) } }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            objectName: "workspace-window-summary"
            spacing: 3
            height: 18

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
            Text {
                objectName: "workspace-remaining-count"
                visible: root.remainingCount > 0
                width: Math.max(1, root.width - 33); height: 18
                text: root.remainingCount>99?"99+":"+"+root.remainingCount
                color: root.active ? Config.Theme.foreground : Config.Theme.muted
                font.family: Config.Theme.fontFamily; font.pixelSize: 11
                elide: Text.ElideRight; clip: true
                verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
                Accessible.name: root.remainingCount + " additional windows"
            }
        }
    }

    MouseArea {
        id: pointer
        parent: root
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.workspace)
                root.focusWorkspace();
        }
    }

}
