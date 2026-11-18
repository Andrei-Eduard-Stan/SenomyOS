pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../config" as Config
import "../services/DisplayGeometry.js" as Geometry
import "../services" as Services

Column {
    id:root
    required property var inventory
    property string selectedName:""
    signal selectionRequested(string name)
    readonly property var actions:inventory.displayActions
    readonly property var draft:inventory.draft||fallbackDraft
    Services.DisplayDraft {id:fallbackDraft;displays:root.displays}
    readonly property var displays:inventory.displays||[]
    readonly property var selectedDisplay:draft.selectedDisplay
    readonly property var selectedOutput:draft.selectedOutput
    readonly property bool editable:!actions.locked&&!actions.token&&actions.actionState!=="pending"&&!inventory.error
    readonly property bool canReview:!actions.locked&&!actions.token&&actions.actionState!=="pending"&&draft.dirty&&inventory.displayBusy!==true
    readonly property var draftProblems:{
        const problems=[];
        if(actions.token)problems.push("Resolve the active display recovery before reviewing another change.");
        if(!draft.dirty)problems.push("No draft changes remain. Cancel this review to continue editing.");
        if(inventory.error)problems.push("Fresh display detection is unavailable: "+inventory.error);
        if(draft.conflict)problems.push("Your draft uses an older running layout. Update its baseline below; your edits will be kept.");
        if(draft.validationError)problems.push(draft.validationError);
        if(inventory.displayBusy===true)problems.push("Wait for the current display operation to finish.");
        return problems;
    }
    readonly property var modes:selectedDisplay?Array.from(new Set(selectedDisplay.availableModes||[])):[]
    readonly property var resolutions:Array.from(new Set(modes.map(m=>{const p=Geometry.modeParts(m);return p?p.width+"×"+p.height:"";})))
    readonly property var refreshModes:modes.filter(m=>{const p=Geometry.modeParts(m);return p&&p.width+"×"+p.height===resolution.currentText;})
    property bool syncing:false
    property bool showPolicy:false
    readonly property int viewColumns:Math.max(1,Math.min(3,Math.floor((width+6)/(150*Config.DirectoryStyle.textScale+6))))
    property string view:"projection"
    property string workspaceName:""
    property int selectedWorkspace:0
    property string draggedWorkspace:""
    property var draggedWindow:null
    spacing:10
    onSelectedNameChanged:if(selectedName){draft.selectName(selectedName);if(view==="projection")view="settings";}else view="projection";
    Component.onCompleted:{if(selectedName){draft.selectName(selectedName);view="settings";}Qt.callLater(syncInspector);}
    function syncInspector(){
        if(!selectedOutput)return;
        syncing=true;
        const p=Geometry.modeParts(selectedOutput.mode),res=p?p.width+"×"+p.height:"";
        resolution.currentIndex=resolutions.indexOf(res);
        refresh.currentIndex=refreshModes.indexOf(selectedOutput.mode);
        if(refresh.currentIndex<0&&p)refresh.currentIndex=refreshModes.findIndex(m=>Math.abs(Geometry.modeParts(m).hz-p.hz)<0.06);
        scale.value=Math.round(selectedOutput.scale*100);orientation.currentIndex=selectedOutput.transform;
        positionX.value=selectedOutput.x;positionY.value=selectedOutput.y;
        syncing=false;
    }
    Connections {target:root.inventory;ignoreUnknownSignals:true;function onProjectionEpochChanged(){root.view="projection";}}
    Connections {target:root.draft;function onSelectedOutputChanged(){Qt.callLater(root.syncInspector);}}
    function patch(value){if(!syncing&&editable&&selectedOutput)draft.patch(selectedOutput.key,value);}
    function revealReview() {
        root.forceLayout();
        let host=root.parent;
        while(host){
            if(host.contentItem&&host.contentY!==undefined){
                const point=reviewPanel.mapToItem(host.contentItem,0,0);
                host.contentY=Math.max(0,Math.min(point.y,host.contentHeight-host.height));
                break;
            }
            host=host.parent;
        }
    }
    function reviewDraft() {
        if(actions.locked||actions.token||!draft.dirty||inventory.displayBusy===true)return false;
        const opened=actions.requestTopology(draft.outputs,draft.baseDigest,draft.primary,draft.policyPatch,draft.workspaceTargets);
        if(opened)Qt.callLater(revealReview);
        return opened;
    }
    function confirmReview() {
        if(actions.actionState!=="pending")return false;
        if(actions.actionKind==="topology"){
            if(draftProblems.length)return false;
            // Refresh the reviewed payload after any baseline/spacing repair.
            if(!actions.requestTopology(draft.outputs,draft.baseDigest,draft.primary,draft.policyPatch,draft.workspaceTargets))return false;
        }
        return actions.confirm();
    }
    Connections {target:root.actions;function onActionStateChanged(){if(["pending","revert-pending"].indexOf(root.actions.actionState)>=0)Qt.callLater(root.revealReview);}}
    function review(operation,argument,text){actions.requestOperation(operation,argument,text);}
    function workspace(id,argument,text){review("workspace",Object.assign({id:id},argument),text);}
    function selectMonitor(name){draft.selectName(name);selectionRequested(name);}
    ConfirmationFocus {view:root;actions:root.actions;cancelButton:actions.actionState==="revert-pending"?revert:cancel;pendingStates:["pending","revert-pending"]}

    Text {
        width:parent.width;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize
        color:((inventory.savedLayout||{}).status||"none")==="matching"?Config.DirectoryStyle.muted:Config.Theme.warning
        text:{const status=(inventory.savedLayout||{}).status||"none";return draft.dirty?"UNSAVED EDITS · Review & Apply → Confirm → Keep saves this arrangement.":status==="matching"?"SAVED · The running arrangement matches your startup layout.":status==="different-setup"?"SAVED FOR A DIFFERENT SETUP · Current displays do not match the saved layout.":status==="changed"?"RUNNING LAYOUT HAS CHANGED · Save the running layout, or apply and Keep your edits.":"NO SAVED STARTUP LAYOUT · Apply and Keep edits, or save the running layout below.";}
    }
    Text {width:parent.width;visible:!!inventory.recoveryMessage;text:inventory.recoveryMessage||"";wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:Config.Theme.warning;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
    Column {
        width:parent.width;spacing:8
        QuietButton {text:root.showPolicy?"Hide recovery options":"Recovery options";active:root.showPolicy;onClicked:root.showPolicy=!root.showPolicy}
        ControlWorkspaceButton {
            visible:root.showPolicy
            width:Math.min(260,root.width);text:inventory.policy.autoRecovery===true?"AUTO RECOVERY ON":"ENABLE AUTO RECOVERY";active:inventory.policy.autoRecovery===true;enabled:root.editable&&!inventory.displayBusy
            onClicked:root.review("recovery-config",{enabled:inventory.policy.autoRecovery!==true},inventory.policy.autoRecovery===true?"Turn off automatic recovery of low-resolution display fallbacks.":"Enable automatic recovery to the last confirmed layout if a connected display falls to a low resolution. This also retries a rejected mode once as a complete layout. Shared-link limits can still reject a resolution; unconfirmed modes are never saved.")
        }
    }
    Text {width:parent.width;visible:!!inventory.draftPersistenceError;text:inventory.draftPersistenceError||"";wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
    Flow {
        width:parent.width;spacing:6
        ControlWorkspaceButton {width:130;text:inventory.identifying?"Hide labels":"Identify";onClicked:inventory.identifying?inventory.dismissIdentify():inventory.identify()}
        ControlWorkspaceButton {width:100;text:"Detect";enabled:!inventory.loading;onClicked:inventory.refresh(true)}
        ControlWorkspaceButton {width:205;text:"Save running layout";enabled:root.editable&&!draft.dirty;onClicked:root.review("save-current",{},"Save the currently running monitor modes and positions for startup. No output is reconfigured. Unapplied edits are not included.")}
        ControlWorkspaceButton {objectName:"displayReview";width:170;text:"Review & apply";enabled:root.canReview;onClicked:root.reviewDraft()}
    }
    Text {width:parent.width;visible:draft.dirty&&root.draftProblems.length>0&&actions.actionState!=="pending";text:root.draftProblems.join("\n");textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
    Column {
        id:reviewPanel;objectName:"displayReviewPanel"
        onHeightChanged:if(["pending","revert-pending"].indexOf(actions.actionState)>=0)Qt.callLater(root.revealReview)
        width:parent.width;spacing:8;visible:actions.actionState!=="idle"
        Text {width:parent.width;text:actions.actionState.toUpperCase()+" · "+actions.message;wrapMode:Text.WordWrap;color:actions.actionState==="failed"?Config.Theme.danger:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;textFormat:Text.PlainText}
        Text {width:parent.width;visible:actions.actionState==="pending"&&actions.actionKind==="topology";text:actions.proposed&&actions.proposed.outputs?actions.proposed.outputs.map(o=>o.name+": "+(o.enabled?o.mode+" · "+o.scale+"× · "+o.x+", "+o.y+(o.mirrorOf?" · mirrors "+o.mirrorOf:""):"DISABLED")).join("\n"):"";color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
        Text {objectName:"displayReviewProblems";width:parent.width;visible:actions.actionState==="pending"&&actions.actionKind==="topology"&&root.draftProblems.length>0;text:root.draftProblems.join("\n");wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:Config.Theme.warning;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
        Flow {
            width:parent.width;spacing:8;visible:actions.actionState==="pending"&&actions.actionKind==="topology"
            ControlWorkspaceButton {objectName:"displayUpdateBaseline";visible:draft.conflict;text:"UPDATE BASELINE";enabled:!actions.locked&&!inventory.error;onClicked:{draft.rebase();root.reviewDraft();}}
            ControlWorkspaceButton {objectName:"displayResolveOverlap";visible:draft.validationError.indexOf("Overlap:")===0;text:"ARRANGE SIDE BY SIDE";enabled:!actions.locked;onClicked:{draft.arrangeSideBySide();root.reviewDraft();}}
        }
        Row {visible:actions.actionState==="pending";width:parent.width;spacing:8
            ControlWorkspaceButton {id:cancel;objectName:"displayCancel";width:(parent.width-8)/2;text:"CANCEL";onClicked:actions.cancel()}
            ControlWorkspaceButton {objectName:"displayConfirm";width:(parent.width-8)/2;text:"CONFIRM";enabled:actions.actionKind!=="topology"||root.draftProblems.length===0;onClicked:root.confirmReview()}
        }
        Row {visible:actions.actionState==="revert-pending";width:parent.width;spacing:8
            ControlWorkspaceButton {id:revert;objectName:"displayRevert";width:(parent.width-8)/2;text:"REVERT NOW";onClicked:actions.revert()}
            ControlWorkspaceButton {width:(parent.width-8)/2;text:"KEEP · "+actions.secondsRemaining+"s";onClicked:actions.keep()}
        }
    }
    Flow {
        width:parent.width;spacing:6
        Repeater {model:["projection","arrangement","settings","workspaces","profiles","diagnostics"];ControlWorkspaceButton {required property string modelData;width:Math.max(1,(root.width-6*(root.viewColumns-1))/root.viewColumns);height:Math.max(implicitHeight,Config.DirectoryStyle.touchMode?48:44);text:({projection:"Projection",arrangement:"Arrange",settings:"Output settings",workspaces:"Workspaces",profiles:"Saved layouts",diagnostics:"Diagnostics"})[modelData];active:root.view===modelData;onClicked:root.view=modelData}}
    }
    Text {width:parent.width;visible:draft.conflict;text:"Your draft needs review against the running layout. Review & Apply can show the changes and help update the baseline without losing your edits.";wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
    Flow {
        visible:draft.conflict;width:parent.width;spacing:8
        ControlWorkspaceButton {text:"UPDATE BASELINE";enabled:!actions.locked&&!inventory.error;onClicked:{draft.rebase();if(actions.actionState==="pending")root.reviewDraft();}}
        ControlWorkspaceButton {text:"DISCARD";enabled:!actions.locked;onClicked:draft.discard()}
    }
    DisplayProjection {width:parent.width;visible:root.view==="projection";inventory:root.inventory;editable:root.editable;onCustomRequested:root.view="arrangement"}
    Column {
        visible:root.view==="arrangement"||root.view==="workspaces";width:parent.width;spacing:10
        Flow {
            width:parent.width;spacing:6
            ControlWorkspaceButton {width:100;text:"FIT ALL";onClicked:canvas.fit()}
            ControlWorkspaceButton {width:70;text:"ZOOM −";onClicked:canvas.zoom(0.8)}
            ControlWorkspaceButton {width:70;text:"ZOOM +";onClicked:canvas.zoom(1.25)}
            ControlWorkspaceButton {width:125;text:canvas.snapping?"SNAP ON":"SNAP OFF";active:canvas.snapping;onClicked:canvas.snapping=!canvas.snapping}
            ControlWorkspaceButton {width:90;text:"UNDO";enabled:root.editable&&draft.history.length>0;onClicked:draft.undo()}
        }
        DisplayCanvas {id:canvas;width:parent.width;height:300;draft:root.draft;inventory:root.inventory;workspaceMode:root.view==="workspaces";editable:root.editable;onSelected:name=>root.selectMonitor(name)}
        Flow {
            width:parent.width;spacing:6
            Repeater {
                model:root.displays
                ControlWorkspaceButton {
                    required property var modelData
                    readonly property var staged:root.draft.outputs.find(o=>o.key===modelData.key)
                    width:Math.min(root.width,180);text:modelData.number+" · "+modelData.name
                    detail:staged&&!staged.enabled?"Draft disabled · connected":staged&&staged.mirrorOf?"Draft mirrors "+staged.mirrorOf:modelData.disabled?"Connected · disabled":modelData.mirrorOf&&modelData.mirrorOf!=="none"?"Mirrors "+modelData.mirrorOf:modelData.dpmsStatus===false?"Enabled · asleep":modelData.width+"×"+modelData.height
                    active:draft.selectedKey===modelData.key
                    onClicked:root.selectMonitor(modelData.name)
                }
            }
        }
    }
    Column {
        width:parent.width;spacing:8;visible:root.view==="arrangement"||root.view==="settings"
        ShellComboBox {id:display;objectName:"control-display-selection";width:parent.width;model:root.displays.map(d=>d.number+" · "+d.friendlyName+" · "+d.name);currentIndex:root.displays.findIndex(d=>d.key===draft.selectedKey);enabled:!actions.locked;onActivated:index=>root.selectMonitor(root.displays[index].name);Accessible.name:"Selected monitor"}
        Text {width:parent.width;wrapMode:Text.WordWrap;text:root.selectedDisplay?"Actual: "+root.selectedDisplay.width+"×"+root.selectedDisplay.height+" at "+Number(root.selectedDisplay.refreshRate).toFixed(2)+" Hz · "+root.selectedDisplay.scale+"× · physical "+(root.selectedDisplay.physicalWidth||"unknown")+"×"+(root.selectedDisplay.physicalHeight||"unknown")+" mm":"No display detected";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
        Text {width:parent.width;visible:root.selectedDisplay&&root.modes.length>0&&Geometry.modeParts(root.modes[0]).width>root.selectedDisplay.width;text:"A higher mode is advertised. Availability depends on the complete GPU/dock/link setup; review before changing it.";wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
        Row {
            width:parent.width;spacing:8
            ShellComboBox {id:resolution;width:(parent.width-8)/2;model:root.resolutions;enabled:root.editable;Accessible.name:"Resolution";onActivated:index=>{const mode=root.modes.find(m=>{const p=Geometry.modeParts(m);return p.width+"×"+p.height===root.resolutions[index];});if(mode)root.patch({mode:mode});}}
            ShellComboBox {id:refresh;width:(parent.width-8)/2;model:root.refreshModes;enabled:root.editable;Accessible.name:"Refresh rate and mode";onActivated:index=>root.patch({mode:root.refreshModes[index]})}
        }
        Row {
            width:parent.width;spacing:8
            Column {width:(parent.width-8)/2;Text {text:"Scale (%)";color:Config.DirectoryStyle.muted}ShellSpinBox {id:scale;width:parent.width;from:50;to:400;stepSize:25;editable:true;enabled:root.editable;Accessible.name:"Display scale percent";onValueModified:root.patch({scale:value/100})}}
            ShellComboBox {id:orientation;width:(parent.width-8)/2;model:["Landscape","Portrait right","180°","Portrait left","Flipped","Flipped 90°","Flipped 180°","Flipped 270°"];enabled:root.editable;Accessible.name:"Orientation";onActivated:index=>root.patch({transform:index})}
        }
        Row {
            width:parent.width;spacing:8
            Column {width:(parent.width-8)/2;Text {text:"Horizontal position";color:Config.DirectoryStyle.muted}ShellSpinBox {id:positionX;width:parent.width;from:-65536;to:65536;editable:true;enabled:root.editable;Accessible.name:"Horizontal position";onValueModified:root.patch({x:value})}}
            Column {width:(parent.width-8)/2;Text {text:"Vertical position";color:Config.DirectoryStyle.muted}ShellSpinBox {id:positionY;width:parent.width;from:-65536;to:65536;editable:true;enabled:root.editable;Accessible.name:"Vertical position";onValueModified:root.patch({y:value})}}
        }
        Flow {
            width:parent.width;spacing:6
            ControlWorkspaceButton {width:200;text:"CENTRE BELOW GROUP";enabled:root.editable;onClicked:draft.centreGroup(true)}
            ControlWorkspaceButton {width:200;text:"CENTRE ABOVE GROUP";enabled:root.editable;onClicked:draft.centreGroup(false)}
            ControlWorkspaceButton {text:root.selectedOutput&&root.selectedOutput.enabled?"DISABLE SELECTED":"ENABLE SELECTED";enabled:root.editable&&!!root.selectedOutput;onClicked:root.patch({enabled:!root.selectedOutput.enabled})}
            ControlWorkspaceButton {text:"ONLY SELECTED";enabled:root.editable&&!!root.selectedOutput;onClicked:draft.mode("only","")}
            ControlWorkspaceButton {text:"EXTEND SELECTED";enabled:root.editable&&!!root.selectedOutput;onClicked:root.patch({mirrorOf:""})}
            ControlWorkspaceButton {width:185;text:"PREFERRED PRIMARY";enabled:root.editable&&!!root.selectedOutput;onClicked:root.workspace(0,{action:"primary",monitor:root.selectedOutput.name},"Use "+root.selectedOutput.name+" for Senomy notification placement. Rails remain per output; launchers, new applications and dialogs keep native focus behaviour.")}
        }
        Row {
            width:parent.width;spacing:8
            ShellComboBox {id:mirrorSource;width:Math.max(100,parent.width-190);model:root.displays.filter(d=>d.key!==draft.selectedKey&&!d.disabled&&(!d.mirrorOf||d.mirrorOf==="none")).map(d=>d.name);Accessible.name:"Mirror source"}
            ControlWorkspaceButton {width:180;text:"DUPLICATE SOURCE";enabled:root.editable&&mirrorSource.currentIndex>=0;onClicked:draft.mode("mirror",mirrorSource.currentText)}
        }
        Text {width:parent.width;text:"Duplicate copies the source framebuffer; different aspect ratios can stretch. A mirrored screen shares its source’s Identify number. Disable removes its workspace area; sleep/DPMS is separate.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
    }
    Loader {width:parent.width;active:root.view==="workspaces";visible:active;sourceComponent:DisplayWorkspaces {enabled:root.editable;width:parent?parent.width:0;inventory:root.inventory;onReview:(argument,text)=>root.review("workspace",argument,text);onMonitorSelected:name=>root.selectMonitor(name)}}
    Loader {width:parent.width;active:root.view==="profiles";visible:active;sourceComponent:DisplayProfiles {enabled:root.editable;width:parent?parent.width:0;inventory:root.inventory;onReview:(operation,argument,text)=>root.review(operation,argument,text)}}
    Column {
        width:parent.width;spacing:8;visible:root.view==="diagnostics"
        Text {width:parent.width;visible:!!((inventory.snapshot||{}).startup||{}).state;wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:((inventory.snapshot||{}).startup||{}).ok===false?Config.Theme.warning:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;text:"Startup · "+(((inventory.snapshot||{}).startup||{}).message||"")}
        Text {width:parent.width;wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;text:"Recovery · "+((inventory.recoveryHealth||{}).message||"No recovery status available.")}
        Repeater {model:root.displays;Text {required property var modelData;width:parent.width;wrapMode:Text.WordWrap;text:modelData.number+" · "+modelData.friendlyName+" · "+modelData.name+"\nActual "+modelData.width+"×"+modelData.height+" @ "+Number(modelData.refreshRate).toFixed(3)+" Hz · scale "+modelData.scale+" · position "+modelData.x+", "+modelData.y+"\n"+(modelData.identityStrong?"Serial-backed local identity":"Connector fallback identity; automatic profile matching disabled")+" · workspace "+((modelData.activeWorkspace||{}).name||"none")+"\nModes: "+(modelData.availableModes||[]).join(", ");color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;textFormat:Text.PlainText}}
    }
    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
    Text {width:parent.width;visible:draft.dirty&&root.draftProblems.length>0;text:root.draftProblems.join("\n");textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
    Flow {
        width:parent.width;spacing:8
        ControlWorkspaceButton {objectName:"displayReviewBottom";text:"Review & apply";enabled:root.canReview;onClicked:root.reviewDraft()}
        ControlWorkspaceButton {text:"DISCARD EDITS";enabled:!actions.locked&&draft.dirty;onClicked:draft.discard()}
    }

}
