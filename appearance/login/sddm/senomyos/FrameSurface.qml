import QtQuick 2.15

Item {
    id: frame

    property real opticalScale: 1
    property string motif: ""
    property string motifAnchor: "top"
    property color surfaceColor: "#0a0c0f"
    property color accentColor: "#9892e8"
    property color dangerColor: "#e98787"
    property bool focused: false
    property bool attention: false
    property bool critical: false

    readonly property real cornerWidth: 16 * opticalScale
    readonly property real cornerHeight: 16 * opticalScale
    readonly property real horizontalEdgeHeight: 6 * opticalScale
    readonly property real verticalEdgeWidth: 6 * opticalScale
    readonly property real frameOpacity: attention || critical ? 1 : (focused ? 0.98 : 0.86)

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4 * frame.opticalScale
        radius: 16 * frame.opticalScale
        color: frame.surfaceColor
        opacity: 0.94
    }

    Rectangle {
        visible: frame.focused || frame.attention || frame.critical
        anchors.fill: parent
        anchors.margins: 5 * frame.opticalScale
        radius: 12 * frame.opticalScale
        color: "transparent"
        border.width: Math.max(1, frame.opticalScale)
        border.color: frame.critical ? frame.dangerColor : frame.accentColor
        opacity: frame.attention || frame.critical ? 0.62 : 0.3
    }

    Image {
        anchors.left: parent.left
        anchors.top: parent.top
        width: frame.cornerWidth
        height: frame.cornerHeight
        source: "assets/frames/compact/corner-tl.svg"
        fillMode: Image.PreserveAspectFit
        opacity: frame.frameOpacity
    }

    Image {
        anchors.right: parent.right
        anchors.top: parent.top
        width: frame.cornerWidth
        height: frame.cornerHeight
        source: "assets/frames/compact/corner-tr.svg"
        fillMode: Image.PreserveAspectFit
        opacity: frame.frameOpacity
    }

    Image {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: frame.cornerWidth
        height: frame.cornerHeight
        source: "assets/frames/compact/corner-bl.svg"
        fillMode: Image.PreserveAspectFit
        opacity: frame.frameOpacity
    }

    Image {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: frame.cornerWidth
        height: frame.cornerHeight
        source: "assets/frames/compact/corner-br.svg"
        fillMode: Image.PreserveAspectFit
        opacity: frame.frameOpacity
    }

    Image {
        anchors.left: parent.left
        anchors.leftMargin: frame.cornerWidth
        anchors.right: parent.right
        anchors.rightMargin: frame.cornerWidth
        anchors.top: parent.top
        height: frame.horizontalEdgeHeight
        source: "assets/frames/compact/edge-top.svg"
        fillMode: Image.Stretch
        opacity: frame.frameOpacity
    }

    Image {
        anchors.left: parent.left
        anchors.leftMargin: frame.cornerWidth
        anchors.right: parent.right
        anchors.rightMargin: frame.cornerWidth
        anchors.bottom: parent.bottom
        height: frame.horizontalEdgeHeight
        source: "assets/frames/compact/edge-bottom.svg"
        fillMode: Image.Stretch
        opacity: frame.frameOpacity
    }

    Image {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: frame.cornerHeight
        anchors.bottom: parent.bottom
        anchors.bottomMargin: frame.cornerHeight
        width: frame.verticalEdgeWidth
        source: "assets/frames/compact/edge-left.svg"
        fillMode: Image.Stretch
        opacity: frame.frameOpacity
    }

    Image {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: frame.cornerHeight
        anchors.bottom: parent.bottom
        anchors.bottomMargin: frame.cornerHeight
        width: frame.verticalEdgeWidth
        source: "assets/frames/compact/edge-right.svg"
        fillMode: Image.Stretch
        opacity: frame.frameOpacity
    }

    Image {
        visible: frame.motif !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: frame.motifAnchor === "top" ? parent.top : undefined
        anchors.bottom: frame.motifAnchor === "bottom" ? parent.bottom : undefined
        anchors.topMargin: frame.motifAnchor === "top" ? 1 * frame.opticalScale : 0
        anchors.bottomMargin: frame.motifAnchor === "bottom" ? 1 * frame.opticalScale : 0
        width: (frame.motif === "identity" ? 24 : (frame.motif === "diagnostic-tick" ? 28 : 10)) * frame.opticalScale
        height: (frame.motif === "identity" ? 10 : (frame.motif === "diagnostic-tick" ? 8 : 6)) * frame.opticalScale
        source: "assets/frames/motifs/" + frame.motif + ".svg"
        fillMode: Image.PreserveAspectFit
        opacity: frame.frameOpacity
    }
}
