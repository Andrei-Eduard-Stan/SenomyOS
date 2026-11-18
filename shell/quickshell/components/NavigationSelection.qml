import QtQuick
import "../config" as Config

// Current destination is persistent location; hover and keyboard focus are transient.
Item {
    id:root
    property bool current:false
    property Item focusTarget:null
    property var pointerTarget:null
    property bool hovered:false
    Rectangle {
        objectName:"navigation-location-marker"
        x:1;y:8;width:1;height:Math.max(0,parent.height-16)
        visible:root.current;color:Config.DirectoryStyle.ink
    }
    ButtonHoverFrame {
        focused:!!root.focusTarget && root.focusTarget.visualFocus
        focusTarget:root.focusTarget;pointerTarget:root.pointerTarget
        selected:false;anchors.fill:parent;engaged:root.enabled && root.hovered
    }
}
