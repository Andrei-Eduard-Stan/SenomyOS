import QtQuick
import QtQuick.Window
import Quickshell
import "interaction" as Interaction
import "bluetooth" as BluetoothUi
import "../config" as Config

Interaction.QuickPopoverWindow {
    id:root
    keyboardPriority:true
    required property var bluetooth
    signal openSettingsRequested()
    readonly property real availableWidth:targetScreen?targetScreen.width-2*Config.Theme.screenInset:432
    readonly property real availableHeight:targetScreen?targetScreen.height-Config.Theme.railHeight-2*Config.Theme.screenInset:650
    implicitWidth:Math.min(Config.QuickPanelStyle.preferredWidth,Math.max(1,availableWidth))
    readonly property int knownCount:bluetooth.devices.filter(item=>item.connected || item.paired).length
    readonly property int neededHeight:440+Math.min(4,knownCount)*84+(bluetooth.actions.actionState==="pending"?160:bluetooth.actions.actionState==="failed"?80:0)+(bluetooth.prompt?190:0)+(bluetooth.error?48:0)
    property int heldHeight:neededHeight
    onNeededHeightChanged:heldHeight=requestedOpen?Math.max(heldHeight,neededHeight):neededHeight
    Connections {target:root;function onRequestedOpenChanged(){if(root.requestedOpen)root.heldHeight=root.neededHeight;}}
    implicitHeight:Math.min(heldHeight,Math.max(1,availableHeight))
    color:"transparent"
    anchor.item:anchorItem;anchor.edges:Edges.Top;anchor.gravity:Edges.Top
    anchor.rect.x:anchorItem?anchorItem.width/2:0;anchor.rect.width:0;anchor.rect.height:0;anchor.rect.y:-12
    focusTarget:card
    FocusScope {
        id:card;anchors.fill:parent;focus:root.cardShown;opacity: root.presentationProgress

        Keys.onEscapePressed:root.handleEscape()
        IslandPopupFrame {
            anchors.fill:parent;frameKey:"control";active:true;animate:false
            backdropColor:Config.QuickPanelStyle.surface;contentInset:Config.QuickPanelStyle.inset;perimeterCorner:Config.QuickPanelStyle.corner
            BluetoothUi.BluetoothLabel {width:parent.width-52;height:44;text:"// Bluetooth";font.family:Config.DirectoryStyle.headingFont;color:Config.DirectoryStyle.ink;verticalAlignment:Text.AlignVCenter}
            QuietButton {anchors.right:parent.right;width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf00d";accessibleLabel:"Close Bluetooth";onClicked:root.dismiss()}
            BluetoothUi.BluetoothPage {anchors.fill:parent;anchors.topMargin:52;service:root.bluetooth;quick:true;onFullSettingsRequested:root.openSettingsRequested()}
        }
    }
}
