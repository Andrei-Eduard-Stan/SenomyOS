pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQml.Models

// mapToItem/updateAnchor are imperative: a trigger's local x/y do not notify
// when a Row or another ancestor moves. Observe only the requested owner's
// chain; no polling or connections to every Rail while the popup is closed.
QtObject {
    id: root
    property var item: null
    property bool active: false
    readonly property var window: item ? item.Window.window : null
    // A QWindow can exist and report visible before its Wayland parent has
    // received its first configure/layout. Use the parent's first queued frame
    // as readiness, then disconnect. Late-created trackers request one update.
    property bool parentReady: false
    readonly property bool ready: !!item && item.visible && item.width > 0 && item.height > 0
        && !!window && window.visible && parentReady
    readonly property var ancestors: {
        const chain = [];
        for (let node = item; node; node = node.parent) chain.push(node);
        return chain;
    }
    signal moved()
    onReadyChanged: if (active) moved()
    onWindowChanged: {
        parentReady = false;
        if (active && window) window.update();
        if (active) moved();
    }
    onActiveChanged: if (active && window && !parentReady) window.update()
    property Connections readiness: Connections {
        target: !root.parentReady ? root.window : null
        function onFrameSwapped() { if (root.window && root.window.visible) root.parentReady = true; }
    }
    property Connections lifetime: Connections {
        target: root.window
        function onVisibleChanged() {
            if (!root.window.visible) root.parentReady = false;
            else if (root.active && !root.parentReady) root.window.update();
        }
    }
    property Instantiator observers: Instantiator {
        model: root.active ? root.ancestors : []
        delegate: QtObject {
            id: observer
            required property var modelData
            property Connections geometry: Connections {
                target: observer.modelData
                function onXChanged() { root.moved(); }
                function onYChanged() { root.moved(); }
                function onWidthChanged() { root.moved(); }
                function onHeightChanged() { root.moved(); }
                function onScaleChanged() { root.moved(); }
                function onRotationChanged() { root.moved(); }
                function onTransformOriginChanged() { root.moved(); }
                function onParentChanged() { root.moved(); }
            }
        }
    }
    property Connections windowEvents: Connections {
        target: root.active ? root.window : null
        function onWidthChanged() { root.moved(); }
        function onHeightChanged() { root.moved(); }
        function onScreenChanged() { root.moved(); }
    }
}
