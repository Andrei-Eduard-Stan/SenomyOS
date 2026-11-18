import QtQuick
import Quickshell
import Quickshell.Io
import "../config" as Config
Column {
    id:root
    property string provider:""
    property string label:""
    property bool pending:false
    property var runner:terminal
    readonly property bool busy:!!runner && runner.running
    property string message:""
    readonly property bool supported:["accounts","idle"].includes(provider)
    function requestSetup(){if(!supported || busy || !visible)return false;pending=true;return true;}
    function confirmSetup(){
        if(!pending || !supported || busy || !visible || !runner)return false;
        pending=false;
        message="Starting setup terminal…";
        runner.exec(["python3","-B",Quickshell.shellDir+"/../../scripts/senomy_app_launch.py","tool","provider-setup",provider]);
        return true;
    }
    spacing:10
    onVisibleChanged:if(!visible)pending=false
    onProviderChanged:pending=false
    DashboardButton {width:Math.min(260,parent.width);text:"Set up "+root.label+"…";enabled:root.supported && !root.busy;onClicked:root.requestSetup()}
    Text {visible:root.pending;width:parent.width;text:"Open a terminal to review the official package installation. Enter authorization only there. Installation does not start the service or change your current session.";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;wrapMode:Text.WordWrap}
    Flow {
        visible:root.pending;width:parent.width;spacing:8
        DashboardButton {width:Math.min(150,parent.width);text:"Cancel";onClicked:root.pending=false}
        DashboardButton {width:Math.min(200,parent.width);text:"Open setup terminal";enabled:root.supported;onClicked:root.confirmSetup()}
    }
    Text {width:parent.width;visible:root.message.length>0;text:root.message;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WordWrap}
    Process {id:terminal;stdout:StdioCollector {id:launchReceipt}
        onExited:(code,status)=>{try{const result=JSON.parse(launchReceipt.text);root.message=code===0 && result.ok?"Setup handed to the terminal. Installation and activation are not yet verified. Refresh this page afterward.":result.message;}catch(_){root.message="Setup launch result unavailable. Check for the terminal before retrying.";}}}
}
