import QtQuick
import QtQuick.Window

// Focus policy only: this object never requests, confirms or cancels an action.
QtObject {
    id: root
    required property var view
    required property var actions
    required property var cancelButton
    property var previousFocus: null
    property int generation: 0

    function inside(item, ancestor) {
        while (item) {
            if (item === ancestor) return true;
            item = item.parent;
        }
        return false;
    }

    function reconcile() {
        const serial = ++generation;
        if (!view || !actions || !cancelButton || !view.Window.window)
            return;
        const window = view.Window.window;
        if (actions.actionState === "pending") {
            if (!previousFocus)
                previousFocus = window.activeFocusItem;
            Qt.callLater(function() {
                if (serial === root.generation && root.view.visible
                        && root.actions.actionState === "pending" && root.cancelButton.visible)
                    root.cancelButton.forceActiveFocus(Qt.TabFocusReason);
            });
        } else if (actions.actionState !== "running") {
            Qt.callLater(function() {
                if (serial !== root.generation || !root.view.visible)
                    return;
                const previous = root.previousFocus;
                root.previousFocus = null;
                const current = window.activeFocusItem;
                // Respect deliberate focus movement outside the review. Never
                // resurrect old route focus after closing/replacing its context.
                if (current && current !== previous && !root.inside(current, root.view))
                    return;
                if (previous && previous.visible && previous.enabled)
                    previous.forceActiveFocus(Qt.TabFocusReason);
            });
        }
    }

    property var stateObserver: Connections {
        target: root.actions
        function onActionStateChanged() { root.reconcile(); }
    }
    property var visibilityObserver: Connections {
        target: root.view
        function onVisibleChanged() {
            if (root.view.visible)
                root.reconcile();
            else if (root.actions.actionState === "pending")
                ++root.generation;
        }
    }
    Component.onCompleted: reconcile()
}
