import QtQuick
import Quickshell
import Quickshell.Wayland
import "../config" as Config

PanelWindow {
    id:root
    required property var targetScreen
    required property var inventory
    screen:targetScreen
    visible:!!inventory&&inventory.identifying
    implicitWidth:Math.min(360,targetScreen?targetScreen.width-24:360)
    implicitHeight:210
    exclusionMode:ExclusionMode.Ignore
    exclusiveZone:0
    color:Config.Theme.glassRaised
    WlrLayershell.namespace:"senomy-display-identify"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
    readonly property var display:inventory?inventory.displays.find(d=>d.name===(targetScreen?targetScreen.name:"")):null
    readonly property string identifiedName:display&&display.mirrorOf&&display.mirrorOf!=="none"?display.mirrorOf:targetScreen?targetScreen.name:""
    Column {
        anchors.fill:parent;anchors.margins:16;spacing:10
        Text {width:parent.width;text:"MONITOR "+root.inventory.numberFor(root.identifiedName);font.family:Config.DirectoryStyle.headingFont;font.pixelSize:40;color:Config.DirectoryStyle.ink;horizontalAlignment:Text.AlignHCenter}
        Text {width:parent.width;text:root.display?(root.display.friendlyName+" · "+root.display.name):root.identifiedName;wrapMode:Text.WordWrap;font.pixelSize:12;color:Config.DirectoryStyle.muted;horizontalAlignment:Text.AlignHCenter;textFormat:Text.PlainText}
        DashboardButton {width:parent.width;text:"DISMISS ALL";onClicked:root.inventory.dismissIdentify()}
    }
}
