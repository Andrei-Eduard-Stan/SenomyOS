import QtQuick
import ".."
import "../../config" as Config

Column {
    id: root
    property var items: []
    property string selectedKey: ""
    property string pickedKey: ""
    onSelectedKeyChanged: pickedKey = ""
    readonly property string effectiveKey: pickedKey || selectedKey
    readonly property var selected: items.find(n => n.name === effectiveKey) || null
    spacing: 8
    Text {
        width: parent.width
        visible: root.items.length === 0
        text: "No devices reported in this group."
        wrapMode: Text.WordWrap
        color: Config.DirectoryStyle.muted
        font.family: Config.DirectoryStyle.dataFont
        font.pixelSize: 12
    }
    Column {
        visible: !!root.selected
        width: parent.width
        spacing: 6
        Text {
            width: parent.width
            text: root.selected ? root.selected.name : ""
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            color: Config.DirectoryStyle.ink
            font.family: Config.DirectoryStyle.headingFont
            font.pixelSize: 14
        }
        Text {
            width: parent.width
            text: root.selected ? root.detail(root.selected) : ""
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Config.DirectoryStyle.muted
            font.family: Config.DirectoryStyle.dataFont
            font.pixelSize: 12
        }
        Rectangle {
            width: parent.width
            height: 1
            color: Config.DirectoryStyle.rule
        }
    }
    function detail(item) {
        return item.width !== undefined ? item.width + " × " + item.height + " · " + Number(item.refreshRate).toFixed(2) + " Hz\nScale " + item.scale + " · Position " + item.x + ", " + item.y + "\n" + (item.disabled ? "Disabled" : "Enabled") + " · " + (item.dpmsStatus ? "Display power on" : "Display power off") : item.kind + (item.layout ? " · Keymap " + item.layout : "") + " · Reported by the compositor";
    }
    Repeater {
        model: root.items
        delegate: ControlWorkspaceButton {
            required property var modelData
            objectName: "control-device-" + encodeURIComponent(modelData.name)
            width: root.width
            height: Math.max(64,implicitHeight)
            wrapLabel:true;wrapDetail:true
            text: modelData.name || "Unnamed device"
            detail: modelData.kind || (modelData.disabled ? "Display disabled" : "Display connected")
            active: root.effectiveKey === modelData.name
            onClicked: root.pickedKey = modelData.name
        }
    }
}
