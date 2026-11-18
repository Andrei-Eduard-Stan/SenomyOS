import QtQuick
QtObject {
    id:root
    required property var runner
    required property string helper
    property string interpreter:"python3"
    property bool active:false
    property string context:""
    property var defaults:[]
    property var apps:[]
    property var autostart:[]
    property var deployment:({})
    property var pending:null
    property string actionState:"idle"
    property string title:""
    property string impact:""
    property string message:""
    readonly property bool locked:actionState==="pending"||actionState==="running"
    signal refreshRequested()
    function plan(kind,key,value){
        if(kind==="default"){
            const role=defaults.find(item=>item.mime===key);
            const option=role && role.options.find(item=>item.id===value);
            return option?{args:["default-confirmed",key,value,role.token],token:role.token,title:"Use "+option.name+" for "+role.label+"?",impact:"Changes this MIME default. No application or file will be opened."}:null;
        }
        if(kind==="autostart"){
            const item=autostart.find(item=>item.id===key);
            return item&&!item.protected&&["yes","no"].indexOf(value)>=0?{args:["autostart-confirmed",key,value,item.token],token:item.token,title:(value==="yes"?"Enable ":"Disable ")+item.name+" at login?",impact:"Saves a user override and preserves the entry's other settings. Existing user entries are backed up. Changes apply at a future XDG autostart login; running applications are not changed."}:null;
        }
        if(kind==="add-autostart"){
            const item=apps.find(item=>item.id===key&&item.autostartAllowed);
            return item&&!autostart.some(entry=>entry.id===key)?{args:["add-autostart-confirmed",key,item.token],token:item.token,title:"Start "+item.name+" at future login?",impact:"Copies this installed application's desktop registration to user autostart. Nothing is launched now. Future startup depends on XDG autostart deployment and session eligibility."}:null;
        }
        if(kind==="enable-autostart" && deployment.supported && !deployment.enabled)return {args:["enable-autostart-confirmed",deployment.token],token:deployment.token,title:"Enable future XDG autostart?",impact:"Adds the packaged autostart target to future graphical user-manager sessions. Existing eligible entries may launch at the next fresh login. No live service or application is started; fresh user-manager/login acceptance is required."};
        return null;
    }
    function request(kind,key,value){
        if(!active||!context||locked||runner.running)return false;
        const preview=plan(kind,key,value);if(!preview)return false;
        pending={kind:kind,key:key,value:value,token:preview.token,context:context};title=preview.title;impact=preview.impact;message="";actionState="pending";return true;
    }
    function cancel(){if(actionState==="running")return false;pending=null;actionState="idle";message="";return true;}
    function confirm(){
        if(actionState!=="pending"||!pending||!active||!context||pending.context!==context||runner.running)return false;
        const preview=plan(pending.kind,pending.key,pending.value);
        if(!preview||preview.token!==pending.token){pending=null;actionState="failed";message="Desktop settings changed. Review them again; nothing was saved.";return false;}
        actionState="running";message="Saving the reviewed desktop preference…";runner.exec([interpreter,helper].concat(preview.args));return true;
    }
    function completed(code,output){pending=null;try{const parsed=JSON.parse(output);if(code===0&&parsed.ok===true&&parsed.data){actionState=parsed.data.state;message=parsed.data.message;}else{actionState=parsed.ok===true?"unverified":"failed";message=parsed.ok===true?"Desktop preference result could not be verified. Refresh actual settings before retrying.":(parsed.error||{}).message||"Desktop preference failed.";}}catch(_){actionState="unverified";message="Invalid preference result. Refresh to verify current settings.";}refreshRequested();}
    property Timer startupCheck:Timer {
        interval:200;running:root.actionState==="running"&&!root.runner.running
        onTriggered:{root.pending=null;root.actionState="failed";root.message="Desktop preference helper could not start. No request was submitted; check Python and review again.";}
    }
    onContextChanged:if(actionState==="pending")cancel()
    onActiveChanged:if(!active&&actionState==="pending")cancel()
}
