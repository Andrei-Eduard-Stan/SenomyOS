import QtQuick
import "../../config" as Config

// Qt Popup owns native focus, anchoring, interruption and close completion.
Transition {
    id: root
    property bool opening: true
    NumberAnimation {
        property: "opacity"
        from: root.opening ? 0 : 1
        to: root.opening ? 1 : 0
        duration: root.opening ? Config.Motion.menuMs : 0
        easing.type: Config.Motion.easing(root.opening)
    }
}
