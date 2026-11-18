import QtQuick
import Quickshell

Item {
    id: root

    property bool animate: true
    property real phase: 0
    property real fillOpacity: 0.65
    readonly property url art: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/SVG/"

    Repeater {
        model: [{
            "file": "Asset 39.svg",
            "r": false,
            "b": false
        }, {
            "file": "Asset 41.svg",
            "r": true,
            "b": false
        }, {
            "file": "Asset 38.svg",
            "r": false,
            "b": true
        }, {
            "file": "Asset 40.svg",
            "r": true,
            "b": true
        }]

        Image {
            required property var modelData

            width: 64
            height: 60
            x: modelData.r ? root.width - width : 0
            y: modelData.b ? root.height - height : 0
            source: root.art + modelData.file
            opacity: 0.725
        }

    }

    Item {
        id: rim

        anchors.fill: parent
        anchors.margins: 10

        Image {
            anchors.fill: parent
            source: "../assets/expanded-fill.svg"
            opacity: root.fillOpacity
            cache: false
        }

        Image {
            id: edge

            anchors.fill: parent
            source: "../assets/expanded-metal.svg"
            opacity: 0.72
            sourceSize: Qt.size(root.width * 2, root.height * 2)
        }

        Repeater {
            model: [{
                "file": "Asset 51.svg",
                "right": false,
                "bottom": false
            }, {
                "file": "Asset 50.svg",
                "right": true,
                "bottom": false
            }, {
                "file": "Asset 52.svg",
                "right": true,
                "bottom": true
            }, {
                "file": "Asset 54.svg",
                "right": false,
                "bottom": true
            }]

            Image {
                required property var modelData

                width: 28
                height: 28
                x: modelData.right ? rim.width - width : 0
                y: modelData.bottom ? rim.height - height : 0
                source: root.art + modelData.file
                fillMode: Image.Stretch
            }

        }

        MetalSheen { anchors.fill: parent; animate: root.animate }
    }

    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 49
        width: 48
        height: 48
        source: root.art + "Asset 37.svg"
        opacity: 0.95
    }

}
