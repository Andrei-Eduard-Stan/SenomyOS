import QtQuick
import QtQuick.Window
import Quickshell
import "interaction" as Interaction
import "../config" as Config

Interaction.QuickPopoverWindow {
    id:root
    required property var powerService
    readonly property real availableWidth:(targetScreen||(anchorItem&&anchorItem.Window.window))?(targetScreen?targetScreen.width:anchorItem.Screen.width)-2*Config.Theme.screenInset:432
    readonly property real availableHeight:(targetScreen||(anchorItem&&anchorItem.Window.window))?(targetScreen?targetScreen.height:anchorItem.Screen.height)-Config.Theme.railHeight-2*Config.Theme.screenInset:800
    implicitWidth:Math.min(480,Math.max(1,availableWidth))
    implicitHeight:Math.min(Math.max(1,availableHeight),2*popupFrame.contentInset+powerContents.preferredHeight)
    color:"transparent"
    keyboardPriority:true
    anchor.item:anchorItem
    anchor.edges:Edges.Top;anchor.gravity:Edges.Top
    anchor.rect.x:anchorItem?anchorItem.width/2:0
    anchor.rect.width:1;anchor.rect.height:1;anchor.rect.y:-12
    focusTarget:card
    onPreparing:powerContents.opening()
    onCardShownChanged:if(cardShown){const opening=lease;Qt.callLater(()=>{if(root.requestedOpen&&root.cardShown&&root.lease===opening)powerContents.focusInitial();});}
    FocusScope {
        id: card
        anchors.fill:parent;focus:root.cardShown;opacity: root.presentationProgress
        Keys.onEscapePressed:if(!powerContents.back())root.handleEscape()
        transform:Translate {y: (1-root.presentationProgress)*Config.Motion.travel}
        IslandPopupFrame {
            id:popupFrame;frameKey:"power";anchors.fill:parent;tier:"standard";motif:"power";active:true;animate:false
            contentInset:Config.QuickPanelStyle.inset;perimeterCorner:Config.QuickPanelStyle.corner
            PowerQuickContents {id:powerContents;anchors.fill:parent;service:root.powerService;surfaceOpen:root.requestedOpen&&root.cardShown;resetOnOpen:false;onDismissRequested:root.dismiss()}
        }
    }
}
