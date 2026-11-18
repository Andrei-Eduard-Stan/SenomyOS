import QtQuick

// One shell-owned controller, independent of per-output window lifetimes.
QtObject {
    id: root
    property string context: ""
    property var adapter: null
    property var ownedAdapter: null

    function release() {
        const previous = ownedAdapter;
        ownedAdapter = null;
        if (previous) previous.discovering = false;
    }

    function reconcile() {
        if (ownedAdapter && (!context || adapter !== ownedAdapter || !adapter.enabled))
            release();
        // Leave discovery already active when we arrived alone.
        if (context && adapter && adapter.enabled && !ownedAdapter && !adapter.discovering) {
            adapter.discovering = true;
            ownedAdapter = adapter;
        }
    }
    onContextChanged: reconcile()
    onAdapterChanged: reconcile()
    Component.onCompleted: reconcile()
    Component.onDestruction: release()
    property Connections adapterChanges: Connections {
        target: root.adapter
        function onEnabledChanged() { root.reconcile(); }
    }
}
