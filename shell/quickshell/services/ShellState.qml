import QtQuick
import Quickshell
import "../components/ControlDirectory.js" as Routes

// One authoritative interaction graph for every Quickshell surface.
Scope {
    id: root

    readonly property var primarySurfaces: ["control", "performance", "insights"]
    readonly property var popupSurfaces: ["volume", "network", "bluetooth", "battery", "tray", "calendar", "notifications", "power", "lens"]

    property bool capturePaused: false
    property string captureToken: ""
    function pauseCapture(token) {
        if (!/^[a-f0-9]{32}$/.test(token) || (capturePaused && captureToken!==token)) return false;
        captureToken=token;capturePaused=true;return true;
    }
    function resumeCapture(token) {
        if (captureToken!==token) return false;
        capturePaused=false;captureToken="";return true;
    }
    property string activePrimary: ""
    property string primaryScreen: ""
    property string activePopup: ""
    property string lensMode: "apps"
    property int popupGeneration: 0
    property var railWindows: []
    property var availableScreens: null
    function validScreen(name){return !!name && (availableScreens === null || availableScreens.indexOf(name) >= 0);}
    property var popupTrigger: null
    property bool popupKeyboard: false
    property var confirmationSources: []
    property bool externalModalActive: false
    property bool pageModalActive: false
    readonly property bool modalActive: pageModalActive || !!deferredPrimary || externalModalActive || confirmationSources.some(source => source && (source.actionState === "pending" || source.actionState === "running" || source.locked === true))
    signal modalCancelRequested()
    signal interactionBlocked()
    function allowInteraction() {
        if (!modalActive) return true;
        interactionBlocked();
        if (activePrimary === "control" && controlMode === "full") settingsRequested();
        return false;
    }
    function dismissExternal(ownedKeyboardFocus) {
        // Hyprland's non-consuming Escape is also delivered to Qt. Defer to
        // that window's innermost handler; never dismiss a persistent window
        // from another application's Escape or repeat a local cancellation.
        if (ownedKeyboardFocus) return "owned";
        if (modalActive) return "modal";
        if (activePopup) return closePopups() ? "popup" : "modal";
        return "none";
    }
    function escapeOverlay() {
        if (modalActive) { modalCancelRequested(); return "modal"; }
        return dismissTransient();
    }
    property var controlHistory: []
    property int controlHistoryIndex: -1
    property bool replayingHistory: false
    readonly property bool canGoBack: controlHistoryIndex > 0
    readonly property bool canGoForward: controlHistoryIndex + 1 < controlHistory.length
    function recordControlRoute() {
        const route = controlPath || controlSection;
        if (replayingHistory || controlHistory[controlHistoryIndex] === route) return;
        const entries = controlHistory.slice(0, controlHistoryIndex + 1);
        entries.push(route);
        controlHistory = entries.slice(-64);
        controlHistoryIndex = controlHistory.length - 1;
    }
    function navigateControl(route) {
        if (!Routes.validRoute(String(route)) || !allowInteraction()) return false;
        return showPrimary("control", primaryScreen, route, controlMode);
    }
    function travelControl(direction) {
        const index = controlHistoryIndex + direction;
        if (index < 0 || index >= controlHistory.length) return false;
        const route = controlHistory[index];
        // Dirty drafts defer the route just like a deep link. History is only
        // moved after the requested destination has actually been accepted.
        replayingHistory = true;
        const accepted = navigateControl(route);
        replayingHistory = false;
        if (accepted) controlHistoryIndex = index;
        else if (deferredPrimary) deferredPrimary = Object.assign({},deferredPrimary,{historyIndex:index});
        return accepted;
    }
    property string controlMode: "compact"
    property string controlSection: "overview"
    property string controlPath: ""
    property var controlPins:[]
    property bool controlDraftDirty: false
    property var deferredPrimary: null
    function guardPrimary(kind, screenName, section, closing, mode) {
        if (activePrimary === "control" && controlDraftDirty && (closing || kind !== "control" || mode !== controlMode || screenName !== primaryScreen || (section && section !== (controlPath || controlSection)))) {
            deferredPrimary = {
                kind: kind,
                screen: screenName,
                section: section,
                closing: closing,
                mode: mode
            };
            if(controlMode === "full")settingsRequested();
            return true;
        }
        return false;
    }
    function completeDeferredPrimary() {
        const next = deferredPrimary;
        deferredPrimary = null;
        if (!next)
            return false;
        controlDraftDirty = false;
        const historyIndex = next.historyIndex;
        replayingHistory = historyIndex !== undefined;
        const accepted = next.closing ? closePrimary() : showPrimary(next.kind, next.screen, next.section, next.mode);
        replayingHistory = false;
        if (accepted && historyIndex !== undefined) controlHistoryIndex = historyIndex;
        return accepted;
    }
    onControlSectionChanged: controlPath = ""
    property string performanceSection: "cpu"
    property string insightsSection: "briefing"

    readonly property bool dashboardActive: activePrimary === "performance"

    function token(kind, screenName) {
        return kind + ":" + screenName;
    }

    function popupOpen(kind, screenName) {
        return activePopup === token(kind, screenName);
    }

    function togglePopup(kind, screenName, trigger) {
        if (popupSurfaces.indexOf(kind) < 0 || !validScreen(screenName) || !allowInteraction()) return false;
        const requested = token(kind, screenName);
        const closing = activePopup === requested;
        ++popupGeneration;
        popupTrigger = closing ? null : (trigger || null);
        popupKeyboard = !!(trigger && trigger.activeFocus);
        activePopup = closing ? "" : requested;
        return true;
    }

    // Dismissals carry a lease: an old window/focus callback cannot close its
    // replacement, including a new opening of the same kind on the same Rail.
    function closePopups(expectedToken, expectedGeneration, force) {
        if (expectedToken && expectedToken !== activePopup) return false;
        if (expectedGeneration !== undefined && expectedGeneration !== popupGeneration) return false;
        if (!force && !allowInteraction()) return false;
        if (!activePopup) return true;
        const trigger = popupTrigger;
        const keyboard = popupKeyboard;
        ++popupGeneration;
        activePopup = "";
        popupTrigger = null;
        if (keyboard && trigger && trigger.visible && trigger.enabled)
            trigger.forceActiveFocus(Qt.PopupFocusReason);
        return true;
    }

    signal settingsRequested()
    function showSettings(screenName, section) {
        const accepted=showPrimary("control", screenName, section || (controlPath || controlSection), "full");
        if (!accepted && deferredPrimary) closePopups(undefined,undefined,true);
        return accepted;
    }

    function showPrimary(kind, screenName, section, mode) {
        mode = kind === "control" ? (mode || "compact") : "compact";
        if (["compact", "full"].indexOf(mode) < 0) return false;
        if (primarySurfaces.indexOf(kind) < 0 || !validScreen(screenName))
            return false;
        if (kind === "control" && section && !Routes.validRoute(String(section)))
            return false;
        if (!allowInteraction()) return false;
        if (guardPrimary(kind, screenName, section, false, mode))
            return false;
        deferredPrimary = null;
        closePopups();
        if (kind === "control") controlMode = mode;
        primaryScreen = screenName;
        activePrimary = kind;
        if (section) {
            if (kind === "control") {
                controlSection = String(section).split("/")[0];
                controlPath = String(section).includes("/") ? section : "";
            } else if (kind === "performance")
                performanceSection = section;
            else if (kind === "insights")
                insightsSection = section;
        }
        if (kind === "control") {recordControlRoute(); settingsRequested();}
        return true;
    }

    function togglePrimary(kind, screenName, section, mode) {
        if (activePrimary === kind && primaryScreen === screenName) {
            return closePrimary();
        }
        return showPrimary(kind, screenName, section, mode);
    }

    function closePrimary() {
        if (!allowInteraction()) return false;
        if (guardPrimary("", "", "", true))
            return false;
        deferredPrimary = null;
        activePrimary = "";
        primaryScreen = "";
        return true;
    }

    function dismissTransient() {
        if (activePopup) {
            return closePopups() ? "popup" : "modal";
        }
        if (activePrimary) {
            return closePrimary() ? "primary" : "review";
        }
        return "none";
    }

}
