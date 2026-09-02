import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../config" as Config

Item {
    id: root

    required property var trayItem
    required property var parentWindow

    width: Config.Theme.touchTarget
    height: Config.Theme.touchTarget

    readonly property bool attention: trayItem.status === Status.NeedsAttention
    readonly property string label: trayItem.tooltipTitle.length > 0
        ? trayItem.tooltipTitle : trayItem.title.length > 0 ? trayItem.title : trayItem.id

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: pointer.containsMouse ? Config.Theme.surfaceHover : Config.Theme.surfaceRaised
        border.width: root.attention ? 1 : 0
        border.color: Config.Theme.warning
    }

    IconImage {
        id: itemIcon
        anchors.centerIn: parent
        width: 22
        height: 22
        source: root.trayItem.icon
        opacity: root.trayItem.status === Status.Passive ? 0.55 : 1
    }

    Text {
        visible: itemIcon.status === Image.Error || root.trayItem.icon.length === 0
        anchors.centerIn: parent
        text: root.attention ? "!" : "•"
        color: root.attention ? Config.Theme.warning : Config.Theme.muted
        font.family: Config.Theme.fontFamily
        font.pixelSize: 16
        font.weight: Font.Bold
    }

    QsMenuAnchor {
        id: contextMenu
        menu: root.trayItem.hasMenu ? root.trayItem.menu : null
        anchor.item: root
        anchor.edges: Edges.Top | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Right
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (root.trayItem.hasMenu)
                    contextMenu.open();
                else
                    root.trayItem.secondaryActivate();
            } else if (mouse.button === Qt.MiddleButton) {
                root.trayItem.secondaryActivate();
            } else if (root.trayItem.onlyMenu && root.trayItem.hasMenu) {
                contextMenu.open();
            } else {
                root.trayItem.activate();
            }
        }
        onWheel: wheel => {
            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
            root.trayItem.scroll(horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal);
            wheel.accepted = true;
        }
    }

    ToolTip.visible: pointer.containsMouse
    ToolTip.delay: 450
    ToolTip.text: root.label + (root.trayItem.tooltipDescription.length > 0
        ? "\n" + root.trayItem.tooltipDescription : "")
}
