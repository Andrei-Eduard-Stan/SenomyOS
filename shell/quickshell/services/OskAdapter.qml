import QtQuick
import Quickshell
import Quickshell.Io
import "../config" as Config

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
    property bool avoidance: false
    property bool modeSupported: false
    property bool floating: false
    property var lastGeometry: null
    property bool lockSync: false
    property bool lockStateKnown: false
    property int capsRequests: 0
    readonly property string lockMessage: !lockSync ? "Physical Caps Lock sync is unavailable for this provider." : lockStateKnown ? "Caps Lock is shared with connected physical keyboards." : "Caps Lock sync is connecting or unavailable."
    signal textFocusEvent(bool active)
    signal geometryChanged()
    signal providerStarted(int serial)
    signal providerFailed(int serial)
    signal providerExited(int serial, bool successful)

    function owns(serial) { return serial === ownerSerial && ownerSerial > 0 && child.running; }
    function start(name, serial, automatic=false) {
        if (child.running || ["wvkbd-mobintl","wvkbd-deskintl"].indexOf(name) < 0 || serial < 1) return false;
        visibilityKnown=false;visible=false;lockSync=false;lockStateKnown=false;capsRequests=0;modeSupported=false;
        ownerSerial = serial; providerName = name; signalReady = false; stopRequested = false;
        child.command = ["python3",Quickshell.shellDir+"/scripts/osk-provider.py",automatic ? "launch-auto" : "launch-confirmed",name];
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
    function toggle(serial) {
        if (!owns(serial) || !signalReady || stopRequested) return false;
        child.signal(34); // Linux SIGRTMIN: provider chooses from its actual state.
        return true;
    }
    function disableAutoFocus(serial) {
        if (!owns(serial) || !signalReady || stopRequested || !modeSupported) return false;
        child.write("focus:off\n");return true;
    }
    function enableAutoFocus(serial) {
        if (!owns(serial) || !signalReady || stopRequested || !modeSupported) return false;
        child.write("focus:on\n");return true;
    }
    function toggleMode(serial) {
        if (!owns(serial) || !signalReady || stopRequested || !modeSupported) return false;
        child.signal(35); return true;
    }
    function consumeFit(line) {
        try {const result=JSON.parse(line);if(visible) Config.OskGeometry.update(result);else Config.OskGeometry.clear();} catch (_) {Config.OskGeometry.clear();}
    }
    function consumeLockState(line) {
        if (!lockSync || !owns(ownerSerial) || line.length>256) return;
        try {
            const data=JSON.parse(line);
            lockStateKnown=data.ok===true && data.available===true && typeof data.capsLock==="boolean";
            if (lockStateKnown) child.write(data.capsLock ? "caps:1\n" : "caps:0\n");
        } catch (_) {}
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
        visibilityKnown=false;visible=false;lockSync=false;lockStateKnown=false;capsRequests=0;modeSupported=false;avoidance=false;lastGeometry=null;Config.OskGeometry.clear();geometryChanged();
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
            if (data.event==="text-focus" && typeof data.active==="boolean") {textFocusEvent(data.active);return;}
            if (data.event==="caps-toggle") {
                if (lockSync && signalReady && capsRequests<32) {capsRequests++;if (!capsToggle.running) capsToggle.running=true;}
                return;
            }
            if (data.event!=="geometry" || typeof data.visible!=="boolean"
                || !Number.isInteger(data.width) || !Number.isInteger(data.height)
                || data.width<0 || data.width>16384 || data.height<0 || data.height>16384
                || (data.visible && (data.width===0 || data.height===0))) return;
            visibilityKnown=true;visible=data.visible;lockSync=data.lockSync===true;
            modeSupported=typeof data.floating==="boolean" && typeof data.avoidance==="boolean";
            avoidance=data.avoidance===true;floating=data.floating===true;
            if (Number.isInteger(data.x) && Number.isInteger(data.y) && data.x>=0 && data.y>=0 && data.x+data.width<=16384 && data.y+data.height<=16384) {
                lastGeometry=data;
                if (fitBridge.running) fitBridge.write(JSON.stringify(data)+"\n");
            }
            if (!visible) Config.OskGeometry.clear();
            geometryChanged();
        } catch (_) { /* Only bounded geometry; never key text or arbitrary output. */ }
    }
    Process {
        id: fitBridge
        running: root.avoidance && root.child.running && root.signalReady
        stdinEnabled: true
        command: ["python3",Quickshell.shellDir+"/scripts/osk-geometry.py",String(root.child.processId)]
        onStarted: {if(root.lastGeometry) write(JSON.stringify(root.lastGeometry)+"\n");}
        stdout: SplitParser {onRead: data => root.consumeFit(data)}
    }
    Process {
        id: lockEvents
        // The event bridge also arms parent-death SIGTERM for abrupt shell exit.
        running: root.lockSync && root.child.running && root.signalReady
        command: ["python3",Quickshell.shellDir+"/scripts/osk-lock-state.py","stream"]
        stdout: SplitParser { onRead: data => root.consumeLockState(data) }
    }
    Process { id: capsToggle;
        onExited: (code,status) => {
            root.capsRequests=Math.max(0,root.capsRequests-1);
            if (code!==0) root.lockStateKnown=false;
            if (root.capsRequests>0 && root.lockSync && root.owns(root.ownerSerial)) capsToggle.running=true;
        }
        command: ["python3",Quickshell.shellDir+"/scripts/osk-lock-state.py","toggle"] }
    Process { id: managedChild; stdinEnabled: true; stdout: SplitParser { onRead: data => root.consumeGeometry(data) } onExited: (code, status) => root.childExited(code) }
    Process { id: readinessProbe; stdout: StdioCollector { onStreamFinished: root.consumeObservation(text) } }
}
