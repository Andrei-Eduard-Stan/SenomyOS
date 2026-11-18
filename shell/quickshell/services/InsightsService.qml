import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property bool active: false
    property string section: "briefing"
    property alias payloads: requests.payloads
    property alias statuses: requests.statuses
    readonly property string error: requests.error
    readonly property string actionState: requests.actionState
    readonly property string actionMessage: requests.actionMessage
    readonly property string actionDomain: requests.actionDomain
    readonly property bool busy: requests.busy
    readonly property string sourceRoot: String(Quickshell.env("SENOMY_SOURCE_ROOT") || "")
    function refresh(route,result) {return requests.refresh(route,result);}
    function tasksFor(domain) {return requests.tasksFor(domain);}
    function runTask(domain,id) {return requests.runTask(domain,id);}
    function runUpdate(kind) {return requests.runUpdate(kind);}
    function openMaintenance() {return requests.openMaintenance();}
    function generateReport(profile) {return requests.generateReport(profile);}
    function openLatestReport() {return requests.openLatestReport();}
    InsightsRequests {
        id: requests
        active: root.active;section:root.section;sourceRoot:root.sourceRoot
        queryRunner:queryProcess;actionRunner:actionProcess
    }
    Timer {
        interval: root.section === "timeline" ? 5000 : 15000
        repeat:true;running:root.active && ["briefing","timeline","updates"].indexOf(root.section)>=0
        onTriggered: root.refresh(root.section,false)
    }
    Process {
        id: queryProcess
        stdout:StdioCollector {id:queryOutput}
        onExited:code=>requests.queryCompleted(code,queryOutput.text)
    }
    Process {
        id: actionProcess
        environment: ({SENOMY_SOURCE_ROOT:root.sourceRoot})
        stdout:StdioCollector {id:actionOutput}
        onExited:code=>requests.actionCompleted(code,actionOutput.text)
    }
}
