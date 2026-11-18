import QtQuick
import "DisplayGeometry.js" as Geometry

QtObject {
    id: root
    property var displays: []
    property string observedDigest: ""
    property string baseDigest: ""
    property var baseline: []
    property var edits: ({})
    property var history: []
    property string selectedKey: ""
    property string observedPrimary: ""
    property string primary: observedPrimary
    onObservedPrimaryChanged:if(!dirty)primary=observedPrimary
    property var policyPatch: ({})
    property var workspaceTargets: ({})
    property bool conflict: false
    readonly property bool dirty: Object.keys(edits).length>0
    readonly property var outputs: baseline.map(item=>Object.assign({},item,edits[item.key]||{}))
    readonly property var selectedDisplay: displays.find(item=>(item.key||item.name)===selectedKey)||null
    readonly property var selectedOutput: outputs.find(item=>item.key===selectedKey)||null
    readonly property string validationError: Geometry.validate(outputs)
    onDisplaysChanged: reconcile()
    onObservedDigestChanged: reconcile()
    function reconcile() {
        if(!displays.some(item=>(item.key||item.name)===selectedKey))selectedKey=displays.length?(displays[0].key||displays[0].name):"";
        if(!dirty){baseline=displays.map(Geometry.fromDisplay);baseDigest=observedDigest;conflict=false;}
        else {
            const known=new Set(baseline.map(o=>o.key)),added=displays.filter(d=>!known.has(d.key||d.name)).map(Geometry.fromDisplay);
            if(added.length)baseline=baseline.concat(added);
            if(observedDigest && baseDigest && observedDigest!==baseDigest)conflict=true;
        }
    }
    function selectName(name){const item=displays.find(d=>d.name===name);if(item)selectedKey=item.key||item.name;}
    function checkpoint(){history=history.concat([{edits:Geometry.copy(edits),policyPatch:Geometry.copy(policyPatch),workspaceTargets:Geometry.copy(workspaceTargets),primary:primary,baseline:Geometry.copy(baseline),baseDigest:baseDigest,conflict:conflict}]).slice(-30);}
    function patch(key,values,checkpointFirst) {
        if(checkpointFirst!==false)checkpoint();
        const next=Geometry.copy(edits);next[key]=Object.assign(next[key]||{},values);edits=next;
    }
    function stage(plan) {
        checkpoint();baseline=Geometry.copy(plan.outputs);baseDigest=plan.baseDigest||observedDigest;conflict=false;
        const next={};plan.outputs.forEach(out=>{const values=Geometry.copy(out);delete values.key;delete values.name;next[out.key]=values;});edits=next;
        primary=plan.primary||primary;policyPatch=plan.policyPatch||{};workspaceTargets=plan.workspaceTargets||{};
    }
    function undo(){if(history.length){const old=history[history.length-1];edits=old.edits;policyPatch=old.policyPatch;workspaceTargets=old.workspaceTargets;primary=old.primary;baseline=old.baseline;baseDigest=old.baseDigest;conflict=old.conflict;history=history.slice(0,-1);reconcile();}}
    function discard(){primary=observedPrimary;edits=({});history=[];policyPatch=({});workspaceTargets=({});baseline=displays.map(Geometry.fromDisplay);baseDigest=observedDigest;conflict=false;}
    function rebase(){const live=new Set(displays.map(d=>d.key||d.name)),next={};Object.keys(edits).forEach(key=>{if(live.has(key)){next[key]=Geometry.copy(edits[key]);delete next[key].key;delete next[key].name;}});baseline=displays.map(Geometry.fromDisplay);edits=next;baseDigest=observedDigest;conflict=false;}
    function exported(){return {edits:edits,baseline:baseline,baseDigest:baseDigest,selectedKey:selectedKey,primary:primary,policyPatch:policyPatch,workspaceTargets:workspaceTargets,requiresReview:conflict};}
    function restore(saved){if(!saved||!Array.isArray(saved.baseline)||!saved.edits)return false;baseline=Geometry.copy(saved.baseline);edits=Geometry.copy(saved.edits);baseDigest=saved.baseDigest||"";selectedKey=saved.selectedKey||selectedKey;primary=saved.primary||primary;policyPatch=saved.policyPatch||{};workspaceTargets=saved.workspaceTargets||{};reconcile();if(saved.requiresReview)conflict=true;return true;}
    function arrangeSideBySide() {
        const group=outputs.filter(o=>o.enabled&&!o.mirrorOf).sort((a,b)=>a.x-b.x||a.y-b.y);
        if(!group.length)return;
        checkpoint();
        let x=Math.min.apply(null,group.map(o=>o.x));
        const y=Math.min.apply(null,group.map(o=>o.y));
        group.forEach(out=>{patch(out.key,{x:Math.round(x),y:y},false);x+=Geometry.rectangle(out).width;});
    }
    function centreGroup(below) {
        const out=selectedOutput;if(!out)return;
        const others=outputs.filter(o=>o.key!==out.key&&o.enabled&&!o.mirrorOf);if(!others.length)return;
        const b=Geometry.bounds(others),r=Geometry.rectangle(out);
        patch(out.key,{x:Math.round(b.x+(b.width-r.width)/2),y:Math.round(below?b.y+b.height:b.y-r.height)});
    }
    function mode(kind,sourceName) {
        if(!selectedOutput)return;
        checkpoint();policyPatch=Object.assign({},policyPatch,{projectionMode:"custom"});workspaceTargets=({});
        if(kind==="only")primary=selectedKey;
        outputs.forEach(out=>{
            if(kind==="only")patch(out.key,{enabled:out.key===selectedKey,mirrorOf:""},false);
            else if(kind==="extend")patch(out.key,{mirrorOf:""},false);
        });
        if(kind==="mirror")patch(selectedKey,{enabled:true,mirrorOf:sourceName},false);
    }
}
