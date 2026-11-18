pragma Singleton
import QtQuick

// Opt-in bounded observations of queued frames. Does not drive rendering.
QtObject {
    id: root
    property bool recording: false
    property int revision: 0
    property var transitions: []
    property int dropped: 0
    property double startedAt: 0
    function start() {
        recording = false; ++revision; transitions = []; dropped = 0;
        startedAt = Date.now(); recording = true; deadline.restart();
    }
    function stop() { recording = false; deadline.stop(); }
    function begin(key, origin) {
        if (!recording) return null;
        if (transitions.length >= 64) { ++dropped; return null; }
        const row = {key:key,origin:origin,requestedAt:Date.now(),firstFrameMs:null,pageReadyMs:null,lastFrameAt:0,intervals:[],closed:false};
        transitions.push(row); return row;
    }
    function frame(row) {
        if (!recording || !row || transitions.indexOf(row) < 0 || row.closed) return;
        const now = Date.now();
        if (row.firstFrameMs === null) row.firstFrameMs = Math.max(0,now-row.requestedAt);
        if (row.lastFrameAt > 0 && row.intervals.length < 2048) row.intervals.push(Math.max(0,now-row.lastFrameAt));
        row.lastFrameAt = now;
    }
    function pageReady(key) {
        if (!recording) return;
        for (let i=transitions.length-1;i>=0;--i) {
            const row=transitions[i];
            if (row.key===key && !row.closed) { row.pageReadyMs=Math.max(0,Date.now()-row.requestedAt);return; }
        }
    }
    function percentile(values, fraction) {
        if (!values.length) return null;
        const sorted=values.slice().sort((a,b)=>a-b);
        return sorted[Math.max(0,Math.ceil(sorted.length*fraction)-1)];
    }
    function snapshot() {
        return {schema_version:1,recording:recording,startedAt:startedAt,droppedTransitions:dropped,
            limits:["Opt-in 30-second capture; at most 64 transitions and 2048 intervals each.",
                "Window frameSwapped callbacks timestamp frames queued for presentation, not hardware input-to-photon or GPU duration.",
                "Idle gaps are retained; interval percentiles are meaningful only for a continuously animating scenario.",
                "First-frame delay starts at a QML request/content change; probe-start and host-change origins are not input latency.",
                "A queued frame does not prove new content is visible; page-ready time is reported separately. Timestamps use millisecond wall-clock callbacks."],
            transitions:transitions.map(row=>({key:row.key,origin:row.origin,firstFrameMs:row.firstFrameMs,pageReadyMs:row.pageReadyMs,
                frameIntervalsMs:row.intervals.slice(),p50IntervalMs:percentile(row.intervals,.5),p95IntervalMs:percentile(row.intervals,.95),
                maxIntervalMs:row.intervals.length?Math.max.apply(null,row.intervals):null,closed:row.closed}))};
    }
    property Timer deadline: Timer { interval:30000; onTriggered:root.stop() }
}
