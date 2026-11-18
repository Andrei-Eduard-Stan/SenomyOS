import QtQuick
import Quickshell
import Quickshell.Io

// One transport implementation; the Python adapter is the authoritative scope
// boundary. Never replay a launch after reload or a missing/late receipt.
Scope {
    id:root
    property string state:"idle"
    property string message:""
    property var receipt:({})
    property bool receiptPending:false
    property bool launcherStarted:false
    property alias runner:process
    readonly property bool busy:process.running || receiptPending
    signal finished(bool accepted, string detail)
    function request(kind,target,args) {
        if(busy)return false;
        receiptPending=true;launcherStarted=false;root.receipt={};
        state="running";message="Starting application…";
        process.exec(["python3","-B",Quickshell.shellDir+"/../../scripts/senomy_app_launch.py",kind,target].concat(args||[]));
        return true;
    }
    function complete(result,accepted) {
        if(!receiptPending)return;
        receiptPending=false;root.receipt=result;
        state=result.state||"failed";message=result.message||"Application launch failed.";
        finished(accepted,message);
    }
    // Quickshell 0.3.1 does not emit exited when exec cannot start. Do not leave
    // Lens/Settings claiming progress or permit another click while unresolved.
    Timer {
        interval:150
        running:root.receiptPending && !root.launcherStarted && !process.running
        onTriggered:root.complete({ok:false,state:"failed",message:"The application launcher could not start. Check Python and the launcher installation; no application was launched."},false)
    }
    Process {
        id:process
        onStarted:root.launcherStarted=true
        stdout:StdioCollector {id:receipt}
        onExited:(code,status)=>{
            let result;try{result=JSON.parse(receipt.text);}catch(_){result={ok:false,state:"unverified",message:"The launch result was unavailable. Check the launcher installation and whether the application opened before retrying."};}
            root.complete(result,code===0 && result.ok===true);
        }
    }
}
