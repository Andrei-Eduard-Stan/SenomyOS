import QtQuick
import Quickshell
import Quickshell.Io
Scope {
    id:root
    property bool active:false
    property string context:""
    property bool blocked:false
    property bool queryEnabled:true
    property string interpreter:"python3"
    property string helper:Qt.resolvedUrl("../scripts/network-profiles.py").toString().replace("file://","")
    property var items:[]
    property var status:({})
    property bool available:false
    property bool providerAvailable:false
    property string providerIdentity:""
    property bool editorAvailable:false
    property bool authenticationAvailable:false
    property bool loading:false
    property string error:""
    property string message:""
    property bool complete:false
    property bool starting:false
    property bool started:false
    property int failures:0
    property int retryBaseMs:1000
    property int retryLimit:5
    property bool editorPending:false
    property bool editorStarted:false
    property alias actions:reviews
    readonly property bool busy:blocked||loading||editorPending||reviews.locked
    function unavailable(reason){available=false;providerAvailable=false;providerIdentity="";items=[];status=({});editorAvailable=false;authenticationAvailable=false;error=reason;loading=false;}
    function start(){
        if(!queryEnabled||starting||query.running)return false;
        starting=true;started=false;loading=true;query.exec([interpreter,helper,"watch"]);return true;
    }
    function stopped(reason){
        starting=false;unavailable(reason);
        if(queryEnabled&&++failures<=retryLimit)retry.restart();
    }
    function refresh(){
        if(!queryEnabled)return false;
        if(query.running){loading=true;query.write("refresh\n");return true;}
        retry.stop();failures=0;return start();
    }
    function adopt(parsed){
        if(parsed.ok!==true||!parsed.data||!Array.isArray(parsed.data.items)||!Array.isArray(parsed.data.devices)){
            unavailable((parsed.error||{}).message||"Network inventory unavailable. Refresh to retry.");return;
        }
        const data=parsed.data;
        providerIdentity=data.providerIdentity||"";providerAvailable=data.providerAvailable===true;
        available=providerAvailable&&data.available===true;items=available?data.items:[];status=data;
        editorAvailable=available&&data.editorAvailable===true;authenticationAvailable=available&&data.authenticationAvailable===true;
        error=available?"":data.message||"NetworkManager is unavailable.";message=data.message||"";loading=false;
    }
    ProfileActions {id:reviews;runner:actionProcess;helper:root.helper;interpreter:root.interpreter;active:root.active;context:root.context;blocked:root.blocked;items:root.items;providerAvailable:root.providerAvailable;providerIdentity:root.providerIdentity;onRefreshRequested:root.refresh()}
    function openEditor(mode,uuid){
        if(!active||!context||busy||blocked||!editorAvailable||["all","vpn","edit"].indexOf(mode)<0)return false;
        if(mode==="edit"&&!items.some(item=>item.uuid===uuid))return false;
        editorPending=true;editorStarted=false;
        editor.exec(mode==="edit"?[interpreter,helper,"open-editor",mode,uuid]:[interpreter,helper,"open-editor",mode]);return true;
    }
    onActiveChanged:if(active)refresh()
    onQueryEnabledChanged:{if(!complete)return;retry.stop();if(queryEnabled)start();else{query.running=false;starting=false;unavailable("Network observer disabled.");}}
    Component.onCompleted:{complete=true;if(queryEnabled)start();}
    Timer {id:retry;interval:Math.min(30000,root.retryBaseMs*Math.pow(2,Math.max(0,root.failures-1)));onTriggered:root.start()}
    Timer {interval:10000;running:query.running&&root.providerAvailable;onTriggered:root.failures=0}
    Timer {interval:200;running:root.starting&&!root.started&&!query.running;onTriggered:root.stopped("Network adapter could not start. Check Python/libnm and refresh to retry.")}
    Timer {interval:200;running:root.editorPending&&!root.editorStarted&&!editor.running;onTriggered:{root.editorPending=false;root.message="Network editor handoff could not start. Check Python and launcher dependencies.";}}
    Process {
        id:query;stdinEnabled:true
        stdout:SplitParser {onRead:data=>{try{root.adopt(JSON.parse(data));}catch(_){root.unavailable("Network inventory returned invalid data. Refresh to retry.");}}}
        onStarted:{root.started=true;root.starting=false;}
        onExited:root.stopped("Network inventory subscription ended. Automatic retries are bounded; Refresh retries it.")
    }
    Process {id:actionProcess;stdout:StdioCollector{id:actionOutput} onStarted:reviews.runnerStarted=true;onExited:code=>reviews.completed(code,actionOutput.text)}
    Process {
        id:editor;stdout:StdioCollector{id:editorOutput}
        onStarted:root.editorStarted=true
        onExited:code=>{
            root.editorPending=false;
            try{const parsed=JSON.parse(editorOutput.text);root.message=code===0&&parsed.ok?parsed.data.message:(parsed.error||{}).message||"Native editor launch failed.";}
            catch(_){root.message="Native editor launch returned invalid data.";}
        }
    }
}
