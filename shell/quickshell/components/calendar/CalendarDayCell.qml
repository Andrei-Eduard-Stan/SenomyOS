import QtQuick
import ".." as UI
import QtQuick.Controls
import "../../config" as Config

AbstractButton {
    id: root
    required property date date
    property bool selected: false
    property bool today: false
    property bool inMonth: true
    property int eventCount: 0
    objectName: "quick-calendar-day-" + Qt.formatDate(date, "yyyy-MM-dd")
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.Button
    Accessible.name: Qt.formatDate(date, "dddd, d MMMM yyyy")
        + (today ? ". Today" : "") + (selected ? ". Selected" : "")
        + (eventCount > 0 ? ". " + eventCount + (eventCount === 1 ? " saved item" : " saved items") : "")
    Accessible.onPressAction: if (enabled) clicked()
    background: Rectangle {
        color: "transparent"
        border.width: 0
        border.color: Config.DirectoryStyle.ink
    }
    UI.ButtonHoverFrame { focused: root.visualFocus; selected: root.selected; anchors.fill: parent; engaged: root.enabled && root.hovered }
    contentItem: Item {
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: Qt.locale().toString(root.date, "d")
            textFormat: Text.PlainText
            color: !root.enabled ? Config.DirectoryStyle.dim
                : root.inMonth ? Config.DirectoryStyle.ink : Config.DirectoryStyle.dim
            font.family: Config.DirectoryStyle.bodyFont
            font.pixelSize: Math.round(15 * Config.DirectoryStyle.textScale)
            font.weight: root.today || root.selected ? Font.DemiBold : Font.Normal
        }
        // Today is an underline; real event presence is a dot. Neither relies
        // on colour, and both remain visible inside the selected date outline.
        Rectangle {
            visible: root.today
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 7; width: 16; height: 2
            color: Config.DirectoryStyle.ink
        }
        Rectangle {
            visible: root.eventCount > 0
            x: parent.width - 8; y: 5; width: 3; height: 3; radius: 2
            color: Config.DirectoryStyle.ink
        }
    }
    ToolTip.visible: hovered
    ToolTip.delay: 700
    ToolTip.text: Accessible.name
}
