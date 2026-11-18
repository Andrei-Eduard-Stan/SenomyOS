import QtQuick
import QtQuick.Controls
import "../config" as Config

TextField {
    id: root
    implicitHeight: Math.max(44, Config.Theme.touchTarget)
    padding: Config.DirectoryStyle.controlInset
    color: Config.DirectoryStyle.ink
    placeholderTextColor: Config.DirectoryStyle.dim
    font.family: Config.DirectoryStyle.bodyFont
    font.pixelSize: Config.DirectoryStyle.bodySize
    selectionColor: Config.DirectoryStyle.selection
    selectedTextColor: Config.DirectoryStyle.ink
    selectByMouse: true
    opacity: enabled ? 1 : 0.46
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
