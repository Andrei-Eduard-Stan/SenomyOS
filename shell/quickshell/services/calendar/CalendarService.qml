import QtQuick
import Quickshell
import Quickshell.Io
import "." as CalendarState

Scope {
    id: root
    property bool active: false
    property bool available: false
    property string error: ""
    property string errorOperation:""
    property string message: ""
    property var snapshot: ({sources: [], preferences: {}, reminders: [], eventCount: 0})
    property var entries: []
    property var briefingEntries: []
    property bool briefingTruncated: false
    property var briefingConsumers: ({})
    readonly property bool briefingActive: Object.keys(briefingConsumers).length>0
    function setBriefingConsumer(id,wanted) {
        const next=Object.assign({},briefingConsumers);
        if(wanted)next[id]=true;else delete next[id];
        briefingConsumers=next;
    }
    property int briefingDays: 30
    readonly property string briefingStart: CalendarState.Navigation.todayKey
    readonly property string briefingEnd: CalendarState.Navigation.key(CalendarState.Navigation.dateAt(CalendarState.Navigation.today.getFullYear(),CalendarState.Navigation.today.getMonth(),CalendarState.Navigation.today.getDate()+briefingDays))
    property bool truncated: false
    property string search: ""
    property string sourceFilter: ""
    property string queryStart: CalendarState.Navigation.key(CalendarState.Navigation.monthDays[0])
    property string queryEnd: CalendarState.Navigation.key(CalendarState.Navigation.dateAt(CalendarState.Navigation.monthDays[0].getFullYear(), CalendarState.Navigation.monthDays[0].getMonth(), CalendarState.Navigation.monthDays[0].getDate() + 42))
    property var pending: ({})
    function abandonPending() {
        const requests=pending;pending=({});
        Object.keys(requests).forEach(id=>{
            const operation=requests[id].operation;
            requestFinished(id,operation,{error:"Calendar connection was lost; the outcome is unverified. Reconnect and inspect saved data before retrying."},false);
        });
    }
    readonly property bool busy: Object.values(pending).some(item => !["query","snapshot","detail","draftSave","draftGet","draftDiscard"].includes(item.operation))
    readonly property var sources: snapshot.sources || []
    readonly property var preferences: snapshot.preferences || {}
    readonly property var reminders: snapshot.reminders || []
    property int serial: 0
    property var requestedEvent:null
    property var requestedCompose:null
    signal composeRequested(string kind,string date,string screenName)
    function compose(kind,date,screenName) {if(!["event","note"].includes(kind)||!/^\d{4}-\d{2}-\d{2}$/.test(date))return;requestedCompose={kind:kind,date:date};composeRequested(kind,date,screenName||"");}
    signal requestFinished(string requestId, string operation, var result, bool ok)
    signal openEventRequested(string source, string uid, string rid)
    function open(entry) {requestedEvent=entry;openEventRequested(entry.source,entry.uid,entry.rid||"");}
    function newId() { return "calendar-" + Date.now() + "-" + (++serial) + "-" + Math.random().toString(16).slice(2); }
    function request(operation, args) {
        if (!socket.connected) { error = "Calendar service unavailable. Saved data is retained."; return ""; }
        const id = newId();
        const next = Object.assign({}, pending); next[id] = {operation: operation, args: args || {}, started: Date.now()}; pending = next;
        socket.write(JSON.stringify({id: id, operation: operation, args: args || {}}) + "\n"); socket.flush();
        return id;
    }
    function refresh() {
        if (!available) return;
        request("snapshot", {});
        if (active) queryTimer.restart();
    }
    function receive(line) {
        let payload;
        try { payload = JSON.parse(line); } catch (_) { error = "Invalid calendar service response."; return; }
        if (payload.type === "changed") { refresh(); return; }
        if (payload.type === "openEvent") { open({source:payload.source,uid:payload.uid,rid:payload.rid||""}); return; }
        const meta = pending[payload.id];
        if (!meta) return;
        const next = Object.assign({}, pending); delete next[payload.id]; pending = next;
        if (!payload.ok) { error = payload.error || "Calendar operation failed.";errorOperation=meta.operation; }
        else {
            if (errorOperation===meta.operation || !["query","snapshot","detail","draftSave","draftGet","draftDiscard"].includes(meta.operation)) {error="";errorOperation="";}
            if (meta.operation === "snapshot") {
                snapshot = payload.result;
                const p = preferences;
                CalendarState.Navigation.dateFormat = p.dateFormat || "iso";
                CalendarState.Navigation.weekStartOverride = p.weekStart === undefined ? -1 : p.weekStart;
                // Today is the local SystemClock day, not a cached snapshot in
                // the event display zone. Keep the override for isolated tests.
            } else if (meta.operation === "query" && meta.args.view === "briefing") {
                if (meta.args.start===briefingStart && meta.args.end===briefingEnd && meta.args.search===search && meta.args.source===sourceFilter) {
                    briefingEntries=payload.result.items||[];briefingTruncated=!!payload.result.truncated;
                }
            } else if (meta.operation === "query" && !meta.args.view && meta.args.start === queryStart && meta.args.end === queryEnd && meta.args.search === search && meta.args.source === sourceFilter) { entries = payload.result.items || []; truncated = !!payload.result.truncated; }
            else if (meta.operation === "query") { /* Independent view consumes requestFinished. */ }
            else if (!["detail","draftSave","draftGet","draftDiscard"].includes(meta.operation)) message = payload.result.state || "Saved";
            if (meta.operation === "draftSave") snapshot = Object.assign({},snapshot,{hasDraft:true});
            if (meta.operation === "draftDiscard") refresh();
        }
        requestFinished(payload.id, meta.operation, payload.ok ? (payload.result || {}) : {error:payload.error || error,fieldErrors:payload.fieldErrors || {}}, !!payload.ok);
    }
    onActiveChanged: if(active)refresh()
    onBriefingActiveChanged: if(active)queryTimer.restart()
    onBriefingStartChanged: if(active&&briefingActive)queryTimer.restart()
    onBriefingEndChanged: if(active&&briefingActive)queryTimer.restart()
    onQueryStartChanged: if (active) queryTimer.restart()
    onQueryEndChanged: if (active) queryTimer.restart()
    onSearchChanged: if (active) queryTimer.restart()
    onSourceFilterChanged: if (active) queryTimer.restart()
    Timer {
        id: queryTimer; interval: 120
        onTriggered: if (root.available && root.active) {
            if(!root.briefingActive)root.request("query", {start:root.queryStart, end:root.queryEnd, search:root.search, source:root.sourceFilter});
            else root.request("query", {start:root.briefingStart,end:root.briefingEnd,search:root.search,source:root.sourceFilter,view:"briefing"});
        }
    }
    Socket {
        id: socket
        path: String(Quickshell.env("XDG_RUNTIME_DIR") || "") + "/senomyos-calendar/calendar.sock"
        connected: String(Quickshell.env("XDG_RUNTIME_DIR") || "").length > 0
        parser: SplitParser { onRead: data => root.receive(data) }
        onConnectionStateChanged: {
            root.available = connected;
            if (connected) { root.error = ""; root.refresh(); }
            else { root.error = "Calendar service unavailable. Saved data is retained.";root.abandonPending(); }
        }
        onError: {root.available=false;root.abandonPending();}
    }
    Timer { interval: 5000; running: !socket.connected; repeat: true; onTriggered: if (String(Quickshell.env("XDG_RUNTIME_DIR") || "")) socket.connected = true }
    Timer {
        interval: 1000; running: Object.keys(root.pending).length > 0; repeat: true
        onTriggered: {
            const next = Object.assign({},root.pending);
            for (const id of Object.keys(next)) if (Date.now() - next[id].started > 45000) {
                const op = next[id].operation; delete next[id];
                root.error = "Calendar result unverified. Reload before retrying.";
                root.requestFinished(id, op, {}, false);
            }
            root.pending = next;
        }
    }
}
