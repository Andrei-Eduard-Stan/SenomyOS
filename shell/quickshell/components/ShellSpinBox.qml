import QtQuick
import QtQuick.Controls
import "../config" as Config

SpinBox {
    id: root
    readonly property real stepTargetWidth: Config.DirectoryStyle.touchMode ? Math.max(36, Config.Theme.touchTarget) : 36
    implicitHeight: Math.max(44, Config.Theme.touchTarget)
    leftPadding: stepTargetWidth
    rightPadding: stepTargetWidth
    font.family: Config.DirectoryStyle.bodyFont
    font.pixelSize: Config.DirectoryStyle.bodySize
    opacity: enabled ? 1 : 0.46
    contentItem: TextInput {
        text: root.displayText
        font: root.font
        color: Config.DirectoryStyle.ink
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        readOnly: !root.editable
        validator: root.validator
        inputMethodHints: root.inputMethodHints
        selectByMouse: true
        clip: true
        selectionColor: Config.DirectoryStyle.selection
        selectedTextColor: Config.DirectoryStyle.ink
    }
    up.indicator: Rectangle {
        x: root.mirrored ? 0 : root.width - width
        width: root.stepTargetWidth
        height: root.height
        color: "transparent"
        ButtonHoverFrame { anchors.fill: parent; engaged: root.enabled && root.up.hovered }
        Text {
            anchors.centerIn: parent
            text: "+"
            color: Config.DirectoryStyle.ink
            font.family: Config.DirectoryStyle.bodyFont
            font.pixelSize: 18
        }
    }
    down.indicator: Rectangle {
        x: root.mirrored ? root.width - width : 0
        width: root.stepTargetWidth
        height: root.height
        color: "transparent"
        ButtonHoverFrame { anchors.fill: parent; engaged: root.enabled && root.down.hovered }
        Text {
            anchors.centerIn: parent
            text: "−"
            color: Config.DirectoryStyle.ink
            font.family: Config.DirectoryStyle.bodyFont
            font.pixelSize: 18
        }
    }
    background: Rectangle {
        color: Config.Theme.glassRaised
        border.width: root.activeFocus ? 1 : 0
        border.color: Config.DirectoryStyle.ink
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Config.DirectoryStyle.rule
        }
    }
}
