import "../config" as Config
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Controls
import Quickshell

Item {
    id: root

    required property var metrics
    property var media: null
    property bool active: false
    property bool reducedMotion: !!Config.Skin.registry.persona && Config.Skin.registry.persona.reducedMotion === true
    readonly property bool narrow: width < 700
    readonly property real gutter: width < 440 ? 20 : 34
    readonly property real columnWidth: narrow ? (width - 2 * gutter - 20) / 2 : (width - 2 * gutter) * 0.32
    readonly property real detailY: narrow ? 242 : 112
    readonly property real lowerY: narrow ? 418 : height - 140

    signal openPerformance()
    signal openInsights()

    implicitHeight: narrow ? (width < 440 ? 760 : 700) : 420

    ExpandedFrame {
        id: expandedFrame
        objectName: "reflectionFrame"
        anchors.fill: parent
        z: -1
        animate: root.active && !root.reducedMotion
        fillOpacity: personaBackground.imageReady ? (personaBackground.spec.scrimOpacity || 0) : 0.65
    }

    PersonaBackground {
        id: personaBackground
        anchors.fill: parent
        anchors.margins: 10
        z: -2
        variant: "expanded"
        drawBacking: false
        drawScrim: false
        visible: !!spec.source
        // Aspect-cropping can cut away the image's own transparent corners.
        // Apply the frame silhouette after cropping so both edges stay aligned.
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: backgroundMask
        }
    }
    Item {
        id: backgroundMask
        anchors.fill: personaBackground
        visible: false
        layer.enabled: true
        // The corner artwork is 28px with a half-width diagonal. Keep that
        // cut fixed as the panel changes aspect ratio, rather than stretching it.
        readonly property real cut: Math.min(14, width / 2, height / 2)
        Shape {
            anchors.fill: parent
            antialiasing: true
            ShapePath {
                fillColor: "white"
                strokeColor: "transparent"
                startX: backgroundMask.cut
                startY: 0
                PathLine { x: backgroundMask.width-backgroundMask.cut; y: 0 }
                PathLine { x: backgroundMask.width; y: backgroundMask.cut }
                PathLine { x: backgroundMask.width; y: backgroundMask.height-backgroundMask.cut }
                PathLine { x: backgroundMask.width-backgroundMask.cut; y: backgroundMask.height }
                PathLine { x: backgroundMask.cut; y: backgroundMask.height }
                PathLine { x: 0; y: backgroundMask.height-backgroundMask.cut }
                PathLine { x: 0; y: backgroundMask.cut }
                PathLine { x: backgroundMask.cut; y: 0 }
            }
        }
    }
    // Authored inner trim stays separate from flexible content.

    Rectangle {
        x: root.gutter
        y: 27
        width: parent.width - 2 * x
        height: 1
        color: "#737379"
    }

    Rectangle {
        x: root.gutter
        y: parent.height - 28
        width: root.columnWidth
        height: 1
        color: "#737379"
        visible: !root.narrow
    }

    Rectangle {
        x: parent.width - root.gutter - root.columnWidth
        y: parent.height - 28
        width: root.columnWidth
        height: 1
        color: "#737379"
        visible: !root.narrow
    }

    Image {
        x: root.gutter
        y: 34
        width: 44
        height: 36
        source: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/lockinthosefirst/SVG/sos logo.svg"
        fillMode: Image.PreserveAspectFit
    }

    Image {
        x: root.gutter - 12 + 0.5 - width / 2
        y: root.detailY + 20
        width: 12
        height: 12
        source: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/SVG/Asset 31.svg"
        visible: !root.narrow
    }

    Repeater {
        model: root.narrow ? [] : [false, true]

        Rectangle {
            required property bool modelData

            x: modelData ? root.width - root.gutter + 12 : root.gutter - 12
            y: 62
            width: 1
            height: 72
            color: "#77777d"
        }

    }

    ExpandedLabel {
        x: parent.width - root.gutter - width
        y: 44
        text: "Temp: " + (root.metrics.temperatureAvailable ? Math.round(root.metrics.temperatureCelsius) + "°C" : "—")
        font.pixelSize: root.narrow ? 12 : 16
    }

    ExpandedAvatar {
        id: avatar

        x: (parent.width - width) / 2
        y: root.narrow ? 32 : 40
        width: root.narrow ? 190 : Math.min(235, parent.width * 0.265)
        height: width
        animate: root.active && !root.reducedMotion
    }

    Repeater {
        model: [{
            "title": "// System",
            "right": false
        }, {
            "title": "// Resources",
            "right": true
        }]

        Item {
            required property var modelData

            x: modelData.right ? root.width - root.gutter - root.columnWidth : root.gutter
            y: root.detailY - 30
            width: root.columnWidth
            height: 20

            ExpandedLabel {
                id: heading

                text: modelData.title
                font.family: "Audiowide"
                font.pixelSize: root.narrow ? 12 : 14
            }

            Image {
                x: heading.width + 5
                y: 6
                width: Math.max(0, parent.width - x)
                height: 9
                source: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/SVG/" + (modelData.right ? "Asset 22.svg" : "Asset 26.svg")
                fillMode: Image.Stretch
            }

        }

    }

    Repeater {
        model: [{
            "label": "Kernel:",
            "value": root.metrics.kernelRelease,
            "detail": "",
            "right": false,
            "row": 0
        }, {
            "label": "Host:",
            "value": root.metrics.hostName,
            "detail": root.metrics.hostModel,
            "right": false,
            "row": 1
        }, {
            "label": "CPU:",
            "value": root.metrics.ready ? Math.round(root.metrics.cpuPercent) + "%" : "—",
            "detail": root.metrics.cpuModel,
            "right": true,
            "row": 0
        }, {
            "label": "RAM:",
            "value": root.metrics.memoryTotalKib > 0 ? Math.round(root.metrics.memoryPercent) + "%" : "—",
            "detail": root.metrics.memoryTotalKib > 0 ? Math.round(root.metrics.memoryUsedKib / 1024) + " MiB / " + Math.round(root.metrics.memoryTotalKib / 1024) + " MiB" : "Unavailable",
            "right": true,
            "row": 1
        }]

        Column {
            required property var modelData

            x: modelData.right ? root.width - root.gutter - root.columnWidth : root.gutter + 10
            y: root.detailY + modelData.row * 78
            width: root.columnWidth - (modelData.right ? 0 : 10)
            spacing: 4

            ExpandedLabel {
                width: parent.width
                text: parent.modelData.label
                font.pixelSize: 10
                color: "#c5c4cd"
            }

            ExpandedLabel {
                width: parent.width
                text: parent.modelData.value || "—"
                font.pixelSize: root.narrow ? 16 : 20
            }

            ExpandedLabel {
                width: parent.width
                text: parent.modelData.detail || ""
                font.pixelSize: 10
                wrapMode: Text.Wrap
                maximumLineCount: 2
                color: "#c5c4cd"
            }

        }

    }

    Column {
        x: root.narrow ? root.gutter : (root.width - width) / 2
        y: root.narrow ? root.lowerY - 35 : root.height - 135
        width: root.narrow ? root.width - 2 * root.gutter : root.width * 0.3
        spacing: 3

        ExpandedLabel {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Uptime"
            font.pixelSize: 12
        }

        ExpandedLabel {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.metrics.uptimeDetailedLabel || "—"
            font.pixelSize: 14
        }

    }

    Item {
        id: mediaSection
        objectName: "expandedMediaSection"
        readonly property bool hasSession: !!root.media && root.media.available
        x: root.gutter
        y: root.narrow ? root.lowerY + 24 : root.lowerY
        width: root.narrow ? parent.width - 2 * root.gutter : root.columnWidth
        height: 112

        Image {
            objectName: "mediaSeparator"
            y: -12
            width: parent.width
            height: 9
            source: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/SVG/Asset 22.svg"
            fillMode: Image.Stretch
        }

        SurfaceBackground {
            objectName: "mediaEmptyBackground"
            anchors.fill: parent
            fillKey: "senomy-media-empty"
            visible: !mediaSection.hasSession
        }

        ExpandedMedia {
            objectName: "expandedMediaController"
            visible: mediaSection.hasSession
            anchors.fill: parent
            media: root.media
            active: root.active
        }

    }

    Item {
        x: root.narrow ? root.gutter : parent.width - root.gutter - root.columnWidth
        y: root.narrow ? root.lowerY + 151 : root.lowerY
        width: root.narrow ? parent.width - 2 * root.gutter : root.columnWidth
        height: root.narrow ? 75 : 105

        Image {
            y: -12
            width: parent.width
            height: 9
            source: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/SVG/line.svg"
            fillMode: Image.Stretch
        }

        ExpandedHistory {
            anchors.fill: parent
            metrics: root.metrics
            collecting: root.active
        }

    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.narrow ? root.height - 90 : root.height - 87
        spacing: 6

        ExpandedButton {
            width: root.narrow ? 125 : root.width * 0.135
            objectName: "performanceButton"
            text: "Performance"
            onClicked: root.openPerformance()
        }

        ExpandedButton {
            width: root.narrow ? 110 : root.width * 0.12
            objectName: "insightsButton"
            text: "Insights"
            onClicked: root.openInsights()
        }

    }

}
