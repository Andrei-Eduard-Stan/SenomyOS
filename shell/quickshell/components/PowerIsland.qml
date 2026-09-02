import QtQuick
import QtQuick.Controls
import "../config" as Config

SenomyFrame {
    id: root

    property var powerService
    property bool panelOpen: false
    property alias panelAnchor: powerArea
    signal togglePower()

    width: 68
    height: Config.Theme.islandHeight
    motif: "power"

    Image {
        anchors.centerIn: parent
        width: 20
        height: 20
        source: "../assets/icons/power.svg"
        fillMode: Image.PreserveAspectFit
        opacity: powerService && powerService.available ? 0.88 : 0.42
    }

    MouseArea {
        id: powerArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: powerService && powerService.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (powerService && powerService.available) root.togglePower()
    }
    ToolTip.visible: powerArea.containsMouse
    ToolTip.delay: 450
    ToolTip.text: powerService && powerService.available
        ? (root.panelOpen ? "Close guarded session controls" : "Open guarded session controls")
        : "Session-action backend unavailable"
}
