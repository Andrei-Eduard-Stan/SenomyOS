import QtQuick
QtObject {
    id:root
    required property var runner
    required property string helper
    property bool active:false
    property bool blocked:false
    property string context:""
    property var items:[]
    property var pending:null
    property string actionState:"idle"
    property string title:""
    property string impact:""
    property string message:""
    readonly property bool locked:actionState==="pending"||actionState==="running"
    signal refreshRequested()
    function allowed(verb,item){return item && item.mutable && (verb==="forget"?!item.active:verb==="disconnect"?item.active:verb==="autoconnect");}
    function request(verb,item){
        if(!active||!context||blocked||locked||!allowed(verb,item)||!items.some(row=>row.uuid===item.uuid&&row.token===item.token))return false;
        pending={verb:verb,uuid:item.uuid,token:item.token,context:context};
        title=(verb==="forget"?"Forget ":verb==="disconnect"?"Disconnect ":"Change autoconnect for ")+item.name+"?";
        impact=verb==="forget"?"Deletes this inactive saved profile and its saved authentication. You will need its settings and credentials to reconnect.":verb==="disconnect"?"Calls, downloads and remote sessions through this profile may stop.":"Changes whether this profile is eligible for automatic connection. Current connectivity is not changed by this request.";
        actionState="pending";message="";return true;
    }
    function cancel(){if(actionState==="running")return false;pending=null;actionState="idle";message="";return true;}
    function confirm(){
        if(actionState!=="pending"||!pending||!active||!context||pending.context!==context||blocked||runner.running)return false;
        if(!items.some(row=>allowed(pending.verb,row)&&row.uuid===pending.uuid&&row.token===pending.token)){
            pending=null;actionState="failed";message="Profile changed. Review it again; nothing was changed.";return false;
        }
        actionState="running";message="Requesting profile change and observing its result…";
        runner.exec(["python3",helper,"apply-confirmed",pending.verb,pending.uuid,pending.token]);return true;
    }
    function completed(code,output){
        pending=null;
        try{const parsed=JSON.parse(output);actionState=code===0&&parsed.ok?parsed.data.state:"failed";message=parsed.ok?parsed.data.message:(parsed.error||{}).message||"Profile request failed.";}
        catch(_){actionState="failed";message="Invalid profile result. Refresh and verify before retrying.";}
        refreshRequested();
    }
    onContextChanged:if(actionState==="pending")cancel()
    onActiveChanged:if(!active&&actionState==="pending")cancel()
}
