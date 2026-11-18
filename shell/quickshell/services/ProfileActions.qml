import QtQuick
QtObject {
    id:root
    required property var runner
    required property string helper
    property string interpreter:"python3"
    property bool providerAvailable:true
    property string providerIdentity:""
    property string operationIdentity:""
    property bool runnerStarted:false
    property bool submitted:false
    property bool awaitingActivation:false
    property double deadline:0
    property int activationTimeoutMs:90000
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
    function allowed(verb,item){return item && item.mutable && (verb==="forget"?!item.active:verb==="disconnect"?item.active:verb==="connect"?!item.active:verb==="autoconnect");}
    function request(verb,item){
        if(!active||!context||!providerAvailable||blocked||locked||runner.running||!allowed(verb,item)||!items.some(row=>row.uuid===item.uuid&&row.token===item.token))return false;
        pending={verb:verb,uuid:item.uuid,token:item.token,context:context,providerIdentity:providerIdentity};
        title=(verb==="forget"?"Forget ":verb==="disconnect"?"Disconnect ":verb==="connect"?"Connect ":"Change autoconnect for ")+item.name+"?";
        impact=verb==="connect"?"Activate this saved NetworkManager profile using its own settings. It may replace routes/DNS or interrupt the current connection. Credentials stay in the native authentication terminal; activation and internet access are separate results.":verb==="forget"?"Deletes this inactive saved profile and its saved authentication. You will need its settings and credentials to reconnect.":verb==="disconnect"?"Calls, downloads and remote sessions through this profile may stop.":"Changes whether this profile is eligible for automatic connection. Current connectivity is not changed by this request.";
        actionState="pending";message="";return true;
    }
    function cancel(){if(actionState==="running")return false;pending=null;submitted=false;awaitingActivation=false;actionState="idle";message="";return true;}
    function confirm(){
        if(actionState!=="pending"||!pending||!active||!context||pending.context!==context||pending.providerIdentity!==providerIdentity||!providerAvailable||blocked||runner.running)return false;
        if(!items.some(row=>allowed(pending.verb,row)&&row.uuid===pending.uuid&&row.token===pending.token)){
            pending=null;actionState="failed";message="Profile changed. Review it again; nothing was changed.";return false;
        }
        actionState="running";message="Requesting profile change and observing its result…";
        runnerStarted=false;submitted=true;awaitingActivation=false;operationIdentity=providerIdentity;
        runner.exec([interpreter,helper,"apply-confirmed",pending.verb,pending.uuid,pending.token]);return true;
    }
    function completed(code,output){
        if(submitted&&actionState!=="running"){submitted=false;refreshRequested();return;}
        if(submitted&&operationIdentity!==providerIdentity){fail("NetworkManager changed; completion could not be verified.");refreshRequested();return;}
        try{
            const parsed=JSON.parse(output);
            if(code===0&&parsed.ok&&parsed.data.state==="awaiting-activation"){
                awaitingActivation=true;deadline=Date.now()+activationTimeoutMs;message=parsed.data.message;observeActivation();
            }else{pending=null;submitted=false;actionState=code===0&&parsed.ok?parsed.data.state:"failed";message=code===0&&parsed.ok?parsed.data.message:(parsed.error||{}).message||"Profile request failed; inspect current state before retrying.";}
        }catch(_){fail("Invalid profile result. Refresh and verify before retrying.");}
        refreshRequested();
    }
    function fail(reason){pending=null;awaitingActivation=false;actionState="failed";message=reason;return false;}
    function observeActivation(){
        if(!awaitingActivation||actionState!=="running")return;
        if(!providerAvailable||operationIdentity!==providerIdentity){fail("NetworkManager changed; activation could not be verified.");return;}
        if(!items.some(row=>row.uuid===pending.uuid)){fail("The saved profile disappeared; activation could not be verified. Check the authentication terminal before retrying.");return;}
        if(items.some(row=>row.uuid===pending.uuid&&row.active)){
            pending=null;submitted=false;awaitingActivation=false;actionState="succeeded";
            message="NetworkManager reports this profile active. Internet reachability is reported separately.";
        }else if(Date.now()>=deadline){pending=null;submitted=false;awaitingActivation=false;actionState="unverified";message="Activation was not observed in time. Check the authentication terminal and current state; the request may still finish. No automatic retry was submitted.";}
    }
    onItemsChanged:observeActivation()
    onProviderIdentityChanged:{if(actionState==="pending")cancel();else if(actionState==="running")fail("NetworkManager changed; completion could not be verified.");}
    onProviderAvailableChanged:if(!providerAvailable){if(actionState==="pending")cancel();else if(actionState==="running")fail("NetworkManager is unavailable; completion could not be verified.");}
    property Timer startup:Timer {interval:200;running:root.actionState==="running"&&!root.awaitingActivation&&!root.runnerStarted&&!root.runner.running;onTriggered:root.fail("Profile adapter could not start. No request was submitted; check Python and refresh.")}
    property Timer observer:Timer {interval:250;repeat:true;running:root.awaitingActivation;onTriggered:root.observeActivation()}
    onContextChanged:if(actionState==="pending")cancel()
    onActiveChanged:if(!active&&actionState==="pending")cancel()
}
