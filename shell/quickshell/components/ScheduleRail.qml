import QtQuick
import "../config" as Config

// Native depleting structure; the service owns both the ratio and the clock.
Item {
    id: root
    property real progress: 0
    property bool critical: false
    implicitHeight: 14
    Rectangle { x: 0; y: 6; width: parent.width; height: 1; color: Config.QuickPanelStyle.rule }
    Repeater {
        model: 13
        Rectangle {
            required property int index
            x: index * (root.width - 1) / 12
            y: index % 3 === 0 ? 3 : 5
            width: 1; height: index % 3 === 0 ? 7 : 3
            color: Config.QuickPanelStyle.secondary; opacity: 0.5
        }
    }
    Rectangle { y: 6; width: Math.max(0, Math.min(1,root.progress)) * parent.width; height: root.critical ? 2 : 1; color: Config.QuickPanelStyle.ink }
    Rectangle { x: Math.max(0, Math.min(root.width - 3, root.progress * root.width)); y: 3; width: 3; height: 7; color: Config.QuickPanelStyle.ink }
    Rectangle { anchors.right: parent.right; y: 1; width: 1; height: 11; color: Config.QuickPanelStyle.ink }
}
