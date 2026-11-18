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
    implicitHeight: 220
    radius: 5
    color: "#b30b0d11"
    border.width: 0
    border.color: Qt.rgba(Config.Theme.muted.r, Config.Theme.muted.g, Config.Theme.muted.b, 0.24)

    onValuesChanged: chart.requestPaint()
    onMinimumChanged: chart.requestPaint()
    onMaximumChanged: chart.requestPaint()

    SurfaceBackground { anchors.fill: parent; anchors.margins: 5; fillKey: "chart" }

    DashboardBorder { anchors.fill: parent }
    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        text: root.label
        color: "#beb8cb"
        font.family: Config.Theme.fontFamily
        font.pixelSize: 10
        font.weight: Font.DemiBold
    }
    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        text: root.currentLabel
        color: root.lineColor
        font.family: Config.Theme.fontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    Canvas {
        id: chart
        anchors.fill: parent
        anchors.leftMargin: 38
        anchors.rightMargin: 18
        anchors.topMargin: 42
        anchors.bottomMargin: 28
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
                    x: width * (1 - (root.values.length - 1 - index) / 59),
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
            context.lineWidth = 1.4;
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


        }
    }
    Repeater {
        model: 5
        Text {
            required property int index
            x: 8; y: 36 + index * (root.height - 70) / 4
            text: Math.round(root.maximum - index * (root.maximum - root.minimum) / 4)
            color: "#aaa5b9"; font.family: Config.Theme.fontFamily; font.pixelSize: 9
        }
    }
    Repeater {
        model: ["59s", "45s", "30s", "15s", "0s"]
        Text {
            required property string modelData
            required property int index
            width: 28
            x: 38 + index * (root.width - 56) / 4 - (index === 0 ? 0 : index === 4 ? width : width / 2)
            y: root.height - 20
            text: modelData; color: "#aaa5b9"; font.family: Config.Theme.fontFamily; font.pixelSize: 9
            horizontalAlignment: index === 4 ? Text.AlignRight : Text.AlignLeft
        }
    }
    Text { visible: root.values.length < 2; anchors.centerIn: parent; text: "COLLECTING LIVE SAMPLES"; color: "#aaa5b9"; font.family: Config.Theme.fontFamily; font.pixelSize: 10 }
}
