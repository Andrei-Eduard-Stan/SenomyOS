import QtQuick
import Quickshell
import Quickshell.Io
Scope {
 id:root
 required property var controller
 property bool monitoring:true
 property alias mode: policy.mode
 readonly property string status: policy.status
 property alias snapshot: policy.snapshot
 readonly property bool available:policy.available
 readonly property bool eligible:policy.eligible
 property alias settingMode: policy.settingMode
 OskAutomaticPolicy {id:policy;controller:root.controller}
 function textFocusEvent(active) {if(!active)policy.dismissed=false;Qt.callLater(()=>policy.reconcile());}
 function consume(line){policy.consume(line);}
 function reconcile(){policy.reconcile();}
 function setMode(next) {
  if(settingMode || ["auto","manual"].indexOf(next)<0)return false;
  policy.stoppedByUser=false;policy.manualPinned=false;policy.dismissed=false;
  settingMode=true;saveMode.command=["python3",Quickshell.shellDir+"/scripts/osk-automatic.py","set-mode",next];saveMode.running=true;return true;
 }
    Process {
        id: monitor;running:root.monitoring && !!Quickshell.env("WAYLAND_DISPLAY")
        command:["python3",Quickshell.shellDir+"/scripts/osk-automatic.py","stream"]
        stdout:SplitParser {onRead:data=>root.consume(data)}
        onExited:(code,status)=>{root.snapshot=null;root.reconcile();if(root.monitoring)retry.restart();}
    }
    Timer {id:retry;interval:3000;onTriggered:if(root.monitoring)monitor.running=true}
    Process {
        id:saveMode
        stdout:StdioCollector {onStreamFinished:{
            try {const r=JSON.parse(text);if(r.ok===true && ["auto","manual"].indexOf(r.mode)>=0)root.mode=r.mode;}catch(_){}
        }}
        onExited:(code,status)=>{root.settingMode=false;root.reconcile();monitor.running=false;Qt.callLater(()=>{if(root.monitoring)monitor.running=true;});}
    }
}
