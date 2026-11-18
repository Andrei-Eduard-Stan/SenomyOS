import QtQuick
import QtQuick.Controls

Item {
    id: root

    required property var metrics
    property bool collecting: false
    readonly property var history: metrics.history || null
    readonly property var samples: history ? history.samples.filter(p => history.lastSampleAt-p.at<=60000) : []
    readonly property var disk: history ? history.disk : null
    onSamplesChanged: if (collecting) plot.requestPaint()
    onCollectingChanged: if (collecting) plot.requestPaint()

    Canvas {
        id: plot

        anchors.fill: parent
        anchors.topMargin: 20
        anchors.bottomMargin: 20
        anchors.rightMargin: 16
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.lineWidth = 1;
            c.strokeStyle = "#303037";
            for (let i = 0; i <= 4; i++) {
                let y = 2 + (height - 4) * i / 4;
                c.beginPath();
                c.moveTo(0, y);
                c.lineTo(width, y);
                c.stroke();
            }
            if (root.samples.length < 2)
                return ;

            const now = root.samples[root.samples.length - 1].at;
            for (let series of ["ram", "cpu", "disk"]) {
                c.beginPath();
                let segment = false, firstX = 0;
                root.samples.forEach((p) => {
                    if (p[series] === null || p[series] === undefined) {
                        segment = false;
                        return ;
                    }
                    const x = width * (1 - (now - p.at) / 60000);
                    const y = height - 2 - Math.max(0, Math.min(100, p[series])) * (height - 4) / 100;
                    if (!segment) {
                        c.moveTo(x, y);
                        firstX = x;
                    } else {
                        c.lineTo(x, y);
                    }
                    segment = true;
                });
                if (series === "ram") {
                    c.lineTo(width, height);
                    c.lineTo(firstX, height);
                    c.closePath();
                    c.fillStyle = "#183b40";
                    c.fill();
                }
                c.strokeStyle = series === "cpu" ? "#f1eef8" : series === "disk" ? "#f3b866" : "#63d5df";
                c.setLineDash(series === "disk" ? [2, 3] : []);
                c.stroke();
                c.setLineDash([]);
            }
        }
    }

    Row {
        anchors.top: parent.top
        anchors.horizontalCenter: plot.horizontalCenter
        spacing: 14

        ExpandedLabel {
            text: "CPU"
            font.pixelSize: 9
        }

        ExpandedLabel {
            text: "MEM"
            font.pixelSize: 9
            color: "#63d5df"
        }

        ExpandedLabel {
            text: "DISK" + (disk && disk.available ? "" : " —")
            font.pixelSize: 9
            color: "#f3b866"

            HoverHandler {
                id: diskHover
            }

        }

    }

    ExpandedLabel {
        visible: root.samples.length < 2
        anchors.centerIn: plot
        text: "Collecting history…"
        font.pixelSize: 10
    }

    ExpandedLabel {
        anchors.bottom: parent.bottom
        text: "60s"
        font.pixelSize: 9
        color: "#92929c"
    }

    ExpandedLabel {
        anchors.bottom: parent.bottom
        x: plot.x + plot.width - width
        text: "0s · %"
        font.pixelSize: 9
        color: "#92929c"
    }

}
