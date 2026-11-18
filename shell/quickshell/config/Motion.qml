pragma Singleton
import QtQuick

// Shared motion policy. Functional dwell/timeout timers do not use this policy.
QtObject {
    readonly property bool reduced: (Skin.registry.persona || {}).reducedMotion === true
    readonly property int openMs: reduced ? 0 : Theme.popupOpenMs
    readonly property int closeMs: reduced ? 0 : Theme.popupCloseMs
    readonly property int hoverMs: duration(Theme.motionHoverMs)
    readonly property int selectionMs: duration(Theme.motionSelectionMs)
    readonly property int menuMs: duration(Theme.motionMenuOpenMs)
    readonly property int compactMs: duration(Theme.motionCompactOpenMs)
    readonly property int lensMs: duration(Theme.motionLensOpenMs)
    readonly property int islandMs: duration(Theme.motionIslandOpenMs)
    readonly property int disclosureMs: duration(Theme.motionDisclosureMs)
    readonly property real travel: reduced ? 0 : Theme.motionTravelPx
    readonly property real islandTravel: reduced ? 0 : Theme.motionIslandTravelPx
    readonly property int navigationMs: duration(Theme.motionNavigationMs)
    readonly property int statusMs: duration(Theme.motionStatusMs)
    function duration(milliseconds) { return reduced ? 0 : Math.max(0,milliseconds); }
    function easing(opening) { return opening ? Easing.OutCubic : Easing.InCubic; }
}
