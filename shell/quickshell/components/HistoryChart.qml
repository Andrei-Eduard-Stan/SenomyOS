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
    radius: 16
    color: Config.Theme.surfaceRaised
    border.width: 1
    border.color: Config.Theme.surfaceHover

    onValuesChanged: chart.requestPaint()
    onMinimumChanged: chart.requestPaint()
    onMaximumChanged: chart.requestPaint()

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
            if (!root.values || root.values.length < 2 || root.maximum <= root.minimum)
                return;
            context.strokeStyle = root.lineColor;
            context.lineWidth = 2;
            context.beginPath();
            for (let index = 0; index < root.values.length; index++) {
                const value = Math.max(root.minimum, Math.min(root.maximum, Number(root.values[index]) || 0));
                const x = width * index / Math.max(1, root.values.length - 1);
                const y = height - height * (value - root.minimum) / (root.maximum - root.minimum);
                if (index === 0)
                    context.moveTo(x, y);
                else
                    context.lineTo(x, y);
            }
            context.stroke();
        }
    }
}
