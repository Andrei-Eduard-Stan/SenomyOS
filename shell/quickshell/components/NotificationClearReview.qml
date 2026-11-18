import QtQuick
import "../config" as Config

Column {
    id: root
    required property var actions
    required property string ownerContext
    ConfirmationFocus { view: root; actions: root.actions; cancelButton: cancel }
    spacing: 8
    visible: actions.actionState !== "idle" && actions.requestedContext === ownerContext
    Text {
        width: parent.width
        text: root.actions.actionState === "pending" ? root.actions.impact : root.actions.message
        textFormat: Text.PlainText
        color: root.actions.actionState === "failed" ? Config.Theme.danger : Config.Theme.foreground
        font.family: Config.Theme.fontFamily
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
    Row {
        width: parent.width
        spacing: 8
        visible: root.actions.actionState === "pending"
        DashboardButton {
            id: cancel
            objectName: "notificationClearCancel"
            width: (parent.width - 8) / 2
            text: "CANCEL"
            onClicked: root.actions.cancel()
        }
        DashboardButton {
            objectName: "notificationClearConfirm"
            width: (parent.width - 8) / 2
            text: "CONFIRM CLEAR"
            accentColor: Config.Theme.danger
            onClicked: root.actions.confirm(root.ownerContext)
        }
    }
}
