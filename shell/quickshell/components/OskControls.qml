import QtQuick
import "../config" as Config
Column {
    id: root
    property var controller: null
    spacing: 8
    readonly property bool pending: controller && ["pending-start","pending-stop"].indexOf(controller.state) >= 0
    Row {
        width: parent.width; spacing: 8
        DashboardButton {
            objectName: "oskShow"; width: (parent.width - 16)/3
            text: root.controller && root.controller.owned ? "SHOW KEYBOARD" : "START KEYBOARD"
            enabled: root.controller && !root.pending && !root.controller.startPending && root.controller.state !== "stop-requested"
                && (root.controller.owned || root.controller.available())
            onClicked: root.controller.requestShow()
        }
        DashboardButton {
            objectName: "oskHide"; width: (parent.width - 16)/3; text: "HIDE"
            enabled: root.controller && root.controller.owned && !root.pending && !root.controller.startPending && root.controller.state !== "stop-requested"
            onClicked: root.controller.requestHide()
        }
        DashboardButton {
            objectName: "oskStop"; width: (parent.width - 16)/3; text: "STOP"
            enabled: root.controller && root.controller.owned && !root.pending && !root.controller.startPending && root.controller.state !== "stop-requested"
            onClicked: root.controller.requestStop()
        }
    }
    Column {
        id: review
        width: parent.width; spacing: 8; visible: root.pending
        ConfirmationFocus {
            view: review; actions: root.controller; actionState: root.controller ? root.controller.state : "idle"
            pendingStates: ["pending-start","pending-stop"]; cancelButton: cancel
        }
        Text {
            width: parent.width; text: root.controller ? root.controller.message : ""
            textFormat: Text.PlainText; color: Config.Theme.foreground
            font.family: Config.Theme.fontFamily; font.pixelSize: 10; wrapMode: Text.WordWrap
        }
        Row {
            width: parent.width; spacing: 8
            DashboardButton {
                id: cancel; objectName: "oskCancel"; width: (parent.width-8)/2; text: "CANCEL"
                onClicked: { if (root.controller.state === "pending-start") root.controller.cancelStart(); else root.controller.cancelStop(); }
            }
            DashboardButton {
                objectName: "oskConfirm"; width: (parent.width-8)/2
                text: root.controller && root.controller.state === "pending-start" ? "START FOR SESSION" : "CONFIRM STOP"
                onClicked: { if (root.controller.state === "pending-start") root.controller.confirmStart(); else root.controller.confirmStop(); }
            }
        }
    }
    Text {
        width: parent.width; visible: root.controller && !root.pending
        text: root.controller ? root.controller.message + (root.controller.owned && root.controller.provider.lockMessage !== undefined ? "\n" + root.controller.provider.lockMessage : "") : "Keyboard controls are unavailable."
        textFormat: Text.PlainText; color: Config.Theme.muted
        font.family: Config.Theme.fontFamily; font.pixelSize: 10; wrapMode: Text.WordWrap
    }
}
