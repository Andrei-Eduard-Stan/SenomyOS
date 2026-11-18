import QtQuick
import Quickshell
import QtQuick.Effects

Item {
    id: root

    property bool animate: true
    readonly property url art: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/lockinthosefirst/SVG/"

    Item {
        x: parent.width * 0.19; y: parent.width * 0.08
        width: parent.width * 0.62; height: width
        SurfaceBackground {
            anchors.fill: parent
            fillKey: "senomy-ring"
            layer.enabled: imageReady
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: ringMask
            }
        }
        Item {
            id: ringMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle { anchors.fill: parent; radius: width / 2; color: "white" }
        }
    }

    // Outer arcs are centred at (208.7,184.35), not the cropped image centre.
    Image {
        x: 0
        y: 0
        width: parent.width
        height: parent.width * 403.47 / 417.4
        source: root.art + "senomy outer ring_1.svg"
        fillMode: Image.Stretch
        sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
        mipmap: true
    }

    Image {
        id: innerRing

        x: parent.width * 0.136
        y: parent.width * 0.03
        width: parent.width * 0.728
        height: width * 380.36 / 304.07
        source: root.art + "senomy inner circle.svg"
        sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
        mipmap: true

        transform: Rotation {
            id: ringRotation

            origin.x: innerRing.width / 2
            origin.y: innerRing.height * 160.3 / 380.36

            NumberAnimation on angle {
                from: 0
                to: 360
                duration: 45000
                loops: Animation.Infinite
                running: root.animate && root.visible
            }

        }

    }

    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.width * 0.105
        width: parent.width * 0.507
        height: width * 233.77 / 211.84
        source: root.art + "senomy avatar pfp.svg"
        sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
        mipmap: true
    }

}
