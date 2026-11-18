import QtQuick
import "../config" as Config

Rectangle {
    id: root

    property real value: 0
    property real maximum: 100
    property string title: "CAPACITY"
    property string valueLabel: Math.round(value) + "%"
    property string detail: ""
    property color gaugeColor: Config.Theme.accent

    implicitWidth: 320
    implicitHeight: 320
    radius: 5
    color: "#b30b0d11"
    border.width: 0
    border.color: Qt.rgba(Config.Theme.muted.r, Config.Theme.muted.g, Config.Theme.muted.b, 0.24)

    onValueChanged: gauge.requestPaint()
    onMaximumChanged: gauge.requestPaint()
    onGaugeColorChanged: gauge.requestPaint()

    DashboardBorder { anchors.fill: parent }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 14
        text: root.title
        color: "#beb8cb"
        font.family: Config.Theme.fontFamily
        font.pixelSize: 8
        font.weight: Font.DemiBold
    }

    Canvas {
        id: gauge
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - 76
        height: width
        antialiasing: true

        onPaint: {
            const context = getContext("2d");
            context.reset();
            const center = width / 2;
            const radius = width / 2 - 12;
            const start = Math.PI * 0.72;
            const span = Math.PI * 1.56;
            const fraction = Math.max(0, Math.min(1, root.maximum > 0 ? root.value / root.maximum : 0));

            context.lineCap = "round";
            context.lineWidth = 13;
            context.strokeStyle = Qt.rgba(Config.Theme.dim.r, Config.Theme.dim.g, Config.Theme.dim.b, 0.22);
            context.beginPath();
            context.arc(center, center, radius, start, start + span);
            context.stroke();

            context.strokeStyle = Qt.rgba(root.gaugeColor.r, root.gaugeColor.g, root.gaugeColor.b, 0.22);
            context.lineWidth = 22;
            context.beginPath();
            context.arc(center, center, radius, start, start + span * fraction);
            context.stroke();

            context.strokeStyle = root.gaugeColor;
            context.lineWidth = 8;
            context.beginPath();
            context.arc(center, center, radius, start, start + span * fraction);
            context.stroke();

            context.strokeStyle = Qt.rgba(Config.Theme.muted.r, Config.Theme.muted.g, Config.Theme.muted.b, 0.45);
            context.lineWidth = 1;
            for (let index = 0; index <= 24; index++) {
                const angle = start + span * index / 24;
                const inner = radius - 20;
                const outer = radius - 14;
                context.beginPath();
                context.moveTo(center + Math.cos(angle) * inner, center + Math.sin(angle) * inner);
                context.lineTo(center + Math.cos(angle) * outer, center + Math.sin(angle) * outer);
                context.stroke();
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 80
        spacing: 6
        Text {
            width: parent.width
            text: root.valueLabel
            color: Config.Theme.foreground
            font.family: Config.Theme.fontFamily
            font.pixelSize: 34
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            width: parent.width
            text: root.detail
            color: Config.Theme.muted
            font.family: Config.Theme.fontFamily
            font.pixelSize: 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
