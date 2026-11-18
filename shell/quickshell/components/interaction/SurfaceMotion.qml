import QtQuick
import "../../config" as Config

// Visual progress only. ShellState and native hosts retain request/focus ownership.
// Retarget from the current value; completion, never a timer, ends retention.
QtObject {
    id: root
    property bool shown: false
    property bool allowed: true
    property int openMs: Config.Motion.openMs
    property int closeMs: Config.Motion.closeMs
    property real progress: 0
    readonly property bool running: animation.running
    readonly property bool retained: progress > 0 || animation.running
    readonly property string phase: animation.running ? (shown ? "opening" : "closing") : progress === 1 ? "open" : "closed"
    signal opened()
    signal closed()
    function retarget() {
        animation.stop();
        const goal = shown && allowed ? 1 : 0;
        const time = allowed ? Math.round((goal ? openMs : closeMs) * Math.abs(goal - progress)) : 0;
        if (!time || progress === goal) {
            progress = goal;
            if (goal) opened(); else closed();
            return;
        }
        animation.from = progress;
        animation.to = goal;
        animation.duration = time;
        animation.easing.type = Config.Motion.easing(goal === 1);
        animation.start();
    }
    onShownChanged: retarget()
    // Unmapping can change native readiness while this binding is evaluated.
    // Reconcile its latest value after the current property transaction.
    onAllowedChanged: Qt.callLater(retarget)
    onOpenMsChanged: retarget()
    onCloseMsChanged: retarget()
    Component.onCompleted: retarget()
    property NumberAnimation animation: NumberAnimation {
        target: root; property: "progress"
        onFinished: {
            if (root.progress === 1 && root.shown && root.allowed) root.opened();
            else if (root.progress === 0 && (!root.shown || !root.allowed)) root.closed();
        }
    }
}
