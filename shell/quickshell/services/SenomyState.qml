import QtQuick
import Quickshell
import "SystemHealth.js" as Health

Scope {
    id: root
    required property var shellState
    required property var media
    required property var battery
    required property var network
    required property var metrics
    required property var notifications
    property var performance: null
    property var insights: null
    property var resolver: Health.createResolver()
    property var events: []
    property string previousBenchmarkState: ""
    property var observation: ({id:"telemetry",state:"unavailable",message:"Waiting for system telemetry",priority:300})
    readonly property string state: observation.state
    readonly property string message: observation.message
    readonly property string attentionState: observation.priority >= 500 ? "warning" : "clear"
    readonly property string systemHealth: state === "unavailable" ? "unavailable" : attentionState === "warning" ? "warning" : "nominal"
    readonly property bool expectedLoad: !!(performance && performance.benchmarkStatus.state === "running")
    function refresh() {
        const now=Date.now();
        events=events.filter(e=>e.expiresAt>now);
        const next=Health.resolve(resolver,metrics,battery,network,events,expectedLoad,now);
        if(next && (next.id!==observation.id || next.message!==observation.message)) observation=next;
    }
    function publishEvent(id, text, actionRequired) {
        const now=Date.now();
        events=events.filter(e=>e.id!==id && e.expiresAt>now).slice(-15).concat([{
            id:id,state:actionRequired ? "action" : "event",priority:actionRequired ? 400 : 300,
            message:text,expiresAt:now+(actionRequired ? 60000 : 15000)
        }]);
        refresh();
    }
    Connections {
        target: root.battery
        function onPercentageChanged() { root.refresh(); }
        function onOnBatteryChanged() { root.refresh(); }
    }
    Connections {
        target: root.insights
        function onActionStateChanged() {
            if(root.insights.actionState==="succeeded") root.publishEvent("operation-complete","System task completed",false);
            else if(root.insights.actionState==="failed") root.publishEvent("operation-failed","System task failed · review Insights",true);
        }
    }
    Connections {
        target: root.performance
        function onBenchmarkStatusChanged() {
            const status=root.performance.benchmarkStatus.state;
            if(status!==root.previousBenchmarkState && (status==="completed" || status==="succeeded")) root.publishEvent("benchmark-complete","Benchmark completed",false);
            root.previousBenchmarkState=status;
        }
    }
    Timer { interval:1000; running:true; repeat:true; triggeredOnStart:true; onTriggered:root.refresh() }
}
