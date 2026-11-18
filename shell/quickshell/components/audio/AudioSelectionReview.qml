import QtQuick
import ".."
import "../../config" as Config

Column {
    id: root
    required property var actions
    ConfirmationFocus { view: root; actions: root.actions; cancelButton: cancel }
    spacing: 8
    visible: actions.actionState !== "idle"
    Text {
        width: parent.width
        text: root.actions.title
        textFormat: Text.PlainText
        color: Config.Theme.foreground
        font.family: Config.Theme.fontFamily
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
    Text {
        width: parent.width
        text: root.actions.actionState === "pending" ? root.actions.impact
            : root.actions.actionState.toUpperCase() + " // " + root.actions.message
        textFormat: Text.PlainText
        color: root.actions.actionState === "failed" ? Config.Theme.danger : Config.Theme.muted
        font.family: Config.Theme.fontFamily
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
    Row {
        width: parent.width
        spacing: 8
        visible: root.actions.actionState === "pending"
        AudioButton {
            id: cancel
            objectName: "selectionCancel"
            width: (parent.width - 8) / 2
            text: "Cancel"
            onClicked: root.actions.cancel()
        }
        AudioButton {
            objectName: "selectionConfirm"
            width: (parent.width - 8) / 2
            text: "Confirm"
            accessibleLabel:"Confirm audio device change"
            onClicked: root.actions.confirm()
        }
    }
}
