import QtQuick
import QtQuick.Window
import "../config" as Config
import "DirectoryFreshness.js" as Freshness
Text {
    id:root
    property string source:""
    property double observedAt:0
    onObservedAtChanged: now=Date.now()
    property double staleAfter:10000
    property bool cached:false
    property double now:Date.now()
    onVisibleChanged: if(visible) now=Date.now()
    Connections {target:root.Window.window;function onVisibleChanged(){if(root.Window.window.visible)root.now=Date.now();}}
    text:source+" // "+Freshness.describe(observedAt,now,staleAfter,cached)
    color:text.includes("STALE") || text.includes("UNAVAILABLE")?Config.Theme.warning:Config.DirectoryStyle.muted
    font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;wrapMode:Text.WordWrap
    Timer {interval:1000;running:root.visible;repeat:true;triggeredOnStart:true;onTriggered:root.now=Date.now()}
}
