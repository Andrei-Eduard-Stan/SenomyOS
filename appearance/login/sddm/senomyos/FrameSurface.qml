import QtQuick
import "Theme.js" as Theme

// Fixed authored Island corners; only neutral rules stretch.
Item {
    id: frame
    objectName:"authored-auth-frame"
    property bool artworkReady:false
    property real opticalScale: 1
    property string motif: ""
    property string motifAnchor: "top"
    property color surfaceColor: "#a6080a0c"
    property bool artwork: true
    property url artworkSource: "assets/island-background.png"
    property color accentColor: Theme.accent
    property color dangerColor: Theme.danger
    property bool focused: false
    property bool attention: false
    property bool critical: false
    readonly property real extent: Math.min(Theme.frameCorner, width / 3, height / 3)
    readonly property color ruleColor: critical ? dangerColor : focused ? accentColor : "#667d808b"
    Canvas {
        id:fill
        anchors.fill: parent
        Component.onCompleted: if(frame.artworkSource){loadImage(frame.artworkSource);frame.artworkReady=isImageLoaded(frame.artworkSource);}
        onImageLoaded:{frame.artworkReady=true;requestPaint();}
        Connections {target:frame;function onSurfaceColorChanged(){fill.requestPaint();}function onArtworkChanged(){fill.requestPaint();}}
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset();
            const k = Math.min(Theme.frameCut, width / 3, height / 3);
            c.beginPath(); c.moveTo(k, 0); c.lineTo(width-k, 0); c.lineTo(width, k);
            c.lineTo(width, height-k); c.lineTo(width-k, height); c.lineTo(k, height);
            c.lineTo(0, height-k); c.lineTo(0, k); c.closePath();
            c.fillStyle = frame.surfaceColor; c.fill();c.clip();
            if(frame.artwork && isImageLoaded(frame.artworkSource)){
                frame.artworkReady=true;
                const scale=Math.max(width/850,height/350);c.globalAlpha=0.36;
                c.drawImage(frame.artworkSource,(width-850*scale)/2,(height-350*scale)/2,850*scale,350*scale);
            }
        }
    }
    Rectangle { x: frame.extent; width: Math.max(0,parent.width-2*frame.extent); height:1; color:frame.ruleColor }
    Rectangle { x: frame.extent; y:parent.height-1; width:Math.max(0,parent.width-2*frame.extent);height:1;color:frame.ruleColor }
    Rectangle { y:frame.extent;width:1;height:Math.max(0,parent.height-2*frame.extent);color:frame.ruleColor }
    Rectangle { x:parent.width-1;y:frame.extent;width:1;height:Math.max(0,parent.height-2*frame.extent);color:frame.ruleColor }
    Repeater {
        model: [{file:"tl",right:false,bottom:false},{file:"tr",right:true,bottom:false},{file:"bl",right:false,bottom:true},{file:"br",right:true,bottom:true}]
        Image {
            required property var modelData
            x:modelData.right?frame.width-width:0; y:modelData.bottom?frame.height-height:0
            width:frame.extent;height:frame.extent;source:"assets/frames/island/corner-"+modelData.file+".svg"
            fillMode:Image.PreserveAspectFit
        }
    }
}
