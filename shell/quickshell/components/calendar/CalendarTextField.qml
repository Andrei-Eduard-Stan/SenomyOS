import QtQuick
import ".."
import "../../config" as Config
ShellTextField {
    id:root
    property string validationMessage:""
    Rectangle {anchors.fill:parent;color:"transparent";border.width:root.validationMessage.length?1:0;border.color:Config.Theme.danger}
    Accessible.description:validationMessage
}
