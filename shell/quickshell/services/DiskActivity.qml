import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool active: false
    property var devices: []
    property var previous: ({
    })
    property real previousAt: 0
    property real busyPercent: 0
    property bool available: false
    property string busiestDevice: ""
    property Process discovery
    property FileView diskFile
    property Timer timer

    signal sampled()

    function consume(text, now) {
        let next = {
        }, values = [];
        for (let line of text.trim().split("\n")) {
            let f = line.trim().split(/\s+/);
            if (f.length < 14 || devices.indexOf(f[2]) < 0)
                continue;

            let busy = Number(f[12]);
            if (!Number.isFinite(busy))
                continue;

            next[f[2]] = busy;
            if (previousAt > 0 && now > previousAt && previous[f[2]] !== undefined && busy >= previous[f[2]])
                values.push({
                "name": f[2],
                "value": Math.max(0, Math.min(100, 100 * (busy - previous[f[2]]) / (now - previousAt)))
            });

        }
        available = values.length > 0;
        if (available) {
            values.sort((a, b) => {
                return b.value - a.value;
            });
            busyPercent = values[0].value;
            busiestDevice = values[0].name;
        }
        previous = next;
        previousAt = now;
        sampled();
    }

    onActiveChanged: {
        previous = {
        };
        previousAt = 0;
        available = false;
        devices = [];
        if (active)
            discovery.running = true;

    }

    discovery: Process {
        command: ["python3", Quickshell.shellDir + "/scripts/disk-devices.py"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active)
                    return ;

                try {
                    root.devices = JSON.parse(text);
                } catch (e) {
                    root.devices = [];
                }
                diskFile.reload();
            }
        }

    }

    diskFile: FileView {
        path: "/proc/diskstats"
        onLoaded: {
            if (root.active)
                root.consume(text(), Date.now());

        }
        onLoadFailed: {
            root.available = false;
            root.previous = {
            };
            root.previousAt = 0;
            if (root.active)
                root.sampled();

        }
    }

    timer: Timer {
        interval: 2000
        repeat: true
        running: root.active
        onTriggered: diskFile.reload()
    }

}
