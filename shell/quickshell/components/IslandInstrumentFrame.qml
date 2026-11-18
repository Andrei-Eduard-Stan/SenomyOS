import QtQuick
import Quickshell
import "../config" as Config

// One instrument, with the original Island's two structural edge planes.
// Atmosphere is backed by an opaque contour; the reading plane never reveals apps.
ShellSurfaceFrame {
    id: root
    property real readingStart: 84
    contentInset: 28
    perimeterInset: 1
    perimeterCorner: 24
    backdropColor: Qt.rgba(Config.DirectoryStyle.glass.r,Config.DirectoryStyle.glass.g,Config.DirectoryStyle.glass.b,1)
    stateColor: "transparent"
    backgroundItem.visible: false
    Image {
        parent: root; z: -1
        x:14;y:14;width:Math.max(1,root.width-28);height:Math.max(1,root.height-28)
        source:"file://"+Quickshell.shellDir+"/../../appearance/assets/backgrounds/sen_expandedisland_bg0.5x.png"
        sourceSize:Qt.size(Math.ceil(width*2),Math.ceil(height*2))
        fillMode:Image.PreserveAspectCrop
        opacity:Config.DirectoryStyle.highContrast?0:0.52
        asynchronous:true
    }
    Rectangle {
        parent:root;z:-0.5
        x:root.contentInset-5;y:root.readingStart
        width:Math.max(1,root.width-2*x);height:Math.max(0,root.height-y-root.contentInset+5)
        color:Qt.rgba(Config.DirectoryStyle.glass.r,Config.DirectoryStyle.glass.g,Config.DirectoryStyle.glass.b,0.98)
    }
    SurfaceOutline {
        parent:root;z:0
        anchors.fill:parent;anchors.margins:11
        cornerExtent:18
        ruleColor:Qt.rgba(Config.DirectoryStyle.ink.r,Config.DirectoryStyle.ink.g,Config.DirectoryStyle.ink.b,0.2)
        opacity:0.4
    }
}
