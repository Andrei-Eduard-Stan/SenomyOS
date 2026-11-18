import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../config" as Config
import "interaction" as Interaction

PanelWindow {
    id: root
    required property var targetScreen
    required property var senomy
    property var media: null
    required property var metrics
    property real anchorCenterX: targetScreen ? targetScreen.width / 2 : 450
    property bool requestedOpen: false
    property bool keyboardRequested: false
    signal closeRequested()
    readonly property real reveal: motion.progress
    readonly property string lifecycle: !requestedOpen && motion.retained ? "closing" : requestedOpen && !nativeReady ? "preparing" : motion.phase
    property bool nativeReady: false
    Interaction.SurfaceMotion {
        id: motion
        shown: root.requestedOpen && root.nativeReady
        openMs: Config.Motion.islandMs
    }
    Connections {
        target: root.contentItem.Window.window
        function onFrameSwapped() {
            if (!root.requestedOpen || root.nativeReady) return;
            root.nativeReady = true;
            if (root.keyboardRequested) stage.forceActiveFocus(Qt.PopupFocusReason);
        }
    }
    readonly property bool hovered: hover.hovered
    signal openPerformance()
    signal openInsights()

    onVisibleChanged: if (!visible) nativeReady = false
    onRequestedOpenChanged: if (requestedOpen) {
        const window = contentItem.Window.window;
        if (window) window.update();
        if (nativeReady && keyboardRequested) stage.forceActiveFocus(Qt.PopupFocusReason);
    }
    screen: targetScreen
    readonly property var nativeMonitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null
    readonly property var reservations: nativeMonitor ? nativeMonitor.lastIpcObject.reserved : null
    readonly property real reservedLeft: reservations && reservations.length===4 ? Number(reservations[0]) : 0
    readonly property real reservedRight: reservations && reservations.length===4 ? Number(reservations[2]) : 0
    readonly property real reservedTop: reservations && reservations.length===4 ? Number(reservations[1]) : 0
    readonly property real reservedBottom: reservations && reservations.length===4 ? Number(reservations[3]) : Config.Theme.railHeight
    readonly property real availableHeight: Math.max(1,(targetScreen ? targetScreen.height : 860)-reservedTop-reservedBottom-16)
    readonly property real panelWidth: Math.max(1,Math.min(900,(targetScreen ? targetScreen.width : 924)-reservedLeft-reservedRight-24))
    readonly property var fitted: Config.OskGeometry.place(targetScreen, {
        x:reservedLeft+12,y:reservedTop+8,width:(targetScreen ? targetScreen.width : 924)-reservedLeft-reservedRight-24,height:availableHeight},
        panelWidth,content.implicitHeight+8,anchorCenterX)
    implicitHeight: fitted.height
    margins.bottom: Math.max(0,(targetScreen ? targetScreen.height : 860)-reservedBottom-fitted.y-fitted.height)
    color: "transparent"
    exclusiveZone: 0
    visible: requestedOpen || motion.retained
    anchors { left: true; right: true; bottom: true }
    WlrLayershell.namespace: "senomy-v2-machine-hover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.requestedOpen && root.keyboardRequested ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: root.requestedOpen ? stage : null }


    FocusScope {
        id: stage
        objectName: "machineStage"
        focus: root.keyboardRequested && root.requestedOpen
        Keys.onEscapePressed: root.closeRequested()
        Keys.onReturnPressed: root.openPerformance()
        Keys.onSpacePressed: root.openPerformance()
        x: root.fitted.x
        y: 0
        width: root.fitted.width
        height: Math.max(1,root.fitted.height-8)
        opacity: root.reveal
        enabled: root.requestedOpen
        scale: 1
        transformOrigin: Item.Bottom
        transform: Translate { y: (1 - root.reveal) * Config.Motion.islandTravel }
        HoverHandler { id: hover }
        Flickable {
            objectName: "machineScroll"
            anchors.fill:parent
            contentHeight:content.implicitHeight
            interactive: contentHeight > height + 1
            clip:true
            boundsBehavior:Flickable.StopAtBounds
            ExpandedSenomyPanel {
                id:content
                width:parent.width;height:implicitHeight
                metrics:root.metrics;media:root.media;active:root.requestedOpen
                onOpenPerformance:root.openPerformance()
                onOpenInsights:root.openInsights()
            }
        }
    }
}
