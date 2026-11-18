import QtQuick
import "../config" as Config

// Endpoint marks belong to a section boundary, as in the reference instrument.
Item {
    id:root
    implicitHeight:1
    property bool leadingPoint:true
    property bool trailingPoint:true
    Rectangle {x:root.leadingPoint?3:0;y:0;width:Math.max(0,root.width-x-(root.trailingPoint?3:0));height:1;color:Config.DirectoryStyle.rule}
    Rectangle {visible:root.leadingPoint;x:0;y:-1;width:3;height:3;radius:1.5;color:Config.DirectoryStyle.muted}
    Rectangle {visible:root.trailingPoint;x:root.width-3;y:-1;width:3;height:3;radius:1.5;color:Config.DirectoryStyle.muted}
}
