import QtQuick

// Request/result policy is independently testable; process execution is injected.
QtObject {
    id: root
    required property var queryRunner
    required property var actionRunner
    required property string sourceRoot
    property bool active: false
    property string section: "briefing"
    property var payloads: ({})
    property var statuses: ({})
    property var queue: []
    property var inFlight: null
    property var action: null
    property string actionState: "idle"
    property string actionMessage: ""
    property string lastActionDomain: ""
    readonly property string actionDomain: action ? action.domain : lastActionDomain
    readonly property string error: (statuses[section] || {}).error || ""
    readonly property bool busy: inFlight !== null
    readonly property var routes: ["briefing","notifications","timeline","updates","diagnostics","console","reports","wiki"]

    function commandFor(route, result) {
        const base = sourceRoot + "/scripts/";
        switch(route) {
        case "briefing": return [base+"update-status.sh","read"];
        case "updates": return ["python3","-B",base+"senomy-maintenance.py","read"];
        case "timeline": return [base+"timeline-status.sh","activity"];
        case "diagnostics": case "console": return [base+route+"-status.sh",result?"read":"catalog"];
        case "reports": return [base+"performance-report.sh","read-json"];
        case "wiki": return [base+"wiki-status.py","catalog"];
        default: return [];
        }
    }
    function status(key,state,error,at) {
        const next=Object.assign({},statuses);
        next[key]={state:state,error:error||"",observedAt:Number.isFinite(Number(at)) && Number(at)>0?Number(at):0};statuses=next;
    }
    function store(key,payload) {
        const next=Object.assign({},payloads);next[key]=payload;payloads=next;
        status(key,payload.ok?"ready":"failed",payload.ok?"":(payload.error||{}).message||"Collector reported failure.",payload.observed_at);
    }
    function decode(output) {
        const parsed=JSON.parse(output);
        if (!parsed || typeof parsed.ok!=="boolean" || (parsed.data!==null && typeof parsed.data!=="object"))
            throw new Error("Invalid collector envelope");
        return parsed;
    }
    function refresh(route,result,afterAction) {
        const target=route||section;
        if ((!active && !afterAction) || commandFor(target,result).length===0) return false;
        const key=target+(result?"Result":"");
        // Keep action-result reads first; normal refreshes deduplicate by key.
        const pending=queue.filter(request=>request.key!==key);
        const request={route:target,key:key,result:Boolean(result),afterAction:Boolean(afterAction)};
        if(afterAction)pending.unshift(request);else pending.push(request);
        queue=pending;status(key,"loading","",(statuses[key]||{}).observedAt);drain();return true;
    }
    function drain() {
        if(inFlight || queryRunner.running || queue.length===0)return;
        const pending=queue.slice();let request=pending.shift();
        while(request && !active && !request.afterAction)request=pending.shift();
        queue=pending;if(!request)return;
        inFlight=request;
        queryRunner.exec(commandFor(request.route,request.result));
    }
    function queryCompleted(code,output) {
        const request=inFlight;inFlight=null;if(!request)return;
        let parsed=null;
        try { parsed=decode(output);if(code===0)store(request.key,parsed); }
        catch(_) {status(request.key,"failed","Collector returned invalid data.",(statuses[request.key]||{}).observedAt);}
        if(code!==0 && (!parsed || parsed.ok)) status(request.key,"failed","Collector failed or timed out.",(parsed||{}).observed_at);
        if(request.afterAction && action)finishAction(code,parsed);
        drain();
    }
    function tasksFor(domain) {const payload=payloads[domain];return payload && payload.ok && payload.data && Array.isArray(payload.data.tasks)?payload.data.tasks:[];}
    function begin(domain,id,command) {
        if(!active || action || actionRunner.running || actionState==="running")return false;
        action={domain:domain,id:id,startedAt:Math.floor(Date.now()/1000)};
        status(domain,"running","",(statuses[domain]||{}).observedAt);
        lastActionDomain=domain;actionState="running";actionMessage="Running requested action…";
        actionRunner.exec(command);return true;
    }
    function runTask(domain,id) {
        if(section!==domain || ["diagnostics","console"].indexOf(domain)<0 || typeof id!=="string"
                || !/^[a-z0-9-]+$/.test(id) || !tasksFor(domain).some(task=>task.id===id && task.available!==false))return false;
        return begin(domain,id,[sourceRoot+"/scripts/"+domain+"-status.sh","run",id]);
    }
    function runUpdate(kind) {
        if(["briefing","updates"].indexOf(section)<0 || ["official","aur"].indexOf(kind)<0)return false;
        return begin("updates",kind,[sourceRoot+"/scripts/update-status.sh","check-"+kind]);
    }
    function openMaintenance() {
        if(section!=="updates")return false;
        return begin("maintenance","open",["python3","-B",sourceRoot+"/scripts/senomy-maintenance.py","open"]);
    }
    function generateReport(profile) {
        if(section!=="reports" || ["overview","performance","network","power","full"].indexOf(profile)<0)return false;
        return begin("reports",profile,[sourceRoot+"/scripts/performance-report.sh","generate-json",profile]);
    }
    function openLatestReport() {
        if(section!=="reports" || !(payloads.reports && payloads.reports.ok && payloads.reports.data.exists))return false;
        return begin("reports","open",[sourceRoot+"/scripts/performance-report.sh","open-latest"]);
    }
    function finishAction(code,parsed) {
        const requested=action;if(!requested)return;
        let succeeded=code===0 && parsed && parsed.ok;
        const data=parsed && parsed.data || {};
        if(["console","diagnostics"].indexOf(requested.domain)>=0)
            succeeded=succeeded && data.task_id===requested.id && ["ready","succeeded"].indexOf(data.state)>=0
                && Number(data.finished_at)>=requested.startedAt;
        else if(requested.domain==="updates")succeeded=succeeded && data[requested.id] && data[requested.id].ok===true && Number(data[requested.id].checked_at)>=requested.startedAt;
        else if(requested.domain==="reports")succeeded=succeeded && data.exists===true && data.latest && data.latest.profile===requested.id && Number(data.latest.generated_at)>=requested.startedAt;
        actionState=succeeded?"succeeded":"failed";
        actionMessage=succeeded?"Requested action completed; review the collected evidence.":(parsed && parsed.error||{}).message||"Requested action failed or its result could not be verified.";
        status(requested.domain,succeeded?"ready":"failed",succeeded?"":actionMessage,(parsed||{}).observed_at);
        action=null;
    }
    function actionCompleted(code,output) {
        if(!action)return;
        const domain=action.domain;
        if(domain==="maintenance") {
            let result=null;try {result=decode(output);}catch(_) {}
            const started=code===0&&result&&result.ok===true&&result.data.state==="terminal-requested";
            actionState=started?"started":"failed";
            actionMessage=started?"Native terminal requested. Review and authenticate there; package completion remains pending.":(result&&result.error||{}).message||"Package review terminal failed.";
            action=null;return;
        }
        if(action.id==="open") {
            actionState=code===0?"started":"failed";actionMessage=code===0?"Report viewer launch requested; visible opening is unverified.":"Report viewer could not be launched.";action=null;return;
        }
        try {
            const parsed=decode(output);
            if(code===0)store(domain+(["console","diagnostics"].indexOf(domain)>=0?"Result":""),parsed);
            finishAction(code,parsed);
        } catch(_) {
            if(code===0 && domain==="console" && !output.trim()) refresh(domain,true,true);
            else finishAction(code,null);
        }
        // Update views share the same cache, but querying it never implies fresh package discovery.
        if(domain==="updates" && active)refresh("briefing",false,false);
    }
    onActiveChanged: {
        if(active) {refresh(section,false);if(["console","diagnostics"].indexOf(section)>=0)refresh(section,true);}
        else queue=queue.filter(request=>request.afterAction);
    }
    onSectionChanged: if(active) {refresh(section,false);if(["console","diagnostics"].indexOf(section)>=0)refresh(section,true);}
    property Timer startupCheck:Timer {
        interval:200;repeat:true
        running:!!root.inFlight&&!root.queryRunner.running||!!root.action&&root.actionState==="running"&&!root.actionRunner.running&&!root.queue.some(r=>r.afterAction)&&!(root.inFlight&&root.inFlight.afterAction)
        onTriggered:{
            if(root.inFlight&&!root.queryRunner.running){
                const request=root.inFlight;
                root.queryCompleted(127,"");
                root.status(request.key,"failed","Collector could not start. Check the helper and its dependencies before refreshing.",(root.statuses[request.key]||{}).observedAt);
                if(request.afterAction)root.actionMessage="The result collector could not start; inspect actual state before retrying the action.";
            }
            if(root.action&&root.actionState==="running"&&!root.actionRunner.running&&!root.queue.some(r=>r.afterAction)&&!(root.inFlight&&root.inFlight.afterAction)){
                const domain=root.action.domain;root.finishAction(127,null);root.actionMessage="The requested helper could not start. Check its dependencies and review again.";
                root.status(domain,"failed",root.actionMessage,(root.statuses[domain]||{}).observedAt);
            }
        }
    }
}
