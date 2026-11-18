.pragma library

// Pure resolver; monotonic sample times are supplied by its owner/tests.
// Expansion, media titles and notification counts never own this state.
function candidates(metrics, battery, network, active, expectedLoad) {
    active = active || {};
    const out = [];
    function add(id, state, priority, message, condition, delay) {
        if (condition) out.push({id:id,state:state,priority:priority,message:message,delay:delay||0});
    }
    const onBattery = battery.available && battery.onBattery && battery.chargeAvailable !== false && Number.isFinite(battery.percentage) && battery.percentage >= 0;
    add("battery-critical","critical",600,"Battery critical · save your work and connect power",onBattery && battery.percentage <= (active["battery-critical"] ? 0.10 : 0.08));
    add("memory-critical","critical",600,"Memory nearly full · review system load",metrics.memoryTotalKib>0 && metrics.memoryPercent >= (active["memory-critical"] ? 95 : 98));
    add("battery-low","battery-low",500,"Battery low. Get us a charger.",onBattery && battery.percentage <= (active["battery-low"] ? 0.25 : 0.20));
    add("memory-high","warning",500,"RAM pressure · review memory usage",metrics.memoryTotalKib>0 && metrics.memoryPercent >= (active["memory-high"] ? 88 : 92),5000);
    add("cpu-high","warning",500,"CPU load sustained · review running tasks",metrics.ready && metrics.cpuPercent >= (active["cpu-high"] ? 80 : 90) && !expectedLoad,10000);
    add("network","offline",500,"Network connection degraded",network.available && ["None","Limited","Portal"].indexOf(network.connectivityName)>=0,3000);
    add("telemetry","unavailable",300,"System telemetry unavailable",!metrics.ready);
    add("expected-load","active",200,"High load — expected benchmark",expectedLoad);
    add("power","charging",100,"Power connected · system monitoring active",battery.available && !battery.onBattery);
    add("nominal","idle",100,"System steady",true);
    return out;
}
function createResolver() { return {since:{},active:{},winner:null}; }
function resolve(model, metrics, battery, network, events, expectedLoad, now) {
    const next = candidates(metrics,battery,network,model.active,expectedLoad);
    const since={}, active={}, eligible=[];
    for (const c of next) {
        since[c.id]=model.since[c.id] === undefined ? now : model.since[c.id];
        if(model.active[c.id] || now-since[c.id]>=c.delay) { active[c.id]=true;eligible.push(c); }
    }
    for(const e of events || []) if(e.expiresAt>now) eligible.push(e);
    const previous=model.winner;
    eligible.sort((a,b)=>b.priority-a.priority || (previous && a.id===previous.id ? -1 : previous && b.id===previous.id ? 1 : 0));
    model.since=since;model.active=active;model.winner=eligible[0];
    return model.winner;
}
// Compatibility for existing instantaneous fixture callers.
function observation(metrics,battery,network) { return candidates(metrics,battery,network,{},false).sort((a,b)=>b.priority-a.priority)[0]; }
