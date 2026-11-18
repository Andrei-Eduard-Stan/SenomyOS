import QtQuick
import Quickshell
import "../config" as Config

// Original Island corner paths stay square; only unornamented rules expand.
Item {
    id: root
    property real cornerExtent: 24
    property real edgeInset: 1
    property color ruleColor: Qt.rgba(Config.DirectoryStyle.ink.r, Config.DirectoryStyle.ink.g, Config.DirectoryStyle.ink.b, 0.38)
    readonly property real extent: Math.min(cornerExtent, width / 3, height / 3)
    readonly property url artRoot: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/SVG/"
    Rectangle {
        x: root.extent
        y: root.edgeInset
        width: Math.max(0, parent.width - 2 * root.extent)
        height: 1
        color: root.ruleColor
    }
    Rectangle {
        x: root.extent
        y: parent.height - root.edgeInset - 1
        width: Math.max(0, parent.width - 2 * root.extent)
        height: 1
        color: root.ruleColor
    }
    Rectangle {
        x: root.edgeInset
        y: root.extent
        width: 1
        height: Math.max(0, parent.height - 2 * root.extent)
        color: root.ruleColor
    }
    Rectangle {
        x: parent.width - root.edgeInset - 1
        y: root.extent
        width: 1
        height: Math.max(0, parent.height - 2 * root.extent)
        color: root.ruleColor
    }
    Repeater {
        model: [
            {
                file: "Asset 51.svg",
                right: false,
                bottom: false
            },
            {
                file: "Asset 50.svg",
                right: true,
                bottom: false
            },
            {
                file: "Asset 52.svg",
                right: true,
                bottom: true
            },
            {
                file: "Asset 54.svg",
                right: false,
                bottom: true
            }
        ]
        Image {
            required property var modelData
            width: root.extent
            height: root.extent
            x: modelData.right ? root.width - width : 0
            y: modelData.bottom ? root.height - height : 0
            source: root.artRoot + modelData.file
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(width * 2, height * 2)
        }
    }
}
