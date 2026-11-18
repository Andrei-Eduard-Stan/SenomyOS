import QtQuick
import "interaction" as Interaction
import "audio" as Audio
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import "../config" as Config

Interaction.QuickPopoverWindow {
    id: root

    required property var audio
    property var media
    signal openAudioRequested

    readonly property real availableWidth: (targetScreen || (anchorItem && anchorItem.Window.window)) ? (targetScreen ? targetScreen.width : anchorItem.Screen.width) - 2 * Config.Theme.screenInset : 460
    readonly property real availableHeight: (targetScreen || (anchorItem && anchorItem.Window.window)) ? (targetScreen ? targetScreen.height : anchorItem.Screen.height) - Config.Theme.railHeight - 2 * Config.Theme.screenInset : 800
    implicitWidth: Math.min(Config.QuickPanelStyle.preferredWidth, Math.max(1, availableWidth))
    implicitHeight: Math.min(availableHeight, Math.max(160, 2 * popupFrame.contentInset + Config.QuickPanelStyle.target + 16 + volumeControls.implicitHeight))
    color: "transparent"

    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.rect.x: anchorItem ? anchorItem.width / 2 : 0
    anchor.rect.width: 0
    anchor.rect.height: 0
    anchor.rect.y: -12

    focusTarget: card

    FocusScope {
        id: card
        anchors.fill: parent
        focus: root.cardShown
        opacity: root.presentationProgress
        scale: 1
        transform: Translate {
            y: (1-root.presentationProgress)*Config.Motion.travel

        }


        Keys.onEscapePressed: root.handleEscape()

        IslandPopupFrame {
            id: popupFrame
            frameKey: "volume"
            anchors.fill: parent
            tier: "standard"
            motif: "controls"
            active: true
            animate: false
            // Same clipped artwork/material as the Command Lens proposal.
            contentInset: Config.QuickPanelStyle.inset
            perimeterCorner: Config.QuickPanelStyle.corner
            backgroundItem.visible: false

            Column {
                anchors.fill: parent
                spacing: 16

                Row {
                    width: parent.width
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - closeButton.width - 8
                        text: "// Audio"
                        color: Config.QuickPanelStyle.ink
                        font.family: Config.QuickPanelStyle.headingFont
                        font.pixelSize: Config.QuickPanelStyle.titleSize
                        elide: Text.ElideMiddle
                        Rectangle {anchors.left:parent.left;anchors.leftMargin:Math.min(parent.width,parent.contentWidth+14);anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;height:1;color:Config.DirectoryStyle.rule}
                    }
                    Audio.AudioButton {
                        id:closeButton;objectName:"quickAudioClose"
                        width:Config.QuickPanelStyle.target;height:Config.QuickPanelStyle.target
                        iconOnly:true;glyph:"\uf00d";accessibleLabel:"Close Audio"
                        onClicked:root.dismiss()
                    }
                }

                FocusScrollArea {
                    id:audioScroll
                    width: parent.width
                    height: Math.max(0, parent.height - Config.QuickPanelStyle.target - 16)
                    contentHeight: volumeControls.implicitHeight
                    ScrollBar.vertical: ShellScrollBar {}
                    Audio.AudioQuickControls {
                        id:volumeControls
                        width:parent.width
                        audio:root.audio
                        media:root.media || null
                        mediaActive:root.cardShown && root.requestedOpen
                        viewport:audioScroll
                        onOpenAudioRequested:root.openAudioRequested()
                    }
                }
            }
        }
    }
}
