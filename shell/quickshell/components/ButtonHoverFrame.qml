pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../config" as Config

// Passive decoration: four traces leave the top/bottom centres, turn around
// the chamfers and meet at the side centres. Never changes the control's size.
Item {
    id: root
    objectName: "button-hover-frame"
    property bool trackPointer: false
    property bool engaged: !!autoHover.item && autoHover.item.hovered
    property bool selected: false
    property Item focusTarget: null
    property var pointerTarget: null
    property bool focusEligible: true
    property bool pointerFocus: false
    property bool focused: !!focusTarget && focusTarget.activeFocus && focusEligible && !pointerFocus
    Connections {
        target: root.focusTarget
        function onActiveFocusChanged() { if (!root.focusTarget || !root.focusTarget.activeFocus) root.pointerFocus = false; }
    }
    // Release precedes clicked in MouseArea. Check after click handlers finish so
    // canceled/disabled clicks cannot suppress the next keyboard focus cue.
    function clearPointerIfUnfocused() {
        if (!focusTarget || !focusTarget.activeFocus) pointerFocus = false;
    }
    Connections {
        target: root.pointerTarget
        function onPressed(mouse) { root.pointerFocus = true; }
        function onReleased(mouse) { Qt.callLater(root.clearPointerIfUnfocused); }
        function onCanceled() { Qt.callLater(root.clearPointerIfUnfocused); }
    }
    property color strokeColor: Config.DirectoryStyle.highContrast ? Config.DirectoryStyle.ink : Config.DirectoryStyle.muted
    readonly property bool revealing: enabled && visible && engaged
    property real hoverProgress: revealing ? 1 : 0
    readonly property real progress: visible && (selected || focused) ? 1 : hoverProgress
    readonly property real inset: Config.DirectoryStyle.frameInsetFor(width, height)
    readonly property real halfWidth: Math.max(0, width / 2 - inset)
    readonly property real halfHeight: Math.max(0, height / 2 - inset)
    readonly property real corner: Config.DirectoryStyle.frameCornerFor(width, height)
    readonly property real horizontalLineStart: inset + corner
    readonly property real contentInset: Config.DirectoryStyle.contentInsetFor(width, height)
    readonly property real horizontal: halfWidth - corner
    readonly property real diagonal: Math.SQRT2 * corner
    readonly property real distance: progress * (horizontal + diagonal + halfHeight - corner)
    readonly property real run: Math.min(horizontal, distance)
    readonly property real turn: Math.min(corner, Math.max(0, distance - horizontal) / Math.SQRT2)
    readonly property real rise: Math.min(halfHeight - corner, Math.max(0, distance - horizontal - diagonal))
    z: 4
    Behavior on hoverProgress {
        enabled: !root.selected && !root.focused
        NumberAnimation {
            duration: Config.Motion.duration(root.revealing ? 180 : 120)
            easing.type: root.revealing ? Easing.OutCubic : Easing.InCubic
        }
    }
    // Standard controls supply their hover signal. Create a native observer only
    // for older allocations which explicitly opt in; decorative overlays stay passive.
    Loader {
        id: autoHover
        anchors.fill: parent
        active: root.trackPointer
        sourceComponent: Item {
            readonly property bool hovered: pointer.hovered
            HoverHandler {
                id: pointer
                blocking: false
                enabled: root.enabled && root.visible
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            }
        }
    }
    Loader {
        objectName: "button-hover-geometry"
        anchors.fill: parent
        active: root.progress > 0 && root.visible
        sourceComponent: Shape {
            anchors.fill: parent
            antialiasing: true
            opacity: Config.DirectoryStyle.highContrast ? 1 : 0.85
            ShapePath {
                strokeColor: root.strokeColor
                strokeWidth: 1
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.MiterJoin
                fillColor: "transparent"
                startX: root.width / 2; startY: root.inset
                PathLine { x: root.width / 2 - root.run; y: root.inset }
                PathLine { x: root.width / 2 - root.run - root.turn; y: root.inset + root.turn }
                PathLine { x: root.width / 2 - root.run - root.turn; y: root.inset + root.turn + root.rise }
                PathMove { x: root.width / 2; y: root.inset }
                PathLine { x: root.width / 2 + root.run; y: root.inset }
                PathLine { x: root.width / 2 + root.run + root.turn; y: root.inset + root.turn }
                PathLine { x: root.width / 2 + root.run + root.turn; y: root.inset + root.turn + root.rise }
                PathMove { x: root.width / 2; y: root.height - root.inset }
                PathLine { x: root.width / 2 - root.run; y: root.height - root.inset }
                PathLine { x: root.width / 2 - root.run - root.turn; y: root.height - root.inset - root.turn }
                PathLine { x: root.width / 2 - root.run - root.turn; y: root.height - root.inset - root.turn - root.rise }
                PathMove { x: root.width / 2; y: root.height - root.inset }
                PathLine { x: root.width / 2 + root.run; y: root.height - root.inset }
                PathLine { x: root.width / 2 + root.run + root.turn; y: root.height - root.inset - root.turn }
                PathLine { x: root.width / 2 + root.run + root.turn; y: root.height - root.inset - root.turn - root.rise }
            }
        }
    }
}
