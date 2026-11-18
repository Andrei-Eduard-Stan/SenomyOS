import QtQuick
import ".." as UI
import QtQuick.Controls
import "../../config" as Config

AbstractButton {
    id: root
    required property var audio
    required property var node
    property bool input: false
    readonly property bool current: node === (input ? audio.source : audio.sink)
    readonly property string deviceName: node.description || node.nickname || node.name || "Audio device"
    objectName: "quickDevice-" + (node.name || "")
    enabled: audio.ready && node.ready && !current && !audio.actionsLocked
    opacity: audio.ready ? 1 : 0.46
    hoverEnabled: true
    activeFocusOnTab: enabled
    Accessible.name: deviceName + (current ? ", current " : ", select ") + (input ? "input" : "output")
    implicitHeight: Math.max(Config.QuickPanelStyle.target, label.implicitHeight + 2*Config.DirectoryStyle.controlVerticalInset)
    Keys.onReturnPressed: if (enabled) clicked()
    onClicked: input ? audio.selectInput(node) : audio.selectOutput(node)
    background: Rectangle {
        color: root.current?Config.DirectoryStyle.selection:"transparent"
        border.width: 0
        border.color: Config.QuickPanelStyle.ink
    }
    padding:0
    UI.ButtonHoverFrame { focused: root.visualFocus; selected: false; anchors.fill: parent; engaged: false }
    contentItem: Item {
        Text {
            id: label
            x: Config.DirectoryStyle.controlInset
            width: Math.max(0, parent.width - x - stateLabel.width - Config.DirectoryStyle.controlGap - Config.DirectoryStyle.controlInset)
            anchors.verticalCenter: parent.verticalCenter
            text: root.deviceName
            textFormat: Text.PlainText
            color: Config.QuickPanelStyle.ink
            font.family: Config.QuickPanelStyle.bodyFont
            font.pixelSize: Config.QuickPanelStyle.bodySize
            wrapMode: Text.Wrap
        }
        Text {
            id:stateLabel
            anchors.right: parent.right
            anchors.rightMargin: Config.DirectoryStyle.controlInset
            anchors.verticalCenter: parent.verticalCenter
            text: root.current ? "CURRENT" : "SELECT ›"
            color: Config.QuickPanelStyle.secondary
            font.family: Config.QuickPanelStyle.dataFont
            font.pixelSize: Math.max(12, Config.QuickPanelStyle.metadataSize)
        }
    }
}
