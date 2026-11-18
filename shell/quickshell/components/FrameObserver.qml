import QtQuick
import "../config" as Config

// No connection and no animation timer while the diagnostic capture is stopped.
QtObject {
    id: root
    required property var targetItem
    property string key: "surface"
    property bool requested: false
    property string contentKey: ""
    onContentKeyChanged: if (Config.RenderMetrics.recording && requested) begin("content-change")
    property var transition: null
    readonly property var observedWindow: targetItem ? targetItem.Window.window : null
    // The first native window can appear after the request. Preserve that
    // request's clock; only split a capture when an already-presented host moves.
    onObservedWindowChanged: if (Config.RenderMetrics.recording && requested
            && observedWindow && transition && transition.firstFrameMs !== null) begin("host-change")
    function begin(origin) {
        if (transition) transition.closed = true;
        transition = requested ? Config.RenderMetrics.begin(key,origin) : null;
    }
    onRequestedChanged: begin("request")
    Component.onDestruction: if (transition) transition.closed = true
    property Connections stateEvents: Connections {
        target: Config.RenderMetrics
        function onRecordingChanged() { root.begin("probe-start"); }
    }
    property Connections windowEvents: Connections {
        target: Config.RenderMetrics.recording && root.requested && root.targetItem ? root.observedWindow : null
        function onFrameSwapped() { Config.RenderMetrics.frame(root.transition); }
    }
}
