import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

TextField {
    id: root
    property bool warning: false
    implicitHeight: 56
    leftPadding: 16; rightPadding: 16; topPadding: 12; bottomPadding: 12
    color: Theme.foreground
    placeholderTextColor: Theme.muted
    selectionColor: Theme.accent
    selectedTextColor: Theme.background
    font.family: Theme.bodyFont; font.pixelSize: 17
    selectByMouse: true
    activeFocusOnTab: visible && enabled
    clip: true
    background: Canvas {
        property bool focused:root.activeFocus
        property bool warning:root.warning
        onFocusedChanged:requestPaint();onWarningChanged:requestPaint();onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        onPaint:{
            const c=getContext("2d");c.reset();const k=6,w=width-1,h=height-1;
            c.beginPath();c.moveTo(k,1);c.lineTo(w-k,1);c.lineTo(w,k);c.lineTo(w,h-k);c.lineTo(w-k,h);c.lineTo(k,h);c.lineTo(1,h-k);c.lineTo(1,k);c.closePath();
            c.fillStyle="#b30a0d12";c.fill();c.strokeStyle=warning?Theme.warning:focused?Theme.foreground:"#68727c8a";c.lineWidth=focused?1.5:1;c.stroke();
        }
    }
}
