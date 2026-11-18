import QtQuick
import Quickshell
import Quickshell.Wayland
import "../config" as Config

PanelWindow {
    id:root
    required property var targetScreen
    required property var inventory
    screen:targetScreen
    readonly property var actions:inventory?inventory.displayActions:null
    visible:!!actions&&!!actions.token&&["revert-pending","failed","keeping","reverting","acknowledging"].indexOf(actions.actionState)>=0
    anchors.top:true
    margins.top:24
    implicitWidth:Math.max(240,Math.min(520,targetScreen?targetScreen.width-24:520))
    implicitHeight:actions&&actions.actionState==="failed"?300:170
    exclusionMode:ExclusionMode.Ignore
    exclusiveZone:0
    color:Config.Theme.glassRaised
    WlrLayershell.namespace:"senomy-display-recovery"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.OnDemand
    Column {
        anchors.fill:parent;anchors.margins:16;spacing:8
        Text {width:parent.width;text:root.actions?(root.actions.actionState==="failed"?"DISPLAY RECOVERY NEEDS REVIEW":"KEEP DISPLAY CHANGES? · "+root.actions.secondsRemaining+"s"):"";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:14;wrapMode:Text.WordWrap}
        Text {width:parent.width;text:root.actions?root.actions.message:"";color:Config.DirectoryStyle.muted;font.pixelSize:12;wrapMode:Text.WordWrap;textFormat:Text.PlainText;maximumLineCount:6;elide:Text.ElideRight}
        Row {width:parent.width;spacing:8
            DashboardButton {width:(parent.width-8)/2;text:"REVERT";enabled:root.actions&&["revert-pending","failed"].indexOf(root.actions.actionState)>=0;onClicked:root.actions.revert()}
            DashboardButton {width:(parent.width-8)/2;text:"KEEP CHANGES";enabled:root.actions&&root.actions.actionState==="revert-pending";onClicked:root.actions.keep()}
        }
        DashboardButton {visible:root.actions&&root.actions.actionState==="failed";width:parent.width;text:"USE CURRENT LAYOUT";detail:"I can see the screens · session only, does not save";onClicked:root.actions.acceptRecovery()}
    }
}
