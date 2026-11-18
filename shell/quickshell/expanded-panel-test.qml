import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services" as Services

Window {
    id: test

    property string out: Quickshell.env("SENOMY_QA_OUT") || "/tmp"
    property int phase: 0
    property int actions: 0
    property real hiddenAt: 0
    property real retainedAt: 0
    property var metrics: ({
        "ready": true,
        "history": historyTest,
        "cpuPercent": 5,
        "memoryPercent": 19,
        "memoryTotalKib": 3.27e+07,
        "memoryUsedKib": 6.2e+06,
        "kernelRelease": "7.2.6-arch2-1",
        "hostName": "Senomy",
        "hostModel": "ThinkPad T480",
        "cpuModel": "Intel(R) Core i5-8250U 2.70 GHz",
        "temperatureAvailable": true,
        "temperatureCelsius": 39,
        "uptimeDetailedLabel": "03:05:12"
    })

    visible: true
    width: 940
    height: 480
    color: "#35353b"

    Services.TelemetryHistory { id: historyTest; metrics: test.metrics }

    Services.DiskActivity {
        id: diskTest
    }

    QtObject {
        id: player

        property bool canSeek: true
        property bool positionSupported: true
        property bool lengthSupported: true
        property real length: 277
        property real position: 84
        property bool canGoPrevious: true
        property bool canGoNext: true
        property bool canTogglePlaying: true

        function togglePlaying() {
            media.playing = !media.playing;
            test.actions++;
        }

        function previous() {
            test.actions++;
        }

        function next() {
            test.actions++;
        }

        function seek(offset) {
            position = Math.max(0, Math.min(length, position + offset));
        }

    }

    QtObject {
        id: media

        property var selectedPlayer: player
        readonly property bool available: selectedPlayer !== null
        property string title: "Echoes in Vacuum"
        property string artist: "Senomy"
        property string identity: "Music"
        property string artwork: "file://" + Quickshell.shellDir + "/../../assets/senomy_island_expanded/2x/Senomy@2x.png"
        property bool playing: true

        function toggle() {
            playing = !playing;
            test.actions++;
        }

        function previous() {
            test.actions++;
        }

        function next() {
            test.actions++;
        }

    }

    TestCase {
        id: input

        when: false
    }

    ExpandedSenomyPanel {
        id: panel

        x: 20
        y: 20
        width: 900
        height: implicitHeight
        metrics: test.metrics
        media: media
        active: true
        onOpenPerformance: test.actions++
        onOpenInsights: test.actions++
    }

    Timer {
        interval: 1800
        running: true
        repeat: true
        onTriggered: {
            if (test.phase === 0) {
                diskTest.devices = ["fixture"];
                diskTest.consume("8 0 fixture 0 0 0 0 0 0 0 0 0 100 0", 1000);
                if (diskTest.available) {
                    console.error("FAIL disk baseline");
                    Qt.exit(1);
                    return ;
                }
                diskTest.consume("8 0 fixture 0 0 0 0 0 0 0 0 0 150 0\n8 1 fixture1 0 0 0 0 0 0 0 0 0 999 0", 2000);
                if (!diskTest.available || diskTest.busyPercent !== 5) {
                    console.error("FAIL disk counters");
                    Qt.exit(1);
                    return ;
                }
                diskTest.consume("8 0 fixture 0 0 0 0 0 0 0 0 0 1 0", 3000);
                if (diskTest.available) {
                    console.error("FAIL disk reset");
                    Qt.exit(1);
                    return ;
                }
                console.log("PASS: disk baseline, activity, partition exclusion and reset");
            }
            if (test.phase === 0)
                panel.grabToImage((r) => {
                return r.saveToFile(test.out + "/expanded-wide.png");
            });

            if (test.phase === 1) {
                test.hiddenAt = Date.now();
                test.retainedAt = historyTest.samples[0].at;
                panel.active = false;
                panel.width = 390;
                test.width = 430;
                test.height = 810;
                media.title = "A very long ASMR video title to verify graceful truncation without layout overflow";
            }
            if (test.phase === 2)
                panel.grabToImage((r) => {
                return r.saveToFile(test.out + "/expanded-narrow.png");
            });

            if (test.phase === 3) {
                try {
                    if (historyTest.samples[historyTest.samples.length - 1].at <= test.hiddenAt)
                        throw new Error("history did not advance while panel closed");
                    if (historyTest.samples[0].at !== test.retainedAt)
                        throw new Error("closing reset history");
                    panel.active = true;
                    if (historyTest.samples[0].at !== test.retainedAt)
                        throw new Error("reopening reset history");
                    const saved = historyTest.samples;
                    historyTest.samples = [{at: Date.now() - 62000, cpu: 0, ram: 0, disk: null}];
                    historyTest.sample(Date.now());
                    if (historyTest.samples.length !== 1 || Date.now() - historyTest.samples[0].at > 60000)
                        throw new Error("history retention is not bounded to 60 seconds");
                    historyTest.samples = saved;
                    console.log("PASS: closed-panel sampling, reopen retention and 60-second eviction");
                    let play = input.findChild(panel, "playButton");
                    input.mouseClick(play, play.width / 2, play.height / 2);
                    if (media.playing || test.actions !== 1)
                        throw new Error("play toggle");

                    const section = input.findChild(panel, "expandedMediaSection");
                    if (!input.findChild(panel, "expandedMediaController").visible)
                        throw new Error("paused media controller hidden");
                    if (!input.findChild(panel, "mediaSeparator").visible)
                        throw new Error("paused media separator hidden");
                    media.playing = true;
                    input.wait(30);
                    if (!section.visible) throw new Error("playing media section hidden");
                    let seek = input.findChild(panel, "mediaSeek");
                    input.mouseClick(seek, seek.width * 0.7, seek.height / 2);
                    if (player.position < 150)
                        throw new Error("seek click");

                    player.canSeek = false;
                    if (seek.enabled)
                        throw new Error("seek capability gate");

                    for (let name of ["performanceButton", "insightsButton"]) {
                        let button = input.findChild(panel, name);
                        input.mouseClick(button, button.width / 2, button.height / 2);
                    }
                    if (test.actions !== 3)
                        throw new Error("navigation routes");

                    panel.reducedMotion = true;
                    let frame = input.findChild(panel, "reflectionFrame");
                    if (frame.animate)
                        throw new Error("reduced motion must stop reflections");

                    let phaseBefore = frame.phase;
                    input.wait(200);
                    if (frame.phase !== phaseBefore)
                        throw new Error("reflection kept animating");

                    console.log("PASS: playback, seek, disabled seek, two navigation routes, reduced motion");
                } catch (e) {
                    console.error("FAIL: " + e);
                    Qt.exit(1);
                    return ;
                }
                media.selectedPlayer = null;
                panel.width = 900;
                test.width = 940;
                test.height = 480;
            }
            if (test.phase === 4) {
                if (input.findChild(panel, "expandedMediaController").visible
                    || !input.findChild(panel, "mediaSeparator").visible
                    || !input.findChild(panel, "mediaEmptyBackground").visible) {
                    console.error("FAIL: empty media slot or separator state");
                    Qt.exit(1);
                    return;
                }
                panel.grabToImage((r) => {
                return r.saveToFile(test.out + "/expanded-empty.png");
            });

            }
            if (test.phase === 5) {
                console.log("PASS: expanded renders wide, narrow, long media and empty states");
                Qt.quit();
            }
            test.phase++;
        }
    }

}
