import QtQuick
import QtQuick.Window
import Quickshell
import "components"
import "config" as Config
Window {
    id:test;visible:true;width:1120;height:72;color:"#080a0c"
    property int phaseChanges:0
    property int presentedFrames:0
    property bool measuring:false
    onFrameSwapped:if(measuring)presentedFrames++
    Connections {target:Config.ReflectionLight;function onPhaseChanged(){if(test.measuring)test.phaseChanges++;}}
    Row {
        spacing:12
        Repeater {id:frames;model:10;SilverIslandFrame {width:90;height:56;hovered:Quickshell.env("SENOMY_SHEEN_MODE")==="engaged"}}
    }
    Timer {interval:1000;running:true;onTriggered:{test.measuring=true;finish.start();}}
    Timer {id:finish;interval:5000;onTriggered:{
        console.log("RESULT "+JSON.stringify({durationMs:5000,mode:Quickshell.env("SENOMY_SHEEN_MODE")||"idle",activeClients:Config.ReflectionLight.activeClients,phaseChanges:test.phaseChanges,presentedFrames:test.presentedFrames}));Qt.quit();
    }}
}
