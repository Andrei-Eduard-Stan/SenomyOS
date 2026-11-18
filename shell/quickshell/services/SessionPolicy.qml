import QtQuick
import Quickshell
import Quickshell.Io
import "../config/SessionPolicyPreferences.js" as Preferences

Scope {
    id: root
    property bool active: false
    property bool available: false
    property bool configured: false
    property int lockSeconds: 300
    property int displayOffSeconds: 600
    property bool suspendEnabled: false
    property bool lockBeforeSleep: true
    property bool lidAvailable: false
    property string lidAction: "lock"
    property bool busy: false
    property bool activationRequired: false
    property string message: ""
    property string error: ""

    function refresh() {
        if(query.running || applyProcess.running) return false;
        query.running=true;
        return true;
    }

    function apply(lockMinutes,displayOffMinutes,nextLidAction) {
        if(busy || query.running || applyProcess.running) return false;
        let proposed;
        try {
            proposed=Preferences.validate(lockMinutes,displayOffMinutes,nextLidAction);
        } catch(e) {
            error=e.message;
            return false;
        }
        busy=true; error=""; message="Saving idle policy…";
        applyProcess.command=["python3",Quickshell.shellDir+"/scripts/session-policy.py","apply",
            JSON.stringify(proposed)];
        applyProcess.running=true;
        return true;
    }

    function consume(text,saved) {
        try {
            const value=Preferences.parseResponse(text);
            available=value.available; configured=value.configured;
            lockSeconds=value.lockSeconds; displayOffSeconds=value.displayOffSeconds;
            suspendEnabled=value.suspendEnabled; lockBeforeSleep=value.lockBeforeSleep;
            lidAvailable=value.lidAvailable; lidAction=value.lidAction;
            activationRequired=value.activationRequired;
            error="";
            message=saved ? "Idle policy saved. It takes effect after Hypridle is started or restarted." : "";
            return true;
        } catch(e) {
            error=e.message || "Session policy status is unavailable.";
            message="";
            return false;
        }
    }

    onActiveChanged: if(active) refresh()
    Process {
        id: query
        command: ["python3",Quickshell.shellDir+"/scripts/session-policy.py"]
        stdout: StdioCollector { onStreamFinished: root.consume(text,false) }
    }
    Process {
        id: applyProcess
        stdout: StdioCollector { onStreamFinished: root.consume(text,true) }
        stderr: StdioCollector { id: applyError }
        onExited: (code) => {
            root.busy=false;
            if(code !== 0 && !root.error) {
                root.error=applyError.text.trim() || "Idle policy preferences could not be saved.";
                root.message="";
            }
        }
    }
}
