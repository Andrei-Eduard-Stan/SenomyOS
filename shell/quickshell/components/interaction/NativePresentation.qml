import QtQuick
import QtQuick.Window

// Frame admission and visual retention inside an existing native host.
// No routing, device action, focus grab or native-geometry authority.
QtObject {
    id: root
    property Item targetItem: null
    property bool requested: false
    property bool suppressed: false
    property bool focusOnReady: true
    property bool contentReady: true
    property bool frameReady: false
    readonly property var window: targetItem ? targetItem.Window.window : null
    readonly property bool shown: requested && frameReady && contentReady && !suppressed
    readonly property real progress: motion.progress
    readonly property bool retained: motion.retained
    readonly property string phase: requested && (!frameReady || !contentReady) ? "preparing" : motion.phase
    signal closed()
    function requestFrame() { if (requested && window && window.visible) window.update(); }
    function focusContent() { if(shown && focusOnReady && targetItem)targetItem.forceActiveFocus(Qt.PopupFocusReason); }
    onWindowChanged: { frameReady=false; requestFrame(); }
    onRequestedChanged: { if(requested){requestFrame();focusContent();} }
    onShownChanged: focusContent()
    Component.onCompleted: requestFrame()
    property SurfaceMotion motion: SurfaceMotion {
        shown: root.shown
        allowed: root.frameReady && root.contentReady && !root.suppressed
        onClosed: root.closed()
    }
    property Connections events: Connections {
        target: root.window
        function onVisibleChanged() {
            if(!root.window.visible)root.frameReady=false;
            else root.requestFrame();
        }
        function onFrameSwapped() {
            if(root.requested && root.window && root.window.visible && !root.frameReady)root.frameReady=true;
        }
    }
}
