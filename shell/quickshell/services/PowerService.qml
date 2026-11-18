import QtQuick
import Quickshell
import Quickshell.Io

// One observable commitment for Session, notification surfaces and every Rail.
// The supervised worker publishes authoritative remaining time into this receipt.
Scope {
    id:root
    readonly property var allowedActions:["lock","suspend","logout","reboot","poweroff"]
    property string helper:Quickshell.shellDir+"/scripts/session-scheduler.py"
    readonly property string actionTool:String(Quickshell.env("SENOMY_SESSION_ACTION")||"")
    property bool active:false
    property bool receiptReady:false
    property bool available:false
    property bool schedulingAvailable:false
    property string unavailableReason:"Checking this login…"
    property var capabilities:({})
    property var schedule:({})
    readonly property bool hasSchedule:["scheduled","running"].includes(schedule.state)
    readonly property real remainingSeconds: Math.max(0,Number(schedule.remainingSeconds || 0))
    readonly property real progress: Number(schedule.progress || 0)
    readonly property string urgency: schedule.urgency || "normal"
    readonly property string remainingText: formatRemaining(remainingSeconds)
    function formatRemaining(value){const n=Math.max(0,Math.ceil(value));return [Math.floor(n/3600),Math.floor(n%3600/60),n%60].map(v=>String(v).padStart(2,"0")).join(":");}
    function cancelSchedule(){if(busy||!["scheduled","missed","failed"].includes(schedule.state))return false;state="running";return begin("cancel",schedule.id);}
    function executeSchedule(){return prepare({action:schedule.action,mode:"now",executeId:schedule.id});}
    function postpone(seconds){if(busy||schedule.state!=="scheduled")return false;state="running";return begin("postpone",{id:schedule.id,seconds:seconds});}
    property string pendingAction:""
    property string pendingKind:""
    property var review:null
    property string state:"idle"
    property string error:""
    property string message:""
    property var fieldErrors:({})
    onScheduleChanged:if(schedule.state!=="scheduled")message=""
    property int generation:0
    readonly property bool busy:worker.running
    property var deferred:null
    signal prepared()
    function supported(action){return available&&capabilities[action]===true;}
    function refresh(){if(!reader.running){reader.serial=generation;reader.exec(["python3",helper,"status"]);}}
    function adopt(payload,skipSchedule){
        if(payload.schedule!==undefined&&!skipSchedule)schedule=payload.schedule;
        if(payload.capabilities!==undefined){capabilities=payload.capabilities;available=Object.values(capabilities).some(v=>v===true);schedulingAvailable=!!payload.schedulingAvailable;unavailableReason=payload.reason||"";}
    }
    function begin(operation,arg){
        if(worker.running)return false;
        worker.operation=operation;worker.serial=++generation;error="";message="";fieldErrors={};
        worker.exec(["python3",helper,operation,typeof arg==="string"?arg:JSON.stringify(arg)]);return true;
    }
    function request(action){return prepare({action:action,mode:"now"});}
    function prepare(form){
        if(busy||!supported(form.action))return false;
        pendingAction=form.action;pendingKind="action";review=null;state="pending";
        return begin("prepare",form);
    }
    function requestCancellation(){
        if(busy||!["scheduled","missed","failed"].includes(schedule.state))return false;
        ++generation;pendingAction=schedule.action;pendingKind="cancel";review={id:schedule.id,label:schedule.label,dueLabel:schedule.dueLabel};error="";fieldErrors={};state="pending";return true;
    }
    function cancel(){
        if(state!=="pending")return false;
        ++generation;review=null;pendingKind="";pendingAction="";state="idle";error="";fieldErrors={};return true;
    }
    function confirm(){
        if(state!=="pending"||!review||busy)return false;
        const op=pendingKind==="cancel"?"cancel":"commit";const id=review.id;
        state="running";return begin(op,id);
    }
    function clearFeedback(){if(state!=="pending"&&state!=="running"){state="idle";error="";fieldErrors={};message="";}}
    Component.onCompleted:refresh()
    onActiveChanged:if(active)refresh()
    Timer {interval:5000;repeat:true;running:root.active;onTriggered:root.refresh()}
    FileView {
        id:receipt
        path:root.receiptReady?String(Quickshell.env("XDG_RUNTIME_DIR")||"")+"/senomyos/session-schedule.json":""
        watchChanges:true;printErrors:false
        onFileChanged:reload()
        onLoaded:{try{root.schedule=JSON.parse(text());}catch(_){root.error="The schedule receipt could not be read. Reopen Session to verify its state.";}}
    }
    Process {
        id:reader
        property int serial:0
        stdout:StdioCollector {id:statusOutput}
        onExited:(code,status)=>{
            if(serial!==root.generation)return;
            try{const payload=JSON.parse(statusOutput.text);if(payload.ok){root.adopt(payload,root.receiptReady);root.receiptReady=true;receipt.reload();}else{root.available=false;root.schedulingAvailable=false;root.unavailableReason=payload.error||"Session status unavailable.";}}
            catch(_){root.available=false;root.schedulingAvailable=false;root.unavailableReason="Session status unavailable. Existing timers are not cancelled.";}
        }
    }
    Process {
        id:worker
        property string operation:""
        property int serial:0
        stdout:StdioCollector {id:actionOutput}
        onExited:(code,status)=>{
            if(serial!==root.generation)return;
            let payload;try{payload=JSON.parse(actionOutput.text);}catch(_){payload={ok:false,error:"The result could not be verified. Refresh before retrying."};}
            if(payload.ok){
                if(operation==="prepare"){root.review=payload.review;root.state="pending";root.prepared();}
                else{root.adopt(payload,root.receiptReady);receipt.reload();root.state="succeeded";root.message=payload.message||"Request accepted.";root.pendingKind="";root.pendingAction="";root.review=null;root.refresh();}
            }else{root.state="failed";root.error=payload.error||"Session action failed.";root.fieldErrors=payload.fieldErrors||{};root.review=null;root.refresh();}
        }
    }
}
