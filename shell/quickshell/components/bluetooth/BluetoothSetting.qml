pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../../config" as Config
Item {
    id:root
    property string title:""
    property string detail:""
    property string actionText:""
    property string actionName:""
    property bool actionEnabled:true
    signal activated()
    implicitHeight:Math.max(labels.implicitHeight,action.implicitHeight)+16
    Column {
        id:labels;width:Math.max(1,parent.width-action.width-12);spacing:4
        anchors.verticalCenter:parent.verticalCenter
        BluetoothLabel {text:root.title;color:Config.DirectoryStyle.ink}
        BluetoothLabel {text:root.detail;font.pixelSize:12}
    }
    ControlWorkspaceButton {id:action;objectName:root.actionName;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:Math.max(108,Math.ceil(minimumContentWidth));text:root.actionText;enabled:root.actionEnabled;headerControl:true;accessibleLabel:"Change "+root.title+". "+root.actionText;onClicked:root.activated()}
    Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:Config.DirectoryStyle.rule}
}
