import QtQuick
import QtQuick.Controls
import "../config" as Config

SenomyFrame {
    id: root

    width: 68
    height: Config.Theme.islandHeight
    motif: "power"

    Image {
        anchors.centerIn: parent
        width: 20
        height: 20
        source: "../assets/icons/power.svg"
        fillMode: Image.PreserveAspectFit
        opacity: 0.64
    }

    MouseArea {
        id: powerArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
    }
    ToolTip.visible: powerArea.containsMouse
    ToolTip.delay: 450
    ToolTip.text: "Power confirmation flow remains on Eww during Milestone 1"
}
