import QtQuick
import "../config" as Config
// Content rows use a quiet rule rather than a second miniature window frame.
Item {
    property bool active: false
    Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:Config.DirectoryStyle.rule}
    Rectangle {visible:parent.active;x:0;y:8;width:2;height:Math.max(0,parent.height-16);color:Config.DirectoryStyle.ink}
}
