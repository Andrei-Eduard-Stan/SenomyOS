import QtQuick
import QtQuick.Controls
import "../config" as Config
FocusScrollArea {
 id:root;required property var workspace
 readonly property var perf:workspace.performance
 property string profile:workspace.readState("benchmarks","profile","quick")
 readonly property var plan:perf.benchmarkPlans[profile] || null
 readonly property var status:perf.benchmarkStatus || {}
 contentHeight:page.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
 ConfirmationFocus {view:root;actions:root.perf;actionState:root.perf.benchmarkActionState;cancelButton:cancel}
 function back(){if(perf.benchmarkActionState!=="pending")return false;perf.cancelBenchmarkRequest();return true;}
 Column {id:page;width:root.width-12;spacing:20
  InsightsWorkspaceTitle {width:parent.width;title:root.status.state_label || root.status.state || "Status unavailable";detail:root.status.message || "No benchmark status returned";actions:[QuietButton {objectName:"benchmark-refresh";text:"Refresh status";enabled:root.perf.benchmarkActionState!=="running";onClicked:root.perf.loadBenchmarks()}]}
  Text {width:parent.width;text:"Finite, unprivileged workloads can create sustained CPU, memory, compression, storage and process-launch load. Review the plan before starting.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  Flow {visible:root.perf.benchmarkActionState!=="pending";width:parent.width;spacing:8
   Repeater {model:[{id:"quick",label:"Quick"},{id:"standard",label:"Standard"}]
    QuietButton {required property var modelData;objectName:"benchmark-scope-"+modelData.id;text:modelData.label;active:root.profile===modelData.id;enabled:root.status.state!=="running" && root.perf.benchmarkActionState!=="running";onClicked:{root.profile=modelData.id;root.workspace.remember("benchmarks","profile",root.profile);}}
   }
  }
  PerformanceWorkspaceFacts {visible:root.perf.benchmarkActionState!=="pending";width:parent.width;rows:[{label:"Estimated duration",value:root.plan?"About "+root.plan.estimated_seconds+" seconds":"Plan unavailable"},{label:"Thermal stop",value:root.plan?root.plan.thermal_limit_c+" °C":"Unavailable",detail:"From the selected benchmark plan"}]}
  Flow {visible:root.perf.benchmarkActionState!=="pending";width:parent.width;spacing:8
   QuietButton {objectName:"benchmark-request";text:"Review benchmark";enabled:!!root.plan && root.status.state!=="running" && root.perf.benchmarkActionState!=="running" && !root.workspace.state.modalActive;onClicked:root.perf.requestBenchmark(root.profile)}
   QuietButton {objectName:"benchmark-stop";text:"Stop workload";warning:true;enabled:root.status.state==="running" && root.perf.benchmarkActionState!=="running";onClicked:root.perf.stopBenchmark()}
  }
  Column {visible:root.perf.benchmarkActionState==="pending";width:parent.width;spacing:14
   Text {width:parent.width;text:"Start "+root.perf.pendingBenchmark+" benchmark?";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(22*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
   Text {width:parent.width;text:"This intentionally starts a bounded workload. It can affect responsiveness, temperature and battery use. Thermal and permission checks stay in force.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
   Flow {width:parent.width;spacing:8
    QuietButton {id:cancel;objectName:"benchmark-cancel";text:"Cancel";width:Math.min(parent.width,Math.max(120,implicitWidth));onClicked:root.perf.cancelBenchmarkRequest()}
    QuietButton {objectName:"benchmark-confirm";text:"Start bounded workload";warning:true;width:Math.min(parent.width,Math.max(230,implicitWidth));wrapLabel:true;onClicked:root.perf.confirmBenchmark()}
   }
  }
  Text {visible:root.perf.benchmarkActionState==="running";width:parent.width;text:"Sending request. Inspect the observed workload status.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  Text {visible:root.status.state==="running" && root.status.progress!==undefined;width:parent.width;text:String(root.status.progress)+"% observed progress";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
  IslandRule {width:parent.width;leadingPoint:false}
  Text {text:"Workload log";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
  Text {visible:!(root.status.logs || []).length;width:parent.width;text:"No workload log returned.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  Repeater {model:root.status.logs || []
   Text {required property string modelData;width:parent.width;text:modelData;textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
  }
 }
}
