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
        font.family: Config.DirectoryStyle.bodyFont
        font.pixelSize: Config.DirectoryStyle.detailSize
        wrapMode: Text.WordWrap
    }
    Flow {
        id:choices
        width: parent.width
        TextMetrics {id:confirmMeasure;text:"Confirm clear";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
        readonly property int columns:width>=2*(confirmMeasure.advanceWidth+2*Config.DirectoryStyle.controlInset)+8?2:1
        readonly property real cellWidth:(width-(columns-1)*8)/columns
        spacing: 8
        visible: root.actions.actionState === "pending"
        QuietButton {
            id: cancel
            objectName: "notificationClearCancel"
            width: choices.cellWidth
            text: "Cancel"
            onClicked: root.actions.cancel()
        }
        QuietButton {
            objectName: "notificationClearConfirm"
            width: choices.cellWidth
            text: "Confirm clear"
            warning: true
            onClicked: root.actions.confirm(root.ownerContext)
        }
    }
}
