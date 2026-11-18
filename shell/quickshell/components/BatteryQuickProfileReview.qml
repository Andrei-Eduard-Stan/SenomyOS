import QtQuick
import "../config" as Config

Column {
    id: root
    required property var actions
    property string confirmLabel:"Confirm power-profile change"
    ConfirmationFocus { view: root; actions: root.actions; cancelButton: cancel }
    spacing: 8
    visible: actions.actionState !== "idle"
    Text {
        width: parent.width
        text: root.actions.title
        textFormat: Text.PlainText
        color: Config.Theme.foreground
        font.family: Config.DirectoryStyle.bodyFont
        font.pixelSize: Config.DirectoryStyle.detailSize
        wrapMode: Text.WordWrap
    }
    Text {
        width: parent.width
        text: root.actions.actionState === "pending" ? root.actions.impact
            : root.actions.actionState.toUpperCase() + " // " + root.actions.message
        textFormat: Text.PlainText
        color: root.actions.actionState === "failed" ? Config.Theme.danger : Config.Theme.muted
        font.family: Config.DirectoryStyle.bodyFont
        font.pixelSize: Config.DirectoryStyle.detailSize
        wrapMode: Text.WordWrap
    }
    Row {
        width: parent.width
        spacing: 8
        visible: root.actions.actionState === "pending"
        QuietButton {
            id: cancel
            objectName: "selectionCancel"
            width: (parent.width - 8) / 2
            text: "Cancel"
            onClicked: root.actions.cancel()
        }
        QuietButton {
            objectName: "selectionConfirm"
            width: (parent.width - 8) / 2
            text: "Confirm"
            accessibleLabel:root.confirmLabel
            onClicked: root.actions.confirm()
        }
    }
}
