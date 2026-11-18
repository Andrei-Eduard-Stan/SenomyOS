import QtQuick
QtObject {
    id: root
    required property var controller
    property string mode: "auto"
    property var snapshot: null
    property bool autoShown: false
    property bool manualPinned: false
    property bool dismissed: false
    property double dismissedEpoch: -1
    property bool settingMode: false
    property bool stoppedByUser: false
    property bool focusRequested: false
    property bool releaseRequested: false
    readonly property bool available: !!snapshot && snapshot.ok === true
    readonly property bool eligible: available && mode === "auto" && !snapshot.locked && !snapshot.physicalKeyboard && !stoppedByUser
    readonly property string status: !available ? "Automatic opening is unavailable; manual controls still work."
        : mode === "manual" ? "Automatic opening is off."
        : controller.state === "failed" ? "Automatic opening failed; use the manual keyboard controls."
        : stoppedByUser ? "Automatic opening paused after Stop; use Show or re-enable Auto."
        : snapshot.physicalKeyboard ? "Physical keyboard detected; automatic opening is paused."
        : "Automatic opening is ready for supported text fields."
    function consume(line) {
        if (line.length>1024) return;
        try {
            const s=JSON.parse(line);
            if (["auto","manual"].indexOf(s.mode)<0) throw new Error("mode");
            mode=s.mode;
            if (s.ok!==true || !["physicalKeyboard","textActive","inputMethod","locked"].every(k=>typeof s[k]==="boolean")
                    || !Number.isSafeInteger(s.focusEpoch) || s.focusEpoch<0) snapshot=null;
            else snapshot=s;
        } catch (_) {snapshot=null;}
        reconcile();
    }
    function manual(showing) {
        if(showing)stoppedByUser=false;
        manualPinned=showing;autoShown=false;
        dismissed=!showing;dismissedEpoch=snapshot ? snapshot.focusEpoch : -1;
    }
    function reconcile() {
        if (snapshot && (!snapshot.textActive || snapshot.focusEpoch!==dismissedEpoch)) dismissed=false;
        if (!eligible) {
            if (!releaseRequested && controller.disableAutomaticFocus !== undefined) releaseRequested=controller.disableAutomaticFocus();
            focusRequested=false;
            if (autoShown && controller.hideAutomatic()) autoShown=false;
            return;
        }
        releaseRequested=false;
        if (manualPinned || dismissed) return;
        // Pre-arm a hidden provider only when no physical keyboard exists.
        // Its IME binding supplies focus events where no IME is already running.
        if (!controller.owned && !controller.startPending && (!snapshot.inputMethod || snapshot.textActive)) {
            controller.prepareAutomatic();return;
        }
        if (controller.startPending) return;
        if(snapshot.inputMethod)focusRequested=false;
        else if(controller.owned && !focusRequested && controller.enableAutomaticFocus !== undefined)focusRequested=controller.enableAutomaticFocus();
        if (snapshot.textActive) {
            if (!autoShown && controller.showAutomatic()) autoShown=true;
        } else if (autoShown && controller.hideAutomatic()) autoShown=false;
    }
    property var connections: Connections {
        target: root.controller
        function onManualStop() {root.stoppedByUser=true;root.autoShown=false;}
        function onManualAction(showing) {root.manual(showing);}
        function onStateChanged() {deferred.restart();}
        function onCapabilitiesChanged() {deferred.restart();}
    }
    property var deferred: Timer {id:deferred;interval:30;onTriggered:root.reconcile()}
}
