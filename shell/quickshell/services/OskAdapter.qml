import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    // Injectable process objects permit adapter tests without a native keyboard.
    property var child: managedChild
    property var observer: readinessProbe
    property int ownerSerial: 0
    property int observationSerial: 0
    property var observationPid: null
    property string providerName: ""
    property bool signalReady: false
    property bool observing: false
    property bool stopRequested: false
    property bool visibilityKnown: false
    property bool visible: false
    signal geometryChanged()
    signal providerStarted(int serial)
    signal providerFailed(int serial)
    signal providerExited(int serial, bool successful)

    function owns(serial) { return serial === ownerSerial && ownerSerial > 0 && child.running; }
    function start(name, serial) {
        if (child.running || ["wvkbd-mobintl","wvkbd-deskintl"].indexOf(name) < 0 || serial < 1) return false;
        visibilityKnown=false;visible=false;
        ownerSerial = serial; providerName = name; signalReady = false; stopRequested = false;
        child.command = ["python3",Quickshell.shellDir+"/scripts/osk-provider.py","launch-confirmed",name];
        observing = true; child.running = true;
        watchdog.restart();
        return true;
    }
    function show(serial) {
        if (!owns(serial) || !signalReady || stopRequested) return false;
        child.signal(12); return true;
    }
    function hide(serial) {
        if (!owns(serial) || !signalReady || stopRequested) return false;
        child.signal(10); return true;
    }
    function stop(serial) {
        if (!owns(serial) || stopRequested) return false;
        stopRequested = true; observing = false; watchdog.stop();
        child.running = false; // SIGTERM only, after controller confirmation.
        return true;
    }
    function probe() {
        if (!observing || !child.running || !child.processId || observer.running) return;
        observationSerial = ownerSerial; observationPid = child.processId;
        observer.command = ["python3",Quickshell.shellDir+"/scripts/osk-provider.py","observe",String(observationPid),providerName];
        observer.running = true;
    }
    function consumeObservation(text) {
        if (!observing || !owns(observationSerial) || child.processId !== observationPid) return;
        try {
            const result = JSON.parse(text);
            if (result.ok === true && result.ready === true) {
                signalReady = true; observing = false; watchdog.stop();
                providerStarted(ownerSerial);
            }
        } catch (error) { /* Bounded watchdog reports failed readiness. */ }
    }
    function childExited(code) {
        const serial = ownerSerial;
        const requested = stopRequested;
        visibilityKnown=false;visible=false;geometryChanged();
        observing = false; signalReady = false; watchdog.stop(); ownerSerial = 0;
        if (serial > 0) providerExited(serial, requested || code === 0);
    }
    Timer { interval: 250; running: root.observing; repeat: true; onTriggered: root.probe() }
    Timer {
        id: watchdog; interval: 11000
        onTriggered: { root.observing = false; root.providerFailed(root.ownerSerial); }
    }
    function consumeGeometry(line) {
        if (!child.running || ownerSerial < 1 || line.length>512) return;
        try {
            const data=JSON.parse(line);
            if (data.event!=="geometry" || typeof data.visible!=="boolean"
                || !Number.isInteger(data.width) || !Number.isInteger(data.height)
                || data.width<0 || data.width>16384 || data.height<0 || data.height>16384
                || (data.visible && (data.width===0 || data.height===0))) return;
            visibilityKnown=true;visible=data.visible;geometryChanged();
        } catch (_) { /* Only bounded geometry; never key text or arbitrary output. */ }
    }
    Process { id: managedChild; stdout: SplitParser { onRead: data => root.consumeGeometry(data) } onExited: (code, status) => root.childExited(code) }
    Process { id: readinessProbe; stdout: StdioCollector { onStreamFinished: root.consumeObservation(text) } }
}
