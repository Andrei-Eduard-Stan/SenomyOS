import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root
    property bool draftRestored:false
    property string draftPersistenceError:""
    property int projectionEpoch:0
    property var recoveryHealth:({enabled:false,needed:false,canAttempt:false,state:"disabled"})
    property string recoveryMessage:""
    property bool active: false
    property bool loading: false
    property var snapshot: ({})
    property string error: ""
    property string actionContext: ""
    property string displayOperation: ""
    property string interpreter:"python3"
    property bool queryPending:false
    property bool operationPending:false
    property bool draftSavePending:false
    property bool policyStarting:false
    property bool repairPending:false
    property int operationEpoch:0
    readonly property bool displayBusy:operationPending||repairPending||displayProcess.running||autoRepair.running
    property bool refreshPending: false
    property bool policyRestorePending: true
    property bool identifying: false
    property bool legacyDefaultsPending:false
    property var profiles: []
    property var savedLayout: ({status:"none"})
    property int selectedWorkspace:0
    property var policy: ({workspaceMode:"independent",workspaces:{},primary:"",rail:{}})
    property var workspaces: []
    property var windows: []
    property string digest: ""
    readonly property var displays: snapshot.displays && snapshot.displays.available ? snapshot.displays.items : []
    property alias displayActions: guardedDisplayActions
    property alias draft: editorDraft
    DisplayActions {id:guardedDisplayActions;provider:root;context:root.actionContext}
    DisplayDraft {id:editorDraft;displays:root.displays;observedDigest:root.digest;observedPrimary:root.policy.primary||""}
    readonly property string preferredScreen: {
        const chosen=displays.find(m=>m.key===policy.primary&&!m.disabled&&(!m.mirrorOf||m.mirrorOf==="none"));
        if(chosen)return chosen.name;
        const internal=displays.find(m=>!m.disabled&&/^eDP-|^DSI-|^LVDS-/.test(m.name));
        return internal?internal.name:(displays.find(m=>!m.disabled)||{}).name||"";
    }
    function numberFor(name){const d=displays.find(m=>m.name===name);return d?d.number:0;}
    function railVisible(name){const d=displays.find(m=>m.name===name);return !d||!policy.rail||policy.rail[d.key]!==false;}
    function workspaceLabel(id){const ws=workspaces.find(w=>w.id===id);return ws&&ws.displayLabel!==undefined?ws.displayLabel:(policy.workspaceMode==="independent"?"…":String(id));}
    function workspaceOrder(id){const r=(policy.workspaces||{})[String(id)];return r?r.order:Number(id);}
    function workspaceIndicatorVisible(id,name){const ws=workspaces.find(w=>w.id===id);return ws?ws.indicatorVisible===true:!!error&&/^(eDP|LVDS|DSI)-/.test(name||"");}
    function workspaceModuleVisible(name){return name===preferredWorkspaceScreen||(!displays.length&&/^(eDP|LVDS|DSI)-/.test(name))||policy.externalWorkspaceIndicators===true||workspaces.some(w=>w.monitor===name&&w.indicatorVisible);}
    readonly property string preferredWorkspaceScreen:{const home=displays.find(m=>m.key===policy.workspaceDefaultHome&&!m.disabled);return home?home.name:preferredScreen;}
    function focusWorkspace(id){return runDisplayOperation("workspace",JSON.stringify({action:"switch",id:id}));}
    function createWorkspace(name){return runDisplayOperation("workspace",JSON.stringify({action:"create",monitor:name}));}
    function planProjection(mode,source,externals){const argument={mode:mode,source:source||""};if(externals!==undefined)argument.externals=externals;return runDisplayOperation("projection-plan",JSON.stringify(argument));}
    function identify(){identifying=true;identifyTimer.restart();}
    function dismissIdentify(){identifying=false;identifyTimer.stop();}
    function refresh(force){
        if(!active&&force!==true)return;
        if(queryPending||query.running){refreshPending=true;return;}
        loading=true;queryPending=true;query.epoch=operationEpoch;
        query.exec([interpreter,Quickshell.shellDir+"/scripts/device-inventory.py"]);
    }
    function runDisplayOperation(operation,argument){
        if(displayBusy)return false;
        displayOperation=operation;operationPending=true;operationEpoch++;
        displayProcess.exec([interpreter,Quickshell.shellDir+"/scripts/display-action.py",operation,argument]);return true;
    }
    function requestWorkspace(argument,description){return guardedDisplayActions.requestOperation("workspace",argument,description);}
    onActiveChanged:if(active)refresh(true)
    Component.onCompleted:refresh(true)
    Process {
        id:query
        property int epoch:0
        stdout:StdioCollector {id:queryOutput}
        onExited:(code,status)=>{
            root.queryPending=false;root.loading=false;
            if(epoch!==root.operationEpoch)root.refreshPending=true;
            else {
                try{
                    if(code!==0)throw new Error("Inventory worker exited unsuccessfully");
                    const next=JSON.parse(queryOutput.text);
                    if(!next.displays||!next.inputs)throw new Error("Invalid inventory");
                    root.snapshot=next;
                    root.savedLayout=next.savedLayout||{status:"none"};
                    root.profiles=next.profiles||[];root.legacyDefaultsPending=next.legacyDefaultsPending===true;root.policy=next.policy||root.policy;
                    root.workspaces=next.workspaces||[];root.windows=next.windows||[];root.digest=next.digest||"";
                    guardedDisplayActions.observe(next.transaction);
                    root.recoveryHealth=next.recovery||{enabled:false,needed:false,canAttempt:false,state:"disabled"};
                    if(root.recoveryHealth.canAttempt&&root.policy.autoRecovery===true&&!guardedDisplayActions.locked&&guardedDisplayActions.actionState!=="pending"&&!displayProcess.running&&!autoRepair.running&&!repairTimer.running)repairTimer.start();
                    if(!root.draftRestored){if(next.editorDraft)editorDraft.restore(next.editorDraft);root.draftRestored=true;}
                    if(root.policyRestorePending&&!root.policyStarting&&!policyRestore.running&&!guardedDisplayActions.locked&&!root.displayBusy){root.policyStarting=true;policyRestore.exec([root.interpreter,Quickshell.shellDir+"/scripts/display-action.py","restore-policy"]);}
                    root.error=next.displays.available?"":next.displays.error||"Display inventory unavailable";
                }catch(e){root.error="Device inventory could not be read; edits are preserved. Detect again before applying.";}
            }
            if(root.refreshPending){root.refreshPending=false;refreshTimer.restart();}
        }
    }
    Process {
        id:displayProcess
        stdout:StdioCollector {id:operationOutput}
        onExited:(code,status)=>{
            root.operationPending=false;
            try{
                const result=JSON.parse(operationOutput.text);
                if(code!==0||result.ok!==true){guardedDisplayActions.fail(code!==0&&result.ok===true?"Display worker exited unsuccessfully; outcome unverified. Inspect actual state before retrying.":result.error||"Operation failed.");guardedDisplayActions.observe(result.transaction);}
                else if(result.state==="projection-plan"){editorDraft.stage(result);guardedDisplayActions.completed("idle",result.message);}
                else if(result.state==="preview")guardedDisplayActions.applied(result.token,result.deadline);
                else {guardedDisplayActions.completed(result.state||"succeeded",result.message);if((["keep","persist"].indexOf(root.displayOperation)>=0&&result.state==="committed")||(root.displayOperation==="revert"&&result.state==="reverted"))editorDraft.discard();}
                root.refresh(true);
            }catch(e){guardedDisplayActions.fail("Invalid operation response; independent recovery remains responsible for a pending preview.");root.refresh(true);}
        }
    }
    Connections {target:editorDraft;function onEditsChanged(){if(root.draftRestored)draftSaveTimer.restart();}}
    Timer {id:draftSaveTimer;interval:400;onTriggered:{if(root.draftSavePending||draftSave.running){restart();return;}root.draftSavePending=true;draftSave.exec([root.interpreter,Quickshell.shellDir+"/scripts/display-action.py","draft-save",JSON.stringify(editorDraft.exported())]);}}
    Process {id:draftSave;stdout:StdioCollector {id:draftOutput}
        onExited:(code,status)=>{root.draftSavePending=false;try{const result=JSON.parse(draftOutput.text);root.draftPersistenceError=code===0&&result.ok===true?"":result.error||"Draft could not be saved.";}catch(e){root.draftPersistenceError="Draft could not be saved for shell recovery.";}}}
    Connections {
        target:Hyprland
        function onRawEvent(event){
            if(event.name==="configreloaded")root.policyRestorePending=true;
            if(/^(monitor|workspace|createworkspace|destroyworkspace|moveworkspace|renameworkspace|focusedmon|openwindow|closewindow|movewindow|fullscreen|configreloaded)/.test(event.name))refreshTimer.restart();
        }
    }
    Process {
        id:policyRestore
        stdout:StdioCollector {id:policyOutput}
        onExited:(code,status)=>{
            root.policyStarting=false;
            try {const result=JSON.parse(policyOutput.text);root.policyRestorePending=code===0&&result.ok===true&&result.state==="policy-deferred";if(code===0&&result.ok===true&&!root.policyRestorePending)root.refresh(true);if(code!==0||result.ok!==true)root.error=result.error||"Saved workspace policy could not be restored. A configuration reload retries it.";}
            catch(e){root.policyRestorePending=false;root.error="Workspace policy restoration returned an invalid response.";}
        }
    }
    Timer {id:refreshTimer;interval:160;onTriggered:root.refresh(true)}
    Timer {interval:root.policy.autoRecovery===true?5000:10000;running:root.active||root.policy.autoRecovery===true;repeat:true;onTriggered:root.refresh(true)}
    Timer {
        id:repairTimer;interval:2200
        onTriggered:if(root.policy.autoRecovery===true&&root.recoveryHealth.canAttempt&&!root.displayBusy&&!guardedDisplayActions.locked&&guardedDisplayActions.actionState!=="pending"){root.repairPending=true;root.operationEpoch++;autoRepair.exec([root.interpreter,Quickshell.shellDir+"/scripts/display-action.py","auto-recover"]);}
    }
    Process {
        id:autoRepair
        stdout:StdioCollector {id:repairOutput}
        onExited:(code,status)=>{
            root.repairPending=false;
            try {const result=JSON.parse(repairOutput.text);root.recoveryMessage=code===0&&result.ok===true?result.message||"":result.error||"Automatic display recovery failed; inspect Diagnostics.";}
            catch(e){root.recoveryMessage="Automatic display recovery returned an invalid response; inspect Diagnostics.";}
            root.refresh(true);
        }
    }
    Timer {
        interval:200
        running:root.queryPending&&!query.running||root.operationPending&&!displayProcess.running||root.draftSavePending&&!draftSave.running||root.policyStarting&&!policyRestore.running||root.repairPending&&!autoRepair.running
        onTriggered:{
            if(root.queryPending&&!query.running){root.queryPending=false;root.loading=false;root.refreshPending=false;root.error="Device inventory helper could not start. Check Python and detect again; edits are preserved.";}
            if(root.operationPending&&!displayProcess.running){root.operationPending=false;guardedDisplayActions.fail("Display helper could not start. No request was submitted; check Python and retry.");}
            if(root.draftSavePending&&!draftSave.running){root.draftSavePending=false;root.draftPersistenceError="Draft helper could not start; edits remain in memory. Check Python before closing the shell.";}
            if(root.policyStarting&&!policyRestore.running){root.policyStarting=false;root.policyRestorePending=false;root.error="Workspace policy helper could not start. Check Python; a configuration reload retries it.";}
            if(root.repairPending&&!autoRepair.running){root.repairPending=false;root.recoveryMessage="Automatic recovery helper could not start. Independent preview recovery is unchanged; inspect Diagnostics.";}
        }
    }
    Timer {interval:500;running:guardedDisplayActions.actionState==="revert-pending";repeat:true;onTriggered:root.refresh(true)}
    Timer {id:identifyTimer;interval:5000;onTriggered:root.identifying=false}
}
