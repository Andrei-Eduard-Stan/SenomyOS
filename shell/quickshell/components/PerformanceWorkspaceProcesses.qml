import QtQuick
import QtQuick.Controls
import "../config" as Config
FocusScope {
 id:root;objectName:"process-manager";required property var workspace
 readonly property var perf:workspace.performance
 property string query:workspace.readState("processes","query","")
 property int focusedPid:0
 readonly property bool inspecting:perf.selectedProcessPid>0
 readonly property bool split:width>=1000*Config.DirectoryStyle.textScale
 readonly property var filtered:(perf.processes || []).filter(p=>!query.trim() || [p.name,p.pid,p.user].join(" ").toLocaleLowerCase().includes(query.trim().toLocaleLowerCase()))
 function back(){return inspecting?inspector.back():false;}
 function focusRow(index,reason){if(!filtered.length)return;const next=Math.max(0,Math.min(index,filtered.length-1));list.currentIndex=next;list.positionViewAtIndex(next,ListView.Contain);list.forceLayout();const row=list.itemAtIndex(next);if(row){focusedPid=Number(row.modelData.pid);row.focusReason=reason===undefined?Qt.TabFocusReason:reason;row.forceActiveFocus(row.focusReason);}}
 onFilteredChanged:Qt.callLater(function(){const keep=filtered.findIndex(p=>Number(p.pid)===focusedPid);const owns=list.activeFocus || list.currentItem && list.currentItem.activeFocus;list.currentIndex=Math.max(0,keep>=0?keep:Math.min(list.currentIndex,filtered.length-1));if(owns)focusRow(list.currentIndex);})
 Column {id:toolbar;visible:root.split || !root.inspecting;width:parent.width;spacing:10
  InsightsWorkspaceSearch {objectName:"process-search";width:parent.width;placeholderText:"Search name, PID or user";text:root.query;onTextEdited:{root.query=text;root.workspace.remember("processes","query",text);}Accessible.name:"Search process samples"}
  Flow {width:parent.width;spacing:8
   Repeater {model:[{id:"cpu",label:"CPU ↓"},{id:"memory",label:"Memory ↓"},{id:"name",label:"Name A–Z"}]
    QuietButton {required property var modelData;objectName:"process-sort-"+modelData.id;text:modelData.label;active:root.perf.processSort===modelData.id;Accessible.checkable:true;Accessible.checked:active;enabled:!root.workspace.state.modalActive;onClicked:root.perf.configureProcesses("sort",modelData.id)}
   }
   Repeater {model:[{id:"all",label:"All"},{id:"user",label:"Mine"},{id:"active",label:"Active"},{id:"heavy",label:"Heavy"}]
    QuietButton {required property var modelData;objectName:"process-filter-"+modelData.id;text:modelData.label;active:root.perf.processFilter===modelData.id;Accessible.checkable:true;Accessible.checked:active;enabled:!root.workspace.state.modalActive;onClicked:root.perf.configureProcesses("filter",modelData.id)}
   }
  }
  Text {width:parent.width;text:root.filtered.length+" shown · "+String(root.perf.processSummary.process_count ?? "Unknown")+" total · "+String(root.perf.processSummary.thread_count ?? "Unknown")+" threads · sampled view";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
 }
 Item {y:toolbar.visible?toolbar.height+12:0;width:parent.width;height:Math.max(1,parent.height-y)
  Item {id:table;objectName:"process-manager-table";visible:root.split || !root.inspecting;width:root.inspecting && root.split?parent.width-inspector.width-24:parent.width;height:parent.height
   readonly property bool roomy:width>=680*Config.DirectoryStyle.textScale
   readonly property real usableWidth:Math.max(1,width-12)
   readonly property real numberWidth:Math.min(100*Config.DirectoryStyle.textScale,usableWidth*.18)
   readonly property real nameWidth:Math.max(1,usableWidth-20-2*numberWidth-24-(roomy?100*Config.DirectoryStyle.textScale:0))
   Row {id:labels;x:10;width:table.usableWidth-20;height:32;spacing:8
    Text {width:table.nameWidth;height:parent.height;text:"Process";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
    Text {visible:table.roomy;width:100*Config.DirectoryStyle.textScale;height:parent.height;text:"PID";horizontalAlignment:Text.AlignRight;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
    Text {width:table.numberWidth;height:parent.height;text:"CPU %";horizontalAlignment:Text.AlignRight;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
    Text {width:table.numberWidth;height:parent.height;text:"MiB";horizontalAlignment:Text.AlignRight;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
   }
   ListView {id:list;objectName:"process-manager-list";y:labels.height;width:parent.width;height:Math.max(1,parent.height-y);clip:true;model:root.filtered;boundsBehavior:Flickable.StopAtBounds;keyNavigationEnabled:false;activeFocusOnTab:true;ScrollBar.vertical:ShellScrollBar {}
    onActiveFocusChanged:if(activeFocus && currentItem && !currentItem.activeFocus)Qt.callLater(()=>root.focusRow(currentIndex))
    Keys.onDownPressed:root.focusRow(currentIndex+1)
    Keys.onUpPressed:root.focusRow(currentIndex-1)
    Keys.onReturnPressed:if(currentItem)root.perf.selectProcess(currentItem.modelData.pid,currentItem.modelData.name)
    delegate:QuietButton {id:row;required property var modelData;required property int index;objectName:"process-row-"+modelData.pid;width:table.usableWidth;leftPadding:10;rightPadding:10;height:Math.max(Config.QuickPanelStyle.target,table.roomy?44:62*Config.DirectoryStyle.textScale);activeFocusOnTab:index===list.currentIndex;active:root.perf.selectedProcessPid===Number(modelData.pid);accessibleLabel:modelData.name+", PID "+modelData.pid+", CPU "+root.workspace.number(modelData.cpu_percent)+" percent, memory "+root.workspace.number(modelData.memory_mib)+" MiB";background.visible:visualFocus || down || active
     onActiveFocusChanged:if(activeFocus){root.focusedPid=Number(modelData.pid);list.currentIndex=index;list.positionViewAtIndex(index,ListView.Contain);}
     Keys.onDownPressed:root.focusRow(index+1)
     Keys.onUpPressed:root.focusRow(index-1)
     Keys.onPressed:event=>{if(event.key===Qt.Key_Home){root.focusRow(0);event.accepted=true;}else if(event.key===Qt.Key_End){root.focusRow(list.count-1);event.accepted=true;}else if(event.key===Qt.Key_PageDown){root.focusRow(index+Math.max(1,Math.floor(list.height/height)));event.accepted=true;}else if(event.key===Qt.Key_PageUp){root.focusRow(index-Math.max(1,Math.floor(list.height/height)));event.accepted=true;}}
     onClicked:{root.perf.selectProcess(modelData.pid,modelData.name);if(!root.split)Qt.callLater(()=>inspector.forceActiveFocus());}
     contentItem:Row {spacing:8
      Column {width:table.nameWidth;anchors.verticalCenter:parent.verticalCenter;spacing:4
       Text {width:parent.width;text:row.modelData.name;textFormat:Text.PlainText;elide:Text.ElideRight;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
       Text {visible:!table.roomy;width:parent.width;text:"PID "+row.modelData.pid+" · "+String(row.modelData.state || "State unavailable");textFormat:Text.PlainText;elide:Text.ElideRight;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
      }
      Text {visible:table.roomy;width:100*Config.DirectoryStyle.textScale;height:parent.height;text:String(row.modelData.pid);verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
      Text {width:table.numberWidth;height:parent.height;text:root.workspace.number(row.modelData.cpu_percent);verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.ink}
      Text {width:table.numberWidth;height:parent.height;text:root.workspace.number(row.modelData.memory_mib);verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
     }
    }
   }
   Text {visible:root.filtered.length===0;width:parent.width;anchors.centerIn:parent;text:root.query?"No process matches this search.":root.perf.processesObservedAt>0?"No process samples in this filter.":"Waiting for process samples.";wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  }
  PerformanceWorkspaceInspector {id:inspector;objectName:"process-manager-inspector";workspace:root.workspace;visible:root.inspecting;anchors.right:parent.right;width:root.split?Math.min(420*Config.DirectoryStyle.textScale,parent.width*.37):parent.width;height:parent.height}
 }
}
