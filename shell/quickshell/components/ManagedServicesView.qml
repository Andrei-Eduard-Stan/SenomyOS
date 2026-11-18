import QtQuick
import "../config" as Config

Column {
    id: root
    required property var services
    spacing: 10
    DashboardCard { width: parent.width; title: "USER AUDIO SERVICES"; value: root.services.available ? "MANAGED RESTART" : "UNAVAILABLE"; detail: "Only supported user audio services can be restarted here. Other services remain read-only." }
    SelectionActionReview { width: parent.width; actions: root.services.actions }
    Text { width: parent.width; visible: root.services.error.length > 0; text: root.services.error; color: Config.Theme.warning; font.family: Config.Theme.fontFamily; wrapMode: Text.WordWrap }
    Repeater {
        model: root.services.items
        delegate: DashboardButton {
            required property var modelData
            width: root.width
            text: modelData.unit
            detail: modelData.state + " · " + (modelData.restartAllowed ? "REVIEW RESTART" : "READ-ONLY")
            enabled: modelData.restartAllowed && !root.services.actions.locked && !root.services.actions.blocked
            onClicked: root.services.actions.request(modelData)
        }
    }
}
