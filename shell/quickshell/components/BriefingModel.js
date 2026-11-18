.pragma library
.import "DirectoryFreshness.js" as Freshness

// Presentation only: never checks repositories, generates reports or mutates providers.
function source(kind, payload, now) {
    const p=payload || {}, at=Number(p.checked_at)*1000;
    const base={id:kind,label:kind==="official"?"Official repositories":"AUR",count:null,current:false,tone:"muted"};
    if(p.ok!==true)return Object.assign(base,{state:p.state_label==="NOT CHECKED"?"Not checked":"Unavailable",age:"No verified check",meaning:"Package status unknown"});
    if(!Number.isFinite(at) || at<=0)return Object.assign(base,{state:"Time unknown",age:"No check timestamp",meaning:"Package status unknown"});
    if(at>now+60000)return Object.assign(base,{state:"Clock mismatch",age:"Check time is in the future",meaning:"Package status unknown"});
    const age=Freshness.ageLabel(at,now);
    if(now-at>3600000)return Object.assign(base,{state:"Check needed",age:"Last checked "+age,meaning:"Package status unknown",tone:"attention"});
    if(p.freshness==="local-database")return Object.assign(base,{state:"Cache only",age:"Read "+age,meaning:"Repository metadata may be old",tone:"attention"});
    const count=p.count===null || p.count===undefined?NaN:Number(p.count);
    if(!Number.isFinite(count) || count<0)return Object.assign(base,{state:"Count unavailable",age:"Checked "+age,meaning:"Package count unknown"});
    return Object.assign(base,{state:"Current check",age:"Checked "+age,meaning:count+" package"+(count===1?"":"s")+" reported",count:count,current:true});
}
function sources(data,now){return [source("official",(data||{}).official,now),source("aur",(data||{}).aur,now)];}
function assessment(health,message){
    if(health==="nominal")return {title:"No active health alerts",detail:"From the available local system observations.",state:"nominal"};
    if(health==="warning")return {title:"System needs attention",detail:message || "Inspect the local diagnostic evidence.",state:"warning"};
    return {title:"Assessment unavailable",detail:message || "Waiting for local system observations.",state:"unavailable"};
}
function queue(health,message,notifications,network,data,now){
    const rows=[], evidence=sources(data,now);
    if(health!=="nominal")rows.push({id:"health",title:health==="warning"?"System health":"Local observations",state:health==="warning"?"Attention":"Unavailable",detail:message || "Review the available diagnostic evidence.",route:"diagnostics",action:"Open Diagnostics",priority:0,tone:health==="warning"?"attention":"muted"});
    if(network.available===false || network.label==="OFF")rows.push({id:"network",title:"Network availability",state:"Check connection",detail:network.detail || "Connection information is unavailable.",route:"diagnostics",action:"Inspect connection",priority:1,tone:"attention"});
    if(evidence.some(s=>!s.current))rows.push({id:"updates",title:"Update checks",state:"Evidence incomplete",detail:"Current package status is unknown. Review the source checks before deciding about updates.",route:"updates",action:"Open Updates",priority:2,tone:"attention"});
    else {
        const count=evidence.reduce((sum,s)=>sum+s.count,0);
        if(count>0)rows.push({id:"updates",title:"Package updates",state:count+" reported",detail:"Reported by the checked sources. Review package details before taking action.",route:"updates",action:"Review packages",priority:2,tone:"attention"});
    }
    if(notifications.serverEnabled===false)rows.push({id:"notifications",title:"Notifications",state:"Unavailable",detail:"The notification provider is unavailable; an unread count cannot be assessed.",route:"notifications",action:"Open Notifications",priority:3,tone:"muted"});
    else if(Number(notifications.unreadCount)>0)rows.push({id:"notifications",title:"Notifications",state:notifications.unreadCount+" unread",detail:"Messages waiting in your local inbox.",route:"notifications",action:"Open Notifications",priority:3,tone:"muted"});
    return rows.sort((a,b)=>a.priority-b.priority);
}
