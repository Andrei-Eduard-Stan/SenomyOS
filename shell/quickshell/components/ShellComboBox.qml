import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "../config" as Config

ComboBox {
    id: root
    hoverEnabled: true
    property bool keyboardNavigation:false
    Keys.onPressed:event=>{if([Qt.Key_Up,Qt.Key_Down,Qt.Key_Home,Qt.Key_End,Qt.Key_Space,Qt.Key_Return].includes(event.key))keyboardNavigation=true;event.accepted=false;}
    ButtonHoverFrame { focused: root.visualFocus; anchors.fill: parent; selected: root.popup.visible; engaged: root.enabled && root.hovered }
    implicitHeight: Math.max(Config.DirectoryStyle.controlTarget, contentItem.implicitHeight + 2 * Config.DirectoryStyle.controlVerticalInset)
    topPadding:Config.DirectoryStyle.controlVerticalInset
    bottomPadding:Config.DirectoryStyle.controlVerticalInset
    leftPadding: Config.DirectoryStyle.controlInset
    rightPadding: Config.DirectoryStyle.controlInset + 16 + Config.DirectoryStyle.controlGap
    font.family: Config.DirectoryStyle.bodyFont
    font.pixelSize: Config.DirectoryStyle.bodySize
    palette.text: Config.DirectoryStyle.ink
    palette.buttonText: Config.DirectoryStyle.ink
    palette.base: "transparent"
    palette.highlight: Config.DirectoryStyle.selection
    palette.highlightedText: Config.DirectoryStyle.ink
    opacity: enabled ? 1 : 0.46
    contentItem: Text {
        text: root.displayText
        color: Config.DirectoryStyle.ink
        font: root.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: parent.width - width - Config.DirectoryStyle.controlInset
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        text: root.popup.visible ? "⌃" : "⌄"
        horizontalAlignment: Text.AlignHCenter
        color: Config.DirectoryStyle.ink
        font.family: Config.DirectoryStyle.bodyFont
        font.pixelSize: 18
    }
    background: Rectangle {
        color: "transparent"
        border.width: 0
        border.color: Config.DirectoryStyle.ink
    }
    delegate: ItemDelegate {
        id: choice
        hoverEnabled: true
        ButtonHoverFrame { focused: choice.visualFocus || (root.keyboardNavigation && choice.highlighted); anchors.fill: parent; selected: false; engaged: choice.enabled && choice.hovered }
        required property int index
        width: ListView.view.width
        leftPadding:Config.DirectoryStyle.controlInset;rightPadding:Config.DirectoryStyle.controlInset
        topPadding:Config.DirectoryStyle.controlVerticalInset;bottomPadding:Config.DirectoryStyle.controlVerticalInset
        height:Math.max(Config.DirectoryStyle.controlTarget,contentItem.implicitHeight+topPadding+bottomPadding)
        text: root.textAt(index)
        highlighted: root.highlightedIndex === index
        onHoveredChanged:if(hovered)root.keyboardNavigation=false
        contentItem: Text {
            text: parent.text
            color: Config.DirectoryStyle.ink
            font.family: Config.DirectoryStyle.bodyFont
            font.pixelSize: Config.DirectoryStyle.bodySize
            verticalAlignment: Text.AlignVCenter
            wrapMode:Text.WordWrap
        }
        background: Rectangle {
            color:choice.index===root.currentIndex?Config.DirectoryStyle.selection:"transparent"
            border.width: 0
            border.color: Config.DirectoryStyle.ink
        }
    }
    popup: Popup {
        onOpened:root.keyboardNavigation=root.visualFocus
        onClosed:root.keyboardNavigation=false
        y: root.height
        width: root.width
        padding: 10
        height: Math.min(choices.contentHeight + 20, root.Window.window ? Math.max(80, root.Window.window.height * 0.55) : 320)
        background: ShellSurfaceFrame {
            contentInset: 0
            perimeterCorner: 16
            backdropColor: Config.Theme.surfaceRaised
            stateColor: "transparent"
            animate: root.popup.visible && !((Config.Skin.registry.persona || {}).reducedMotion)
        }
        contentItem: ListView {
            id: choices
            Keys.onPressed:event=>{root.keyboardNavigation=true;event.accepted=false;}
            clip: true
            implicitHeight: contentHeight
            model: root.delegateModel
            currentIndex: root.highlightedIndex
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: if (currentIndex >= 0)
                positionViewAtIndex(currentIndex, ListView.Contain)
            ScrollBar.vertical: ShellScrollBar {}
        }
    }
}
