import QtQuick
import QtQuick.Controls
import "../config" as Config
ToolTip {
    id: root
    padding: 10
    width: Math.min(360, implicitWidth)
    contentItem: Text {
        text: root.text
        textFormat: Text.PlainText
        color: Config.DirectoryStyle.ink
        font.family: Config.Theme.fontFamily
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }
    background: Rectangle {
        SurfaceBackground { anchors.fill: parent; anchors.margins: 4; fillKey: "tooltip" }
        radius: 0
        color: "#f2080a0c"
        border.color: Config.DirectoryStyle.rule
    }
}
