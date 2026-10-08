import QtQuick
import Quickshell
import Quickshell.Io
Scope {
    id:root
    property bool active:false
    property string context:""
    property bool blocked:false
    property bool queryEnabled:true
    property var items:[]
    property bool available:false
    property bool editorAvailable:false
    property bool authenticationAvailable:false
    property bool loading:false
    property string error:""
    property string message:""
    property alias actions:reviews
    readonly property bool busy:blocked||loading||editor.running||reviews.locked
    readonly property string helper:Qt.resolvedUrl("../scripts/network-profiles.py").toString().replace("file://","")
    ProfileActions {id:reviews;runner:actionProcess;helper:root.helper;active:root.active;context:root.context;blocked:root.blocked;items:root.items;onRefreshRequested:root.refresh()}
    function refresh(){if(active&&queryEnabled&&!query.running){loading=true;query.exec(["python3",helper,"catalog"]);}}
    function openEditor(mode,uuid){
        if(!active||!context||busy||blocked||!editorAvailable||["all","vpn","edit"].indexOf(mode)<0)return false;
        if(mode==="edit"&&!items.some(item=>item.uuid===uuid))return false;
        editor.exec(mode==="edit"?["python3",helper,"open-editor",mode,uuid]:["python3",helper,"open-editor",mode]);return true;
    }
    onActiveChanged:if(active)refresh()
    Process {
        id:query;stdout:StdioCollector{id:output}
        onExited:code=>{
            root.loading=false;
            try{const parsed=JSON.parse(output.text);root.available=code===0&&parsed.ok;root.items=root.available?parsed.data.items:[];root.editorAvailable=root.available&&parsed.data.editorAvailable;root.authenticationAvailable=root.available&&parsed.data.authenticationAvailable;root.error=parsed.ok?"":(parsed.error||{}).message||"Profile inventory unavailable.";root.message=parsed.ok?parsed.data.message:"";}
            catch(_){root.available=false;root.editorAvailable=false;root.authenticationAvailable=false;root.items=[];root.error="Profile inventory returned invalid data.";}
        }
    }
    Process {id:actionProcess;stdout:StdioCollector{id:actionOutput} onExited:code=>reviews.completed(code,actionOutput.text)}
    Process {
        id:editor;stdout:StdioCollector{id:editorOutput}
        onExited:code=>{
            try{const parsed=JSON.parse(editorOutput.text);root.message=code===0&&parsed.ok?parsed.data.message:(parsed.error||{}).message||"Native editor launch failed.";}
            catch(_){root.message="Native editor launch returned invalid data.";}
        }
    }
}
