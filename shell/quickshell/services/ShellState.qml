import Quickshell

// One authoritative interaction graph for every Quickshell surface. The
// companion is intentionally independent from the one-primary-surface rule.
Scope {
    id: root

    readonly property var primarySurfaces: ["control", "performance", "insights"]
    readonly property var popupSurfaces: ["volume", "tray", "calendar", "notifications", "power"]

    property string activePrimary: ""
    property string primaryScreen: ""
    property string activePopup: ""
    property string controlSection: "overview"
    property string performanceSection: "overview"
    property string insightsSection: "briefing"
    property string companionMode: "closed"
    property string companionScreen: ""
    property string companionDock: "right"
    property bool companionPinned: false

    readonly property bool dashboardActive: activePrimary === "performance"

    function token(kind, screenName) {
        return kind + ":" + screenName;
    }

    function popupOpen(kind, screenName) {
        return activePopup === token(kind, screenName);
    }

    function togglePopup(kind, screenName) {
        if (popupSurfaces.indexOf(kind) < 0 || !screenName)
            return false;
        const requested = token(kind, screenName);
        activePopup = activePopup === requested ? "" : requested;
        return true;
    }

    function closePopups() {
        activePopup = "";
    }

    function showPrimary(kind, screenName, section) {
        if (primarySurfaces.indexOf(kind) < 0 || !screenName)
            return false;
        closePopups();
        primaryScreen = screenName;
        activePrimary = kind;
        if (section) {
            if (kind === "control")
                controlSection = section;
            else if (kind === "performance")
                performanceSection = section;
            else if (kind === "insights")
                insightsSection = section;
        }
        return true;
    }

    function togglePrimary(kind, screenName, section) {
        if (activePrimary === kind && primaryScreen === screenName) {
            closePrimary();
            return true;
        }
        return showPrimary(kind, screenName, section);
    }

    function closePrimary() {
        activePrimary = "";
        primaryScreen = "";
    }

    function dismissTransient() {
        if (activePopup) {
            closePopups();
            return "popup";
        }
        if (activePrimary) {
            closePrimary();
            return "primary";
        }
        return "none";
    }

    function toggleCompanion(screenName) {
        companionScreen = screenName;
        companionMode = companionMode === "closed" ? "expanded" : "closed";
    }

    function setCompanionMode(mode, screenName) {
        if (["closed", "compact", "expanded"].indexOf(mode) < 0)
            return false;
        if (screenName)
            companionScreen = screenName;
        companionMode = mode;
        if (mode === "closed")
            companionPinned = false;
        return true;
    }
}
