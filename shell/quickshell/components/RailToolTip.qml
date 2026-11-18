import QtQuick
import QtQuick.Window
import Quickshell
import "../config" as Config

// Non-interactive, non-primary help. No focus grab and no provider actions.
PopupWindow {
    id:root
    property var anchorItem:null
    property bool hovered:false
    property bool suppressed:false
    property string text:""
    property bool shown:false
    readonly property bool requested:hovered && !suppressed && text.length>0 && !!anchorItem && anchorItem.visible && !!anchorItem.Window.window && anchorItem.Window.window.visible
    onRequestedChanged:{if(requested)delay.restart();else{delay.stop();shown=false;}}
    Timer {id:delay;interval:450;onTriggered:root.shown=root.requested}
    anchor.item:anchorItem
    anchor.edges:Edges.Top | Edges.Right
    anchor.gravity:Edges.Top | Edges.Left
    anchor.rect.y:-8
    implicitWidth:Math.max(1,Math.min(320,anchorItem?anchorItem.Screen.width-24:320))
    implicitHeight:label.implicitHeight+20
    color:"transparent"
    visible:shown && requested
    grabFocus:false
    mask:Region {}
    Rectangle {
        anchors.fill:parent;color:"#080a0c";border.width:1;border.color:Config.DirectoryStyle.rule
        Text {
            id:label;x:12;y:10;width:parent.width-24
            text:root.text.slice(0,320);textFormat:Text.PlainText;wrapMode:Text.WordWrap
            font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink
        }
    }
}
