import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../config" as Config

Control {
    id: root
    required property var trayItem
    required property var parentWindow
    property bool compact: true
    readonly property bool attention: !!trayItem && trayItem.status === Status.NeedsAttention
    readonly property string label: String(trayItem && (trayItem.tooltipTitle || trayItem.title || trayItem.id) || "Application")
    readonly property string detail: !trayItem ? "Item unavailable" : attention ? "Needs attention" : trayItem.onlyMenu ? (trayItem.hasMenu ? "Application menu" : "Menu unavailable") : trayItem.status === Status.Passive ? "Passive status" : ""
    readonly property bool primaryAvailable: !!trayItem && (!trayItem.onlyMenu || trayItem.hasMenu)
    signal menuRequested()
    width: Config.Theme.touchTarget
    height: Config.Theme.touchTarget
    enabled: primaryAvailable
    opacity: primaryAvailable ? 1 : 0.5
    focusPolicy: primaryAvailable ? Qt.TabFocus : Qt.NoFocus
    padding: 0
    // Qt keeps focusReason when forceActiveFocus targets an already focused item.
    function focusForReason(reason) { focusReason = reason; forceActiveFocus(reason); }
    activeFocusOnTab: primaryAvailable
    Accessible.role: Accessible.Button
    Accessible.name: label + (detail ? ". " + detail : "") + (!primaryAvailable ? "" : trayItem.onlyMenu ? ". Open menu" : ". Open application")
    Accessible.onPressAction: root.activate()
    function activate() {
        if (!primaryAvailable) return;
        if (trayItem.onlyMenu) menuRequested();
        else trayItem.activate();
    }
    function menuOrSecondary() { if (!trayItem) return; if (trayItem.hasMenu) menuRequested(); else trayItem.secondaryActivate(); }
    Keys.onReturnPressed: { root.focusForReason(Qt.TabFocusReason); activate(); }
    Keys.onSpacePressed: { root.focusForReason(Qt.TabFocusReason); activate(); }
    Keys.onMenuPressed: if (trayItem.hasMenu) { root.focusForReason(Qt.TabFocusReason); menuRequested(); }
    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Escape) root.focusForReason(Qt.TabFocusReason);
        if (event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier && trayItem.hasMenu) { menuRequested(); event.accepted = true; }
    }
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 0
        border.color: Config.DirectoryStyle.ink
    }
    ButtonHoverFrame { focused: root.visualFocus; pointerTarget: pointer; anchors.fill: parent; engaged: root.enabled && pointer.containsMouse }
    Item {
        id: iconSlot
        x:root.compact?0:Config.DirectoryStyle.controlInset
        width: root.compact ? root.width : 28
        height: parent.height
        IconImage {
            id: itemIcon
            anchors.centerIn: parent; width: root.compact ? 22 : 28; height: width
            source: root.trayItem ? root.trayItem.icon || "" : ""
            opacity: root.trayItem && root.trayItem.status === Status.Passive ? 0.6 : 1
        }
        Image {
            anchors.centerIn: parent; width: 24; height: 24
            visible: !root.trayItem || !root.trayItem.icon || itemIcon.status === Image.Error
            source: "../assets/icons/applications.svg"
        }
        Rectangle {
            visible: root.attention
            anchors.right: parent.right; anchors.top: parent.top
            anchors.topMargin: Math.max(2, (parent.height - 32) / 2); anchors.rightMargin: 1
            width: 14; height: 14; radius: 7; color: Config.Theme.surface
            Text { anchors.centerIn: parent; text: "!"; color: Config.Theme.warning; font.bold: true; font.pixelSize: 12 }
        }
    }
    Column {
        visible: !root.compact
        x: iconSlot.x+iconSlot.width+Config.DirectoryStyle.controlGap; width: Math.max(1, parent.width - x - Config.DirectoryStyle.controlInset)
        anchors.verticalCenter: parent.verticalCenter; spacing: 4
        Text {
            width: parent.width; text: root.label; textFormat: Text.PlainText
            maximumLineCount: 1; elide: Text.ElideRight
            color: Config.DirectoryStyle.ink; font.family: Config.DirectoryStyle.bodyFont
            font.pixelSize: Config.QuickPanelStyle.deviceSize; font.weight: Font.DemiBold
        }
        Text {
            visible: !!root.detail
            width: parent.width; text: root.detail; textFormat: Text.PlainText
            maximumLineCount: 1; elide: Text.ElideRight
            color: root.attention ? Config.Theme.warning : Config.DirectoryStyle.muted
            font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.detailSize
        }
    }
    MouseArea {
        id: pointer; anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (!root.trayItem) return;
            root.focusForReason(Qt.MouseFocusReason);
            if (mouse.button === Qt.RightButton) root.menuOrSecondary();
            else if (mouse.button === Qt.MiddleButton) root.trayItem.secondaryActivate();
            else root.activate();
        }
        onWheel: wheel => {
            if (!root.trayItem) { wheel.accepted = false; return; }
            // The icon retains the native app's scroll action. Scrolling the
            // label scrolls a long tray list instead of changing an app setting.
            if (!root.compact && wheel.x > iconSlot.width) { wheel.accepted = false; return; }
            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
            root.trayItem.scroll(horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal);
            wheel.accepted = true;
        }
    }
}
