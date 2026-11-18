import QtQuick
import "../config" as Config

Canvas {
    id: root
    property bool active: false
    property bool drawFill: true
    property bool hovered: false
    // Overlay the shared halo without repainting an existing authored frame.
    property bool glowOnly: false
    property bool hoverGlow: false
    property real glow: hoverGlow && hovered ? 1 : 0
    Behavior on glow { NumberAnimation { duration: Config.Motion.duration(160) } }
    onGlowChanged: requestPaint()
    onGlowOnlyChanged: requestPaint()
    onDrawFillChanged: requestPaint()
    onActiveChanged: requestPaint()
    onHoveredChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d"); c.reset();
        const w = width-1, h = height-1, cut = 7;
        c.beginPath(); c.moveTo(cut,1); c.lineTo(w-cut,1);
        c.lineTo(w,cut); c.lineTo(w,h-cut); c.lineTo(w-cut,h);
        c.lineTo(cut,h); c.lineTo(1,h-cut); c.lineTo(1,cut); c.closePath();
        c.fillStyle = "#a6080a0c";
        if (!root.glowOnly && root.drawFill) c.fill();
        const metal = c.createLinearGradient(0,0,w,h);
        metal.addColorStop(0, active ? "#f3eaff" : "#d8d3e2");
        metal.addColorStop(.35, active ? "#a78cce" : "#62616d");
        metal.addColorStop(.7,"#aaa6b6");
        metal.addColorStop(1, active ? "#cbb4ee" : "#e5deef");
        if (root.glow > 0) {
            c.strokeStyle = "rgba(229,226,246," + (0.15 * root.glow) + ")";
            c.lineWidth = 5; c.stroke();
            c.strokeStyle = "rgba(239,237,253," + (0.28 * root.glow) + ")";
            c.lineWidth = 3; c.stroke();
        }
        c.lineWidth = 1;
        if (!root.glowOnly) { c.strokeStyle = metal; c.stroke(); }
        if (root.glow > 0) {
            c.strokeStyle = "rgba(255,255,255," + (0.75 * root.glow) + ")";
            c.stroke();
        }
    }
    MetalSheen { visible: !root.glowOnly; anchors.fill: parent; anchors.margins: 1; idleMotion:false; engaged:false; strength: 1 + 1.2 * root.glow }
}
