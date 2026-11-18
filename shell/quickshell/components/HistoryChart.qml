import QtQuick
import "../config" as Config

Rectangle {
    id: root

    property var values: []
    property real minimum: 0
    property real maximum: 100
    property color lineColor: Config.Theme.accent
    property string label: ""
    property string currentLabel: ""

    implicitWidth: 320
    implicitHeight: 160
    radius: 5
    color: chartSkin.ready ? "transparent" : Config.Theme.glassRaised
    border.width: chartSkin.ready ? 0 : 1
    border.color: Qt.rgba(Config.Theme.muted.r, Config.Theme.muted.g, Config.Theme.muted.b, 0.24)

    onValuesChanged: chart.requestPaint()
    onMinimumChanged: chart.requestPaint()
    onMaximumChanged: chart.requestPaint()

    ArtFrame {
        id: chartSkin
        anchors.fill: parent
        spec: Config.Skin.frame("chart")
        requested: Config.Skin.mode(spec) === "art"
    }
    SurfaceBackground { anchors.fill: parent; anchors.margins: 5; fillKey: "chart" }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        text: root.label
        color: Config.Theme.dim
        font.family: Config.Theme.fontFamily
        font.pixelSize: 8
        font.weight: Font.DemiBold
    }
    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        text: root.currentLabel
        color: root.lineColor
        font.family: Config.Theme.fontFamily
        font.pixelSize: 10
        font.weight: Font.DemiBold
    }

    Canvas {
        id: chart
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 34
        anchors.bottomMargin: 12
        antialiasing: true
        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.strokeStyle = Qt.rgba(Config.Theme.dim.r, Config.Theme.dim.g, Config.Theme.dim.b, 0.22);
            context.lineWidth = 1;
            for (let line = 1; line < 4; line++) {
                const y = height * line / 4;
                context.beginPath();
                context.moveTo(0, y);
                context.lineTo(width, y);
                context.stroke();
            }
            for (let line = 1; line < 6; line++) {
                const x = width * line / 6;
                context.beginPath();
                context.moveTo(x, 0);
                context.lineTo(x, height);
                context.stroke();
            }
            if (!root.values || root.values.length < 2 || root.maximum <= root.minimum)
                return;

            const points = [];
            for (let index = 0; index < root.values.length; index++) {
                const value = Math.max(root.minimum, Math.min(root.maximum, Number(root.values[index]) || 0));
                points.push({
                    x: width * index / Math.max(1, root.values.length - 1),
                    y: height - height * (value - root.minimum) / (root.maximum - root.minimum)
                });
            }

            const fill = context.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.24));
            fill.addColorStop(1, Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.015));
            context.fillStyle = fill;
            context.beginPath();
            context.moveTo(points[0].x, height);
            for (let point of points)
                context.lineTo(point.x, point.y);
            context.lineTo(points[points.length - 1].x, height);
            context.closePath();
            context.fill();

            context.strokeStyle = root.lineColor;
            context.lineWidth = 2;
            context.beginPath();
            for (let index = 0; index < points.length; index++) {
                const x = points[index].x;
                const y = points[index].y;
                if (index === 0)
                    context.moveTo(x, y);
                else
                    context.lineTo(x, y);
            }
            context.stroke();

            const latest = points[points.length - 1];
            context.fillStyle = root.lineColor;
            context.beginPath();
            context.arc(latest.x, latest.y, 3, 0, Math.PI * 2);
            context.fill();
        }
    }
}
