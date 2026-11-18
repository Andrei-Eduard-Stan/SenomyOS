import QtQuick
import QtQuick.Window
import "../config" as Config

Item {
    id: root
    property bool animate: true
    // Rail clients request motion only while engaged; other surfaces keep ambient light.
    property bool idleMotion: true
    property bool engaged: false
    property real strength: 1
    property real restingPhase: 0
    readonly property bool wantsMotion: animate && (idleMotion || engaged) && visible && !!Window.window && Window.window.visible && !Config.Motion.reduced
    property bool registered:false
    function syncLight() {
        if(wantsMotion && !registered){registered=true;Config.ReflectionLight.acquire();}
        else if(!wantsMotion && registered){registered=false;Config.ReflectionLight.release();}
    }
    onWantsMotionChanged: {
        if (!wantsMotion && !idleMotion) restingPhase = Config.ReflectionLight.phase;
        syncLight();
    }
    Component.onCompleted:syncLight()
    Component.onDestruction:if(registered)Config.ReflectionLight.release()
    readonly property real phase: wantsMotion ? Config.ReflectionLight.phase : idleMotion || Config.Motion.reduced ? 0 : restingPhase
    // Screen position approximates incidence angle from a shared, distant light.
    readonly property real incidence: {
        const tick = phase;
        return mapToGlobal(width / 2, 0).x / Math.max(1, Screen.width);
    }
    readonly property real direction: phase + incidence * 2.4
    readonly property real progress: 0.5 + 0.36 * Math.sin(direction)
    readonly property real intensity: 0.35 + 0.45 * Math.pow(0.5 + 0.5 * Math.cos(direction - 0.6), 2)
    readonly property real beamWidth: Math.min(150, width * 0.72)
    clip: true
    Image {
        width: root.beamWidth * 1.15; height: 20
        x: (parent.width - width) * root.progress - 5; y: -8
        source: "../assets/sheen-cyan.png"; opacity: Math.min(1, root.intensity * 0.36 * root.strength)
    }
    Image {
        width: root.beamWidth; height: 18
        x: (parent.width - width) * root.progress + 6; y: -7
        source: "../assets/sheen-violet.png"; opacity: Math.min(1, root.intensity * 0.4 * root.strength)
    }
    Image {
        width: root.beamWidth; height: 18
        x: (parent.width - width) * root.progress; y: -8
        source: "../assets/reflection-glow.png"; opacity: Math.min(1, root.intensity * root.strength)
    }
}
