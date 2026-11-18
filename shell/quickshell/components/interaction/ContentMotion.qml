import QtQuick
import "../../config" as Config

// A route/disclosure response, never a loading gate or input lock. Deliberately
// keep readable content present; live telemetry must not be used as the context.
QtObject {
    id: root
    property Item targetItem: null
    property string context: ""
    property bool active: true
    property real floorOpacity: 0.72
    property int duration: Config.Motion.navigationMs
    property real progress: 1
    function pulse() {
        animation.stop();
        if(!active || !targetItem || !targetItem.visible || Config.Motion.reduced){progress=1;return;}
        progress=0;animation.start();
    }
    onContextChanged: pulse()
    onActiveChanged: if(!active){animation.stop();progress=1;}
    property Connections policy: Connections {
        target: Config.Motion
        function onReducedChanged(){if(Config.Motion.reduced){animation.stop();root.progress=1;}}
    }
    property Binding opacity: Binding {
        target: root.targetItem; property: "opacity"
        value: root.floorOpacity+(1-root.floorOpacity)*root.progress
        when: !!root.targetItem
    }
    property NumberAnimation animation: NumberAnimation {
        target: root; property:"progress";from:0;to:1
        duration:root.duration;easing.type:Easing.OutCubic
    }
}
