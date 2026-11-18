import QtQuick

QtObject {
    id: root
    required property var provider
    property string context: ""
    property string actionState: "idle"
    property var proposed: null
    property var previous: null
    property string actionKind: "topology"
    property string token: ""
    property double deadline: 0
    property double now: Date.now()
    property string message: ""
    readonly property bool locked: ["applying","revert-pending","keeping","persisting","reverting","running","acknowledging"].indexOf(actionState)>=0
    readonly property int secondsRemaining: Math.max(0,Math.ceil((deadline-now)/1000))
    function requestTopology(outputs,digest,primary,policyPatch,workspaceTargets) {
        if(locked||token)return false;
        if(!context)return fail("Open Displays before requesting a change.");
        proposed={outputs:JSON.parse(JSON.stringify(outputs)),baseDigest:digest,primary:primary||"",policyPatch:policyPatch||{},workspaceTargets:workspaceTargets||{}};
        actionKind="topology";actionState="pending";message="Review all affected displays. Outputs being disabled or mirrored will move their workspaces to a surviving display.";return true;
    }
    function requestOperation(operation,argument,description) {
        if(locked||token)return false;
        proposed={operation:operation,argument:JSON.parse(JSON.stringify(argument))};
        actionKind="operation";actionState="pending";message=description;return true;
    }
    function cancel(){if(actionState!=="pending")return false;reset();return true;}
    function confirm(){
        if(actionState!=="pending")return false;
        actionState=actionKind==="topology"?"applying":"running";
        const started=actionKind==="topology"?provider.runDisplayOperation("apply-topology",JSON.stringify(proposed))
            :provider.runDisplayOperation(proposed.operation,JSON.stringify(proposed.argument));
        if(!started)return fail("Another operation is in progress.");return true;
    }
    function applied(nextToken,nextDeadline){token=nextToken;deadline=nextDeadline;actionState="revert-pending";message="Keep changes only if your displays are usable.";}
    function keep(){if(actionState!=="revert-pending")return false;actionState="keeping";if(!provider.runDisplayOperation("keep",token))return fail("Could not confirm; recovery remains armed.");return true;}
    function persist(){return keep();}
    function acceptRecovery(){if(actionState!=="failed"||!token)return false;actionState="acknowledging";if(!provider.runDisplayOperation("accept-recovery",token))return fail("Could not acknowledge recovery.");return true;}
    function revert(){if(!token)return false;actionState="reverting";if(!provider.runDisplayOperation("revert",token))return fail("Recovery request could not start; independent recovery remains armed.");return true;}
    function completed(kind,text){actionState=kind;message=text||"Operation verified.";token="";deadline=0;}
    function fail(reason){actionState="failed";message=reason;return false;}
    function reset(){actionState="idle";proposed=null;previous=null;token="";deadline=0;message="";}
    function observe(state){
        if(!state)return;
        if(state.state==="recovery-failed"){
            token=state.token||token;actionState="failed";message=state.message||"Automatic recovery failed; retry Revert.";return;
        }
        if(state.state==="preview"&&state.token){
            if(["keeping","reverting","persisting"].indexOf(actionState)>=0||(actionState==="failed"&&token))return;
            token=state.token;deadline=state.deadline;actionState="revert-pending";message=state.message||"Keep or revert this preview.";
        }else if(["reverted","committed","abandoned","recovered-safe"].indexOf(state.state)>=0&&token&&(state.token===token||state.state==="abandoned"&&!state.token)){
            completed(state.state,state.message||state.state);
        }
    }
    onContextChanged: if(actionState==="pending")cancel()
    property Timer countdown: Timer {interval:250;repeat:true;running:root.actionState==="revert-pending";onTriggered:root.now=Date.now()}
}
