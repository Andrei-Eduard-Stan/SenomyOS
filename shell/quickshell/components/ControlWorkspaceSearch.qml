import QtQuick
import "../config" as Config
InsightsWorkspaceSearch {
 id:root
 background:Canvas {
  property color fillColor:Config.Theme.glassRaised
  property color lineColor:root.activeFocus?Config.DirectoryStyle.ink:Config.DirectoryStyle.rule
  onFillColorChanged:requestPaint();onLineColorChanged:requestPaint();onWidthChanged:requestPaint();onHeightChanged:requestPaint()
  onPaint:{const c=getContext("2d");c.reset();const i=Config.DirectoryStyle.controlFrameInset,k=Config.DirectoryStyle.controlFrameCorner,r=width-i,b=height-i;c.beginPath();c.moveTo(i+k,i);c.lineTo(r-k,i);c.lineTo(r,i+k);c.lineTo(r,b-k);c.lineTo(r-k,b);c.lineTo(i+k,b);c.lineTo(i,b-k);c.lineTo(i,i+k);c.closePath();c.fillStyle=fillColor;c.fill();c.strokeStyle=lineColor;c.lineWidth=root.activeFocus?1.5:1;c.stroke();}
 }
}
