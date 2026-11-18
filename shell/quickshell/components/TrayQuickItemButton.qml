import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../config" as Config

QuietButton {
    id: root
    required property var trayItem
    required property var parentWindow
    readonly property bool compact: false
    readonly property bool attention: !!trayItem && trayItem.status === Status.NeedsAttention
    readonly property string label: String(trayItem && (trayItem.tooltipTitle || trayItem.title || trayItem.id) || "Application")
    readonly property string detail: !trayItem ? "Item unavailable" : attention ? "Needs attention" : trayItem.onlyMenu ? (trayItem.hasMenu ? "Application menu" : "Menu unavailable") : trayItem.status === Status.Passive ? "Passive status" : "Open application"
    readonly property bool primaryAvailable: !!trayItem && (!trayItem.onlyMenu || trayItem.hasMenu)
    readonly property bool menuAvailable: !!trayItem && !!trayItem.hasMenu
    signal menuRequested()
    width: Config.Theme.touchTarget
    height: Config.Theme.touchTarget
    enabled: primaryAvailable
    opacity: primaryAvailable ? 1 : 0.5
    focusPolicy: primaryAvailable ? Qt.TabFocus : Qt.NoFocus
    padding: 0
    down: pointer.pressed
    accessibleLabel: label + (detail ? ". " + detail : "")
    contentItem: Item {}
    // Qt keeps focusReason when forceActiveFocus targets an already focused item.
    function focusForReason(reason) { focusReason = reason; forceActiveFocus(reason); }
    activeFocusOnTab: primaryAvailable
    Accessible.role: Accessible.Button
    Accessible.name: label + (detail ? ". " + detail : "") + (menuAvailable ? ". Menu: right-click, hold, Menu key or Shift F10" : "")
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
    background.visible:visualFocus || down
    ToolTip.visible:false
    Item {
        id:iconSlot;x:(root.width-32)/2;y:8;width:32;height:36
        IconImage {id:itemIcon;anchors.centerIn:parent;width:32;height:32;source:root.trayItem?root.trayItem.icon || "":"";opacity:root.trayItem && root.trayItem.status===Status.Passive?.6:1}
        Image {anchors.centerIn:parent;width:28;height:28;visible:!root.trayItem || !root.trayItem.icon || itemIcon.status===Image.Error;source:"../assets/icons/applications.svg"}
        Rectangle {visible:root.attention;anchors.right:parent.right;anchors.top:parent.top;width:14;height:14;radius:7;color:Config.Theme.surface;Text {anchors.centerIn:parent;text:"!";color:Config.Theme.warning;font.bold:true;font.pixelSize:12}}
    }
    Text {x:4;y:iconSlot.y+iconSlot.height+6;width:parent.width-8;text:root.label;textFormat:Text.PlainText;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;Accessible.ignored:true}
    ToolTip {id:fullName;visible:pointer.containsMouse;delay:650;text:root.label+(root.attention?" · Needs attention":"");contentItem:Text {text:fullName.text;textFormat:Text.PlainText;font:fullName.font;color:fullName.palette.toolTipText;wrapMode:Text.Wrap}}
    MouseArea {
        id: pointer; anchors.fill: parent
        property bool heldMenu:false
        onPressed:heldMenu=false
        onPressAndHold:mouse=>{if(root.menuAvailable){heldMenu=true;root.menuRequested();mouse.accepted=true;}else mouse.accepted=false;}
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (!root.trayItem || heldMenu) return;
            root.focusForReason(Qt.MouseFocusReason);
            if (mouse.button === Qt.RightButton) root.menuOrSecondary();
            else if (mouse.button === Qt.MiddleButton) root.trayItem.secondaryActivate();
            else root.activate();
        }
        onWheel: wheel => {
            if (!root.trayItem) { wheel.accepted = false; return; }
            // The icon retains the native app's scroll action. Scrolling the
            // label scrolls a long tray list instead of changing an app setting.
            if (!root.compact && (wheel.x < iconSlot.x || wheel.x > iconSlot.x + iconSlot.width || wheel.y < iconSlot.y || wheel.y > iconSlot.y+iconSlot.height)) { wheel.accepted = false; return; }
            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y);
            root.trayItem.scroll(horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal);
            wheel.accepted = true;
        }
    }
    QuietButton {
        id:touchMenu
        objectName:root.objectName.replace("tray-app-","tray-touch-menu-")
        anchors.right:parent.right;anchors.top:parent.top
        width:Config.DirectoryStyle.controlTarget;height:width
        visible:Config.DirectoryStyle.touchMode && root.menuAvailable
        iconOnly:true;glyph:"\uf142";accessibleLabel:"Open menu for "+root.label
        background.visible:visualFocus || down
        onClicked:root.menuRequested()
    }
}
