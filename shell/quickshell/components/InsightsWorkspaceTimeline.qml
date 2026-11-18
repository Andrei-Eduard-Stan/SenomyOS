import QtQuick
import QtQuick.Controls
import "../config" as Config
import "calendar" as CalendarUi
Item {
 id:root;required property var workspace
 property string filter:workspace.readState("timeline","filter","all")
 property int selected:-1
 readonly property var entries:workspace.data("timeline").entries || []
 readonly property var filtered:entries.filter(e=>(filter!=="issues" || ["error","warning","critical"].includes(e.severity)) && (!search.text.trim() || [e.title,e.source,e.message].some(v=>String(v || "").toLocaleLowerCase().includes(search.text.trim().toLocaleLowerCase()))))
 function back(){if(selected<0)return false;selected=-1;return true;}
 Column {id:header;width:parent.width;spacing:12
  InsightsWorkspaceTitle {width:parent.width;title:"Timeline";detail:"Recent local activity";actions:[QuietButton {objectName:"insights-timeline-refresh";text:"Refresh";enabled:!root.workspace.insights.busy;onClicked:root.workspace.insights.refresh("timeline",false)}]}
  InsightsWorkspaceStatus {width:parent.width;workspace:root.workspace;route:"timeline"}
  Flow {width:parent.width;spacing:8
   QuietButton {text:"All activity";Accessible.checkable:true;Accessible.checked:active;active:root.filter==="all";onClicked:{root.filter="all";root.workspace.remember("timeline","filter",root.filter);}}
   QuietButton {objectName:"insights-timeline-issues";text:"Issues";Accessible.checkable:true;Accessible.checked:active;active:root.filter==="issues";onClicked:{root.filter="issues";root.workspace.remember("timeline","filter",root.filter);}}
  }
  InsightsWorkspaceSearch {id:search;objectName:"insights-timeline-search";width:parent.width;placeholderText:"Search activity or source";text:root.workspace.readState("timeline","search","");onTextEdited:{root.selected=-1;root.workspace.remember("timeline","search",text);}Accessible.name:"Search local activity"}
 }
 FocusDeviceList {id:list;y:header.height+12;width:parent.width;height:Math.max(1,parent.height-y);spacing:4;model:root.filtered;ScrollBar.vertical:ShellScrollBar {}
  delegate:Column {required property var modelData;required property int index;width:list.width-12;spacing:8
   InsightsWorkspaceChoice {objectName:"insights-event-"+index;width:parent.width;text:modelData.title;detail:modelData.time+" · "+modelData.source;hint:["warning","error","critical"].includes(modelData.severity)?modelData.severity:"";active:root.selected===index;onClicked:root.selected=root.selected===index?-1:index}
   Text {visible:root.selected===index;x:10;width:parent.width-20;text:modelData.message || "No further detail was returned.";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
   Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
  }
  Text {visible:root.filtered.length===0;width:parent.width;text:root.entries.length?"No activity matches these filters.":"No activity has been returned. Refresh to check the local history.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
 }
}
