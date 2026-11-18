import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id:root
    property bool active:false
    property string context:""
    property string interpreter:"python3"
    property string helper:Quickshell.shellDir+"/scripts/account-settings.py"
    property var snapshot:({available:false,complete:false,currentUid:-1,accounts:[],passwordAvailable:false,message:"Account inventory not loaded"})
    readonly property var accounts:snapshot.accounts || []
    readonly property bool available:snapshot.available===true
    property bool loading:false
    readonly property bool locked:actionState==="pending" || actionState==="running" || writePending
    property string actionState:"idle"
    property string message:""
    property string operation:""
    property string proposed:""
    property var target:null
    property string requestContext:""
    property string requestInventory:""
    property string requestProvider:""
    property double observedAt:-1
    property bool complete:false
    property bool starting:false
    property bool readerStarted:false
    property bool writePending:false
    property bool writerStarted:false
    property int failures:0
    property int retryBaseMs:1000
    property int retryLimit:5
    function unavailable(reason){snapshot=Object.assign({},snapshot,{available:false,complete:false,providerIdentity:"",message:reason});loading=false;}
    function adopt(next){
        if(!next || !Array.isArray(next.accounts) || !Number.isFinite(next.observedAtMs))return false;
        if(next.observedAtMs<observedAt)return true; // late status must not overwrite newer authoritative readback
        observedAt=next.observedAtMs;snapshot=next;loading=false;
        if(actionState==="pending" && (requestProvider!==snapshot.providerIdentity || target && !accounts.some(a=>a.uid===target.uid&&a.token===target.token) || operation==="create"&&snapshot.token!==requestInventory)){
            actionState="failed";message="Account provider, target or inventory changed. Nothing was submitted; review it again.";
        }
        return true;
    }
    function start(){if(!active||starting||reader.running)return false;starting=true;readerStarted=false;loading=true;reader.exec([interpreter,helper,"watch"]);return true;}
    function stopped(reason){starting=false;if(!active){loading=false;return;}unavailable(reason);if(++failures<=retryLimit)retry.restart();}
    function refresh(){if(!active)return false;if(reader.running){loading=true;reader.write("refresh\n");return true;}retry.stop();failures=0;return start();}
    function request(kind,account,value){
        if(!active || !context || locked || loading || ["create","remove","name","avatar","lock","type","password","setup"].indexOf(kind)<0)return false;
        if(kind!=="password" && kind!=="setup" && !available)return false;
        operation=kind;target=account?JSON.parse(JSON.stringify(account)):null;proposed=String(value || "");requestContext=context;requestInventory=snapshot.token||"";requestProvider=snapshot.providerIdentity||"";
        message=kind==="setup"?"Open a terminal to review installation of the official AccountsService package. sudo owns authorization. This does not create users, change passwords or restart login.":kind==="remove"?"Remove the account while retaining its home files. Signed-in accounts and the last viable administrator are protected.":kind==="password"?"Open passwd in a secure terminal. Enter passwords only there. Password-change success must be checked there.":kind==="create"?"Create a standard account through AccountsService. Password setup remains a separate secure system workflow.":"Apply through AccountsService. System authentication is followed by fresh target/session/administrator checks.";
        actionState="pending";return true;
    }
    function cancel(){if(actionState==="running")return false;actionState="idle";target=null;operation="";message="";return true;}
    function confirm(){
        if(!active || !context || context!==requestContext || actionState!=="pending" || writer.running || writePending)return false;
        const current=target?accounts.find(a=>a.uid===target.uid):null;
        if(requestProvider!==(snapshot.providerIdentity||"") || target && (!current || current.token!==target.token) || operation==="create"&&requestInventory!==snapshot.token){actionState="failed";message="Account state changed. Review it again.";return false;}
        actionState="running";writePending=true;writerStarted=false;
        writer.exec([interpreter,helper,"apply",operation,target?String(target.uid):"-1",proposed,target?target.token:operation==="create"?requestInventory:"","--confirmed"]);return true;
    }
    onContextChanged:if(actionState==="pending")cancel()
    onActiveChanged:{if(!complete)return;retry.stop();if(!active){if(actionState==="pending")cancel();reader.running=false;starting=false;loading=false;}else start();}
    Component.onCompleted:{complete=true;if(active)start();}
    Timer {id:retry;interval:Math.min(30000,root.retryBaseMs*Math.pow(2,Math.max(0,root.failures-1)));onTriggered:root.start()}
    Timer {interval:10000;running:reader.running&&root.available;onTriggered:root.failures=0}
    Timer {interval:200;running:root.starting&&!root.readerStarted&&!reader.running;onTriggered:root.stopped("Account inventory helper could not start. Check Python and refresh accounts.")}
    Timer {interval:200;running:root.writePending&&!root.writerStarted&&!writer.running;onTriggered:{root.writePending=false;root.actionState="failed";root.message="Account helper could not start. No account request was submitted; check Python and refresh.";}}
    Process {
        id:reader;stdinEnabled:true
        onStarted:{root.readerStarted=true;root.starting=false;if(!root.active)running=false;}
        stdout:SplitParser {onRead:data=>{try{if(!root.adopt(JSON.parse(data)))root.unavailable("Invalid account inventory; refresh before reviewing a change.");}catch(e){root.unavailable("Account inventory unavailable; refresh to retry.");}}}
        onExited:root.stopped("Account subscription ended. Automatic retries are bounded; Refresh accounts retries it.")
    }
    Process {
        id:writer
        onStarted:root.writerStarted=true
        stdout:StdioCollector {id:writeOutput}
        onExited:(code,status)=>{
            root.writePending=false;
            try{
                const result=JSON.parse(writeOutput.text);
                if(code===0 && result.ok===true && ["succeeded","handed-off"].includes(result.state))root.actionState=result.state;
                else root.actionState=result.ok===true?"unverified":["denied","cancelled","unverified","failed"].includes(result.state)?result.state:"failed";
                root.message=code!==0&&result.ok===true?"Account helper exited unsuccessfully. Inspect current state before retrying.":result.message||"Account result unavailable";
                if(result.snapshot)root.adopt(result.snapshot);
            }catch(e){root.actionState="unverified";root.message="Account request ended without a verified receipt. It may have completed; refresh actual state before retrying.";}
            root.refresh();
        }
    }
}
