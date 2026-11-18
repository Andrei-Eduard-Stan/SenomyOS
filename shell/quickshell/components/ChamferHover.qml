import QtQuick
// Compatibility adapter for the Rail's existing background slots.
Item {
    property bool leftCorner: false
    property bool rightCorner: false
    property bool highlighted: false
    property bool selected: false
    property bool focused: false
    property Item focusTarget: null
    property var pointerTarget: null
    ButtonHoverFrame { id: cue; anchors.fill: parent; engaged: parent.highlighted; selected: parent.selected; focused: parent.focused || (!!parent.focusTarget && parent.focusTarget.activeFocus && !cue.pointerFocus); focusTarget: parent.focusTarget; pointerTarget: parent.pointerTarget }
}
