import QtQuick
import QtQuick.Controls
import "Theme.js" as Theme

AbstractButton {
    id: root
    property int fontPixelSize: 14
    property bool highlighted: false
    property bool destructive: false
    property bool quiet: false
    property bool selected: false
    property int alignment: Text.AlignHCenter
    property url iconSource: ""
    padding: 12
    implicitWidth: Math.max(48,label.implicitWidth+24+(iconSource.toString().length?28:0))
    implicitHeight: Math.max(Theme.controlHeight,implicitContentHeight+24)
    activeFocusOnTab: visible && enabled
    Accessible.name: text
    Accessible.role: Accessible.Button
    Keys.onReturnPressed: if(enabled)clicked()
    Keys.onEnterPressed: if(enabled)clicked()
    contentItem: Row {
        spacing: root.iconSource.toString().length ? 8 : 0
        Image {visible:root.iconSource.toString().length>0;source:root.iconSource;width:20;height:20;anchors.verticalCenter:parent.verticalCenter;fillMode:Image.PreserveAspectFit;opacity:root.enabled?1:0.45}
        Text {
            id:label
            width:Math.max(1,parent.width-(root.iconSource.toString().length?28:0))
            text:root.text;textFormat:Text.PlainText
            color:!root.enabled?Theme.muted:root.highlighted?Theme.background:root.destructive?Theme.danger:Theme.foreground
            font.family:Theme.bodyFont;font.pixelSize:root.fontPixelSize
            horizontalAlignment:root.alignment;verticalAlignment:Text.AlignVCenter
            wrapMode:Text.Wrap
        }
    }
    background: Canvas {
        property bool keyboard:root.visualFocus
        property bool emphasis:root.highlighted && root.enabled
        property bool selection:root.selected
        property bool pressed:root.down
        property bool quiet:root.quiet
        onKeyboardChanged:requestPaint();onEmphasisChanged:requestPaint();onSelectionChanged:requestPaint();onPressedChanged:requestPaint();onQuietChanged:requestPaint()
        onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        onPaint:{
            const c=getContext("2d");c.reset();const k=6,w=width-1,h=height-1;
            c.beginPath();c.moveTo(k,1);c.lineTo(w-k,1);c.lineTo(w,k);c.lineTo(w,h-k);c.lineTo(w-k,h);c.lineTo(k,h);c.lineTo(1,h-k);c.lineTo(1,k);c.closePath();
            c.fillStyle=emphasis?Theme.foreground:selection?"#363b424d":pressed?"#303b414b":quiet?"transparent":"#24181d25";c.fill();
            c.strokeStyle=keyboard?Theme.foreground:selection?"#9aa7b3c0":quiet?"transparent":"#555c6470";c.lineWidth=keyboard?1.5:1;c.stroke();
        }
    }
}
