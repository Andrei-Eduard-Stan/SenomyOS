import QtQuick
import "interaction" as Interaction
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import "../config" as Config

// Shared anchored lifecycle for new quick controls. Content has no ownership
// of backend subscriptions; ShellState supplies its exclusive route context.
Interaction.QuickPopoverWindow {
    id: root
    property string title: "SYSTEM CONTROLS"
    property string frameKey: "control"
    property int preferredHeight: 560
    default property alias bodyData: body.data
    readonly property real availableWidth: (targetScreen || (anchorItem && anchorItem.Window.window)) ? (targetScreen ? targetScreen.width : anchorItem.Screen.width)-2*Config.Theme.screenInset : 460
    readonly property real availableHeight: (targetScreen || (anchorItem && anchorItem.Window.window)) ? (targetScreen ? targetScreen.height : anchorItem.Screen.height)-Config.Theme.railHeight-2*Config.Theme.screenInset : 700
    implicitWidth: Math.min(460,Math.max(1,availableWidth))
    implicitHeight: Math.min(preferredHeight,Math.max(1,availableHeight))
    color: "transparent"
    // HyprlandFocusGrab owns focus; xdg_popup grabs need an input serial and
    // conflict with keyboard/IPC entry. Match the established audio popup.
    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.rect.x: anchorItem ? anchorItem.width / 2 : 0
    anchor.rect.width: 0
    anchor.rect.height: 0
    anchor.rect.y: -12
    focusTarget: card

    FocusScope {
        id:card;anchors.fill:parent;focus:root.cardShown
        opacity: root.presentationProgress

        Keys.onEscapePressed:root.handleEscape()
        CathedralPopupFrame {
            anchors.fill:parent;frameKey:root.frameKey;active:true
            animate:root.cardShown && !((Config.Skin.registry.persona || {}).reducedMotion)
            Text {
                width:Math.max(1,parent.width-52);height:44;text:root.title
                font.family:Config.DirectoryStyle.headingFont;font.pixelSize:13
                color:Config.DirectoryStyle.ink;verticalAlignment:Text.AlignVCenter
            }
            DashboardButton {anchors.right:parent.right;width:44;height:44;text:"×";headerControl:true;accessibleLabel:"Close "+root.title;onClicked:root.dismiss()}
            Item {id:body;anchors.fill:parent;anchors.topMargin:52}
        }
    }
}
