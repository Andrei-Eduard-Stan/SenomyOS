import QtQuick
import "../../config" as Config
Text {
    width: parent ? parent.width : implicitWidth
    textFormat: Text.PlainText
    color: Config.DirectoryStyle.muted
    font.family: Config.DirectoryStyle.bodyFont
    font.pixelSize: Config.DirectoryStyle.detailSize
    lineHeight: 1.25
    wrapMode: Text.WordWrap
}
