import QtQuick
import QtQuick.Window
import Quickshell
import "interaction" as Interaction
import "../config" as Config

Interaction.QuickPopoverWindow {
    id: root
    readonly property real availableWidth: (targetScreen || (anchorItem && anchorItem.Window.window)) ? (targetScreen ? targetScreen.width : anchorItem.Screen.width) - 2 * Config.Theme.screenInset : 432
    readonly property real availableHeight: (targetScreen || (anchorItem && anchorItem.Window.window)) ? (targetScreen ? targetScreen.height : anchorItem.Screen.height) - Config.Theme.railHeight - 2 * Config.Theme.screenInset : 800
    implicitWidth: Math.min(Math.max(1, availableWidth), trayContents.menuOpen ? 460 : Math.max(240, 2*popupFrame.contentInset+Math.min(4,trayContents.items.length)*104))
    implicitHeight: Math.min(Math.max(1, availableHeight), 2 * popupFrame.contentInset + trayContents.preferredHeight)
    color: "transparent"
    keyboardPriority: true
    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.rect.x: anchorItem ? anchorItem.width / 2 : 0
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.rect.y: -12
    focusTarget: card
    onCardShownChanged: if (cardShown) {
        const opening = lease;
        Qt.callLater(function() {
            if (root.requestedOpen && root.cardShown && root.lease === opening) trayContents.focusInitial();
        });
    }
    FocusScope {
        id: card
        anchors.fill: parent
        focus: root.cardShown
        opacity: root.presentationProgress
        transform: Translate {
            y: (1-root.presentationProgress)*Config.Motion.travel

        }

        Keys.onEscapePressed: if (!trayContents.back()) root.handleEscape()
        IslandPopupFrame {
            id: popupFrame
            frameKey: "tray"
            anchors.fill: parent
            tier: "standard"
            motif: "controls"
            active: true
            animate: false
            contentInset: Config.QuickPanelStyle.inset
            perimeterCorner: Config.QuickPanelStyle.corner
            TrayContents {
                id: trayContents; anchors.fill: parent; parentWindow: root
                surfaceOpen: root.requestedOpen && root.cardShown
                onDismissRequested: root.dismiss()
            }
        }
    }
}
