import QtQuick
import QtTest
import "../components"
TestCase {
    name: "ExpansionChevrons"
    when: windowShown
    width: 80; height: 80
    visible: true
    ExpansionChevrons { id: arrows; width: 24; height: 64 }
    function test_reveal_cancel_and_motion() {
        compare(arrows.opacity, 0);
        arrows.revealed = true;
        tryCompare(arrows, "opacity", 1);
        wait(160);
        verify(arrows.phase > 0);
        arrows.revealed = false;
        tryCompare(arrows, "opacity", 0);
        const stopped = arrows.phase;
        wait(160);
        compare(arrows.phase, stopped);
        arrows.reducedMotion = true;
        arrows.revealed = true;
        compare(arrows.opacity, 1);
        const still = arrows.phase;
        wait(160);
        compare(arrows.phase, still);
    }
}
