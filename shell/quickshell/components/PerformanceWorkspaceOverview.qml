import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config
FocusScrollArea {
 id:root;required property var workspace
 readonly property bool split:width>=980*Config.DirectoryStyle.textScale
 contentHeight:page.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
 Column {id:page;width:root.width-12;spacing:24
  GridLayout {width:parent.width;columns:root.split?2:1;columnSpacing:28;rowSpacing:24
   Column {Layout.fillWidth:true;Layout.preferredWidth:2;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop;spacing:20
    GridLayout {width:parent.width;columns:width>=600*Config.DirectoryStyle.textScale?2:1;columnSpacing:20;rowSpacing:20
     PerformanceWorkspaceChart {Layout.fillWidth:true;Layout.preferredWidth:1;Layout.minimumWidth:0;Layout.preferredHeight:240;label:"CPU";currentLabel:root.workspace.metrics.ready?Math.round(root.workspace.metrics.cpuPercent)+"%":"Unavailable";timestamps:root.workspace.performance.sampleTimes || [];values:root.workspace.performance.cpuHistory || [];windowSeconds:root.workspace.performance.historySeconds || 60}
     PerformanceWorkspaceChart {Layout.fillWidth:true;Layout.preferredWidth:1;Layout.minimumWidth:0;Layout.preferredHeight:240;label:"Memory";currentLabel:root.workspace.metrics.memoryTotalKib>0?Math.round(root.workspace.metrics.memoryPercent)+"%":"Unavailable";timestamps:root.workspace.performance.sampleTimes || [];values:root.workspace.performance.memoryHistory || [];windowSeconds:root.workspace.performance.historySeconds || 60}
    }
    GridLayout {width:parent.width;columns:width>=600*Config.DirectoryStyle.textScale?2:1;columnSpacing:20;rowSpacing:20
     PerformanceWorkspaceChart {Layout.fillWidth:true;Layout.preferredWidth:1;Layout.minimumWidth:0;Layout.preferredHeight:200;compact:true;label:"Receive";unit:"KiB/s";currentLabel:root.workspace.trafficAvailable?root.workspace.number(root.workspace.metrics.networkRxKib)+" KiB/s":"Unavailable";timestamps:root.workspace.performance.sampleTimes || [];values:root.workspace.performance.rxHistory || [];maximum:root.workspace.peak(values,10);windowSeconds:root.workspace.performance.historySeconds || 60}
     PerformanceWorkspaceChart {Layout.fillWidth:true;Layout.preferredWidth:1;Layout.minimumWidth:0;Layout.preferredHeight:200;compact:true;label:"Transmit";unit:"KiB/s";currentLabel:root.workspace.trafficAvailable?root.workspace.number(root.workspace.metrics.networkTxKib)+" KiB/s":"Unavailable";timestamps:root.workspace.performance.sampleTimes || [];values:root.workspace.performance.txHistory || [];maximum:root.workspace.peak(values,10);windowSeconds:root.workspace.performance.historySeconds || 60}
    }
   }
   PerformanceWorkspaceTopProcesses {Layout.fillWidth:true;Layout.preferredWidth:1;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop;workspace:root.workspace;limit:6}
  }
  IslandRule {width:parent.width;leadingPoint:false}
  PerformanceWorkspaceFacts {width:parent.width;rows:[{label:"Power",value:root.workspace.battery.label || "Unavailable",detail:root.workspace.battery.detail || ""},{label:"Root filesystem",value:root.workspace.performance.details.storage && root.workspace.performance.details.storage.percent!==undefined && root.workspace.performance.details.storage.percent!==null?root.workspace.performance.details.storage.percent+"% used":"Unavailable",detail:root.workspace.formatBytes((root.workspace.performance.details.storage || {}).used_bytes)+" / "+root.workspace.formatBytes((root.workspace.performance.details.storage || {}).total_bytes)},{label:"User service health",value:(root.workspace.performance.details.services || {}).available?String(root.workspace.performance.details.services.failed_total)+" failed":"Unavailable",detail:root.workspace.metrics.uptimeLabel?"Uptime · "+root.workspace.metrics.uptimeLabel:"Uptime unavailable"}]}
 }
}
