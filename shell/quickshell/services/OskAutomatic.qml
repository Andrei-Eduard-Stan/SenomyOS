import QtQuick
import Quickshell
import Quickshell.Io
Scope {
 id:root
 required property var controller
 property bool monitoring:true
 property alias mode: policy.mode
 readonly property string status: settingMode ? "Saving keyboard activation preference…" : modeError || policy.status
 property string modeError:""
 property string requestedMode:""
 property string interpreter:"python3"
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
  requestedMode=next;modeError="";
  settingMode=true;saveMode.exec([interpreter,Quickshell.shellDir+"/scripts/osk-automatic.py","set-mode",next]);return true;
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
        stdout:StdioCollector {id:modeOutput}
        onExited:(code,status)=>{
            root.settingMode=false;
            try {
                const result=JSON.parse(modeOutput.text);
                if(code!==0||result.ok!==true||result.mode!==root.requestedMode)throw new Error("Unverified mode receipt");
                root.mode=result.mode;root.modeError="";
                policy.stoppedByUser=false;policy.manualPinned=false;policy.dismissed=false;
                root.reconcile();monitor.running=false;Qt.callLater(()=>{if(root.monitoring&&!!Quickshell.env("WAYLAND_DISPLAY"))monitor.running=true;});
            }catch(_){root.modeError="Keyboard activation preference could not be verified. Check current mode before retrying; automatic focus ownership was not reset.";}
        }
    }
    Timer {interval:200;running:root.settingMode&&!saveMode.running;onTriggered:{root.settingMode=false;root.modeError="Keyboard preference helper could not start. No mode request was submitted; check Python and retry.";}}
}
