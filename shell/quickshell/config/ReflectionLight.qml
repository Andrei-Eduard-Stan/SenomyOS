pragma Singleton
import QtQuick

// One slow decorative light. It does not need a refresh-rate animation loop.
QtObject {
    id:light
    property real phase:0
    property int activeClients:0
    property bool onBattery:true
    readonly property int tickMs:onBattery ? 250 : 125
    readonly property bool running:activeClients>0 && !Motion.reduced
    function acquire(){activeClients++;}
    function release(){activeClients=Math.max(0,activeClients-1);}
    property Timer motion:Timer {
        interval:light.tickMs;repeat:true;running:light.running
        onTriggered:light.phase=(Date.now()%64000)*6.2831853/64000
    }
}
