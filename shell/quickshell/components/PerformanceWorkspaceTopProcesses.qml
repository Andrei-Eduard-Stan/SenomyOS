import QtQuick
import "../config" as Config
import "DirectoryFreshness.js" as Freshness
Column {
 id:root;required property var workspace
 property int limit:5
 property string sort:"cpu"
 readonly property var rows:(workspace.performance.processes || []).slice().sort((a,b)=>Number(b[sort==="memory"?"memory_mib":"cpu_percent"] || 0)-Number(a[sort==="memory"?"memory_mib":"cpu_percent"] || 0)).slice(0,limit)
 spacing:8
 InsightsWorkspaceTitle {width:parent.width;title:"Top processes";detail:workspace.performance.processesObservedAt>0?"Observed "+Freshness.ageLabel(workspace.performance.processesObservedAt,workspace.now):"Waiting for process samples";actions:[QuietButton {text:"All";accessibleLabel:"Open process manager";onClicked:root.workspace.navigate("processes")}]}
 Row {width:parent.width;spacing:8
  Text {width:Math.max(1,parent.width-144);text:"Process";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
  Text {width:64;text:"CPU %";horizontalAlignment:Text.AlignRight;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
  Text {width:64;text:"MiB";horizontalAlignment:Text.AlignRight;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
 }
 Repeater {model:root.rows
  QuietButton {id:row;required property var modelData;width:parent.width;height:Config.QuickPanelStyle.target;accessibleLabel:"Inspect "+modelData.name+", PID "+modelData.pid;background.visible:visualFocus || down;onClicked:root.workspace.inspectProcess(modelData)
   contentItem:Row {spacing:8
    Text {width:Math.max(1,parent.width-144);height:parent.height;text:row.modelData.name;textFormat:Text.PlainText;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
    Text {width:64;height:parent.height;text:root.workspace.number(row.modelData.cpu_percent);verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.ink}
    Text {width:64;height:parent.height;text:root.workspace.number(row.modelData.memory_mib);verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
   }
  }
 }
 Text {width:parent.width;visible:root.rows.length===0;text:"No process samples returned.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
}
