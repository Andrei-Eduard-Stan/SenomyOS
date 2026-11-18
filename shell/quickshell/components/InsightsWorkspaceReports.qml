import QtQuick
import "interaction" as Interaction
import QtQuick.Controls
import "../config" as Config
FocusScrollArea {
 id:root;required property var workspace
 property string profile:workspace.readState("reports","profile","overview")
 readonly property var report:workspace.payload("reports").ok?workspace.data("reports"):({})
 readonly property var profiles:[{id:"overview",label:"Overview"},{id:"performance",label:"Performance"},{id:"network",label:"Network"},{id:"power",label:"Power"},{id:"full",label:"Full evidence"}]
 contentHeight:page.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
 Column {id:page;width:root.width-12;spacing:20
  InsightsWorkspaceTitle {width:parent.width;title:"Reports";detail:"Private evidence, collected only when requested";actions:[ContextEvidenceMenu {contextKey:"reports";componentKey:"insights-reports";ownerActive:root.workspace.requestedOpen && !root.workspace.state.modalActive;accessibleLabel:"Report evidence actions";evidenceAvailable:Boolean(root.report.exists);report:({latest:root.report.latest || {},preview:root.report.preview || []});copyLabel:"Copy report preview";textLabel:"Save report preview as text"}]}
  Text {width:parent.width;text:"Choose a scope";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
  Flow {width:parent.width;spacing:8
   Repeater {model:root.profiles
    QuietButton {required property var modelData;objectName:"insights-report-scope-"+modelData.id;text:modelData.label;active:root.profile===modelData.id;Accessible.selected:active;enabled:root.workspace.insights.actionState!=="running";onClicked:{root.profile=modelData.id;root.workspace.remember("reports","profile",root.profile);}}
   }
  }
  Text {width:parent.width;text:"Private files on this device. Nothing is uploaded automatically."+(root.profile==="full"?" Full evidence includes machine identity, processes, services, network and power.":"");wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  Flow {width:parent.width;spacing:8
   QuietButton {objectName:"report-generate";text:root.workspace.insights.actionState==="running"?"Generating…":"Generate report";enabled:root.workspace.insights.actionState!=="running" && !root.workspace.state.modalActive;onClicked:root.workspace.insights.generateReport(root.profile)}
   QuietButton {objectName:"insights-report-open";text:"Open latest";enabled:Boolean(root.report.exists) && root.workspace.insights.actionState!=="running" && !root.workspace.state.modalActive;onClicked:root.workspace.insights.openLatestReport()}
  }
  InsightsWorkspaceStatus {width:parent.width;workspace:root.workspace;route:"reports"}
  IslandRule {width:parent.width;leadingPoint:false}
  InsightsWorkspaceTitle {width:parent.width;title:"Latest preview";detail:root.report.exists?String((root.report.latest || {}).profile_label || "Report")+" · "+String(root.report.history_count || 0)+" retained":"No report has been returned"}
  Text {visible:!root.report.exists;width:parent.width;text:"Choose a scope and generate a report to inspect its evidence here.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  Interaction.ContentMotion {targetItem:preview;context:String((root.report.latest || {}).generated_at || "")+":"+String((root.report.latest || {}).profile || "")+":"+String((root.report.preview || []).length);active:root.workspace.requestedOpen;floorOpacity:0.88}
  EvidenceDocument {id:preview;width:parent.width;visible:Boolean(root.report.exists);lines:root.report.preview || []}
 }
}
