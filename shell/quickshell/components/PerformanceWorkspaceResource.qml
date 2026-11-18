import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config
FocusScrollArea {
 id:root;required property var workspace
 readonly property string domain:workspace.activeSection
 readonly property string view:workspace.objectView
 readonly property var perf:workspace.performance
 readonly property var metrics:workspace.metrics
 readonly property var details:perf.details || {}
 readonly property var telemetry:workspace.telemetry
 readonly property var thermal:metrics.temperatureAvailable!==undefined?({available:metrics.temperatureAvailable===true,celsius:metrics.temperatureCelsius,source:"CPU / SoC thermal zones"}):(details.health || {}).temperature || {available:false}
 onDomainChanged:contentY=0
 onViewChanged:contentY=0
 property int coreId:-1
 readonly property var cores:telemetry.cores || []
 readonly property var core:cores.find(c=>c.id===coreId) || cores[0] || null
 readonly property var storage:details.storage || {}
 readonly property var sockets:details.sockets || {}
 readonly property var frequency:telemetry.frequency || {available:false}
 readonly property var memory:telemetry.memory || {swapAvailable:false}
 readonly property var pressure:telemetry.pressure || {available:false}
 readonly property bool thermalView:domain==="cpu" && view==="thermals"
 readonly property bool frequencyView:domain==="cpu" && view==="frequency"
 readonly property bool cpuChart:domain==="cpu" && ["utilisation","frequency","thermals","cores"].includes(view)
 readonly property bool memoryChart:domain==="memory" && view==="physical"
 readonly property bool diskChart:domain==="storage" && view==="io"
 contentHeight:page.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
 Column {id:page;width:root.width-12;spacing:24
  Text {width:parent.width;visible:root.domain==="cpu" || root.domain==="gpu";text:root.domain==="cpu"?(root.details.cpu_inventory || {}).model || root.metrics.cpuModel || "CPU inventory unavailable":(root.details.graphics || {}).device || "Graphics inventory unavailable";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(20*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
  PerformanceWorkspaceFacts {visible:root.domain==="cpu";width:parent.width;rows:[{label:"Logical CPUs",value:(root.details.cpu_inventory || {}).logical_cpus},{label:"Architecture",value:(root.details.cpu_inventory || {}).architecture},{label:"Base frequency",value:(root.telemetry.baseFrequency || {}).available?root.workspace.number(root.telemetry.baseFrequency.mhz/1000,2)+" GHz":"Unavailable",detail:"Reported base; not current clock"}]}
  Flow {visible:root.domain==="cpu" && root.view==="cores";width:parent.width;spacing:8
   Repeater {model:root.cores
    QuietButton {required property var modelData;objectName:"performance-core-"+modelData.id;active:root.core && root.core.id===modelData.id;text:"CPU "+modelData.id+" · "+root.workspace.number(modelData.percent)+(modelData.percent!==null && modelData.percent!==undefined?"%":"");accessibleLabel:text;width:Math.min(parent.width,Math.max(140,implicitWidth));onClicked:root.coreId=modelData.id}
   }
   Text {visible:root.cores.length===0;width:parent.width;text:"Per-core observations are unavailable.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  }
  PerformanceWorkspaceChart {visible:root.cpuChart || root.memoryChart || root.diskChart;width:parent.width;height:300
   label:root.cpuChart?(root.frequencyView?"Current frequency":root.thermalView?"CPU temperature":root.view==="cores"?(root.core?"Logical CPU "+root.core.id:"Logical CPU"):"CPU utilisation"):root.diskChart?"Disk active time":"Physical memory"
   unit:root.frequencyView?"GHz":root.thermalView?"°C":"%"
   currentLabel:root.frequencyView?(root.frequency.available?root.workspace.number(root.frequency.mhz/1000,2)+" GHz":"Unavailable"):root.thermalView?(root.thermal.available?root.workspace.number(root.thermal.celsius)+" °C":"Unavailable"):root.cpuChart?(root.view==="cores"?(root.core?root.workspace.number(root.core.percent)+(root.core.percent!==null && root.core.percent!==undefined?"%":""):"Unavailable"):root.metrics.ready?Math.round(root.metrics.cpuPercent)+"%":"Unavailable"):root.diskChart?(root.metrics.history && root.metrics.history.disk && root.metrics.history.disk.available?root.workspace.number(root.metrics.history.disk.busyPercent)+"%":"Unavailable"):root.metrics.memoryTotalKib>0?Math.round(root.metrics.memoryPercent)+"%":"Unavailable"
   timestamps:root.perf.sampleTimes || [];windowSeconds:root.perf.historySeconds || 60
   values:root.frequencyView?root.perf.frequencyHistory || []:root.thermalView?root.perf.temperatureHistory || []:root.cpuChart?(root.view==="cores" && root.core?root.perf.coreHistory(root.core.id):root.perf.cpuHistory || []):root.diskChart?root.perf.diskBusyHistory || []:root.perf.memoryHistory || []
   maximum:root.frequencyView?root.workspace.peak(values,1):root.thermalView?root.workspace.peak(values,100):100
  }
  Text {visible:root.thermalView || root.diskChart;width:parent.width;text:root.thermalView?(root.thermal.source || "Supported thermal observation")+". A reference temperature alone is not a safety diagnosis.":"Active time of the busiest observed disk; not transfer throughput. "+(root.metrics.history && root.metrics.history.disk && root.metrics.history.disk.busiestDevice || "Device unavailable");wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}

  Column {visible:root.thermalView;width:parent.width;spacing:12
   Repeater {model:(root.details.sensors || {}).temperatures || []
    Column {required property var modelData;width:parent.width;spacing:5
     Text {width:parent.width;text:(modelData.label || "Sensor")+" · "+(modelData.source || "Source unavailable");textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
     Text {width:parent.width;text:root.workspace.number(modelData.celsius)+" °C"+(modelData.critical_celsius!==undefined && modelData.critical_celsius!==null?" · Reported critical reference "+modelData.critical_celsius+" °C":"");wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
    }
   }
  }
  Text {visible:root.frequencyView && Number((root.details.cpu_inventory || {}).max_mhz)>0;width:parent.width;text:"Reported maximum · "+root.workspace.number((root.details.cpu_inventory || {}).max_mhz/1000,2)+" GHz";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  PerformanceWorkspaceTopProcesses {visible:root.domain==="cpu" && ["utilisation","processes"].includes(root.view) || root.domain==="memory" && root.view==="processes";width:parent.width;workspace:root.workspace;sort:root.domain==="memory"?"memory":"cpu";limit:8}
  Column {visible:root.domain==="gpu";width:parent.width;spacing:16
   PerformanceWorkspaceFacts {width:parent.width;rows:[{label:"Driver",value:(root.details.graphics || {}).driver || "Unavailable"},{label:"Device",value:(root.details.graphics || {}).device || "Unavailable"}]}
   Text {objectName:"performance-gpu-unavailable";width:parent.width;text:"Live GPU "+root.view+" is unavailable from the current providers. Detected device inventory does not establish a live measurement.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  }
  PerformanceWorkspaceFacts {visible:root.domain==="memory" && root.view==="physical";width:parent.width;rows:[{label:"Used",value:root.metrics.memoryTotalKib>0?root.workspace.formatBytes(root.metrics.memoryUsedKib*1024):"Unavailable"},{label:"Total",value:root.metrics.memoryTotalKib>0?root.workspace.formatBytes(root.metrics.memoryTotalKib*1024):"Unavailable"},{label:"Available",value:root.metrics.memoryTotalKib>0 && root.metrics.memoryAvailableKib!==undefined?root.workspace.formatBytes(root.metrics.memoryAvailableKib*1024):"Unavailable"}]}
  Column {visible:root.domain==="memory" && root.view==="swap";width:parent.width;spacing:16
   Text {width:parent.width;text:root.memory.swapAvailable?(root.memory.swapTotalKib>0?"Configured swap":"No swap configured"):"Swap counters unavailable";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(20*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink}
   PerformanceWorkspaceFacts {width:parent.width;rows:[{label:"Used",value:root.memory.swapAvailable?root.workspace.formatBytes(root.memory.swapUsedKib*1024):"Unavailable"},{label:"Configured",value:root.memory.swapAvailable?root.workspace.formatBytes(root.memory.swapTotalKib*1024):"Unavailable"}]}
  }
  Column {visible:root.domain==="memory" && root.view==="pressure";width:parent.width;spacing:16
   Text {width:parent.width;text:root.pressure.available?"Memory stall time · PSI some averages":"Memory pressure unavailable";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
   PerformanceWorkspaceFacts {width:parent.width;rows:[{label:"10 seconds",value:root.pressure.available?root.workspace.number(root.pressure.avg10)+"%":"Unavailable",numeric:true},{label:"60 seconds",value:root.pressure.available?root.workspace.number(root.pressure.avg60)+"%":"Unavailable",numeric:true}]}
  }
  Column {visible:root.domain==="storage" && root.view!=="health";width:parent.width;spacing:20
   PerformanceWorkspaceFacts {width:parent.width;rows:[{label:"Root filesystem",value:root.storage.filesystem || "Unavailable",detail:root.storage.mount || ""},{label:"Used",value:root.workspace.formatBytes(root.storage.used_bytes),detail:"of "+root.workspace.formatBytes(root.storage.total_bytes)},{label:"Capacity",value:root.storage.percent!==undefined && root.storage.percent!==null?root.storage.percent+"%":"Unavailable",numeric:true}]}
   Column {visible:root.view==="devices";width:parent.width;spacing:12
    Repeater {model:root.storage.devices || []
     Column {required property var modelData;width:parent.width;spacing:6
      Text {width:parent.width;text:modelData.name+" · "+(modelData.model || "Unknown model");textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
      Text {width:parent.width;text:root.workspace.formatBytes(modelData.size_bytes)+" · "+(modelData.transport || "Unknown transport")+" · "+String(modelData.partition_count ?? "Unknown")+" partitions";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
      Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
     }
    }
    Text {width:parent.width;visible:!(root.storage.devices || []).length;text:"No device inventory returned.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
   }
   PerformanceWorkspaceFacts {visible:root.view==="devices";width:parent.width;rows:[{label:"Root device",value:(root.storage.root_device || {}).name},{label:"Logical sector",value:(root.storage.root_device || {}).logical_sector_bytes},{label:"Physical sector",value:(root.storage.root_device || {}).physical_sector_bytes}]}
   Text {width:parent.width;text:"Read-only filesystem/device inventory · "+(root.storage.source || "Source unavailable");wrapMode:Text.WrapAnywhere;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
  }
  Column {visible:root.domain==="storage" && root.view==="health";width:parent.width;spacing:16
   Text {objectName:"performance-smart-unavailable";width:parent.width;text:"SMART / NVMe health is unavailable from the current read-only providers. Capacity and device inventory do not establish device health.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
   QuietButton {text:"View devices";onClicked:root.workspace.selectView("devices")}
  }
  GridLayout {visible:root.domain==="network" && root.view==="traffic";width:parent.width;columns:width>=680*Config.DirectoryStyle.textScale?2:1;columnSpacing:24;rowSpacing:24
   PerformanceWorkspaceChart {Layout.fillWidth:true;Layout.preferredWidth:1;Layout.minimumWidth:0;Layout.preferredHeight:300;label:"Receive";unit:"KiB/s";currentLabel:root.workspace.trafficAvailable?root.workspace.number(root.metrics.networkRxKib)+" KiB/s":"Unavailable";timestamps:root.perf.sampleTimes || [];values:root.perf.rxHistory || [];maximum:root.workspace.peak(values,10);windowSeconds:root.perf.historySeconds || 60}
   PerformanceWorkspaceChart {Layout.fillWidth:true;Layout.preferredWidth:1;Layout.minimumWidth:0;Layout.preferredHeight:300;label:"Transmit";unit:"KiB/s";currentLabel:root.workspace.trafficAvailable?root.workspace.number(root.metrics.networkTxKib)+" KiB/s":"Unavailable";timestamps:root.perf.sampleTimes || [];values:root.perf.txHistory || [];maximum:root.workspace.peak(values,10);windowSeconds:root.perf.historySeconds || 60}
  }
  Column {visible:root.domain==="network" && root.view==="interfaces";width:parent.width;spacing:18
   PerformanceWorkspaceFacts {width:parent.width;rows:[{label:"Active connection",value:root.workspace.network.label || "Unavailable",detail:root.workspace.network.detail || ""}]}
   Repeater {model:[{key:"interface",label:"Interface"},{key:"state",label:"State"},{key:"kind",label:"Type"},{key:"mtu",label:"MTU"},{key:"ipv4",label:"IPv4"},{key:"ipv6",label:"IPv6"},{key:"gateway",label:"Gateway"}]
    Text {required property var modelData;width:parent.width;text:modelData.label+" · "+String((root.details.network || {})[modelData.key] ?? "Unavailable");textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
   }
   Text {width:parent.width;text:"Active-interface inventory only; not complete interface enumeration.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
  }
  PerformanceWorkspaceFacts {visible:root.domain==="network" && root.view==="connections";width:parent.width;rows:[{label:"TCP established",value:root.sockets.available?(root.sockets.tcp || {}).established:"Unavailable",numeric:true},{label:"TCP listening",value:root.sockets.available?(root.sockets.tcp || {}).listening:"Unavailable",numeric:true},{label:"Sockets / UDP",value:root.sockets.available?String(root.sockets.used)+" / "+String(root.sockets.udp_in_use):"Unavailable"}]}
  Column {visible:root.domain==="network" && root.view==="dns";width:parent.width;spacing:16
   Text {objectName:"performance-dns-unavailable";width:parent.width;text:"DNS resolver inventory is not supplied by the current read-only collector. Traffic and active-interface observations remain available.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
   QuietButton {text:"View interfaces";onClicked:root.workspace.selectView("interfaces")}
  }
 }
}
