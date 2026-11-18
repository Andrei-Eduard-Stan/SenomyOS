pragma ComponentBehavior: Bound
import QtQuick
import "../../config" as Config
Text {
    width: parent ? parent.width : implicitWidth
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: Config.DirectoryStyle.muted
    font.family: Config.DirectoryStyle.bodyFont
    font.pixelSize: Config.DirectoryStyle.detailSize
}
