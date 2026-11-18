import QtQuick
import "../../config" as Config
Text {
    property string message: ""
    text: message; visible: message.length>0; width: parent.width
    textFormat: Text.PlainText; wrapMode: Text.WordWrap
    font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 12
    color: Config.Theme.danger
    Accessible.role: Accessible.StaticText; Accessible.name: message
}
