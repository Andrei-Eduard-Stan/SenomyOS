import QtQuick
import QtQuick.Controls
import "../config" as Config
import "calendar" as CalendarUi
Item {
 id:root;required property var workspace;required property string domain
 property string selectedId:workspace.readState(domain,"selected",String(result.task_id || ""))
 property bool detailOpen:false
 readonly property bool split:width>=700*Config.DirectoryStyle.textScale
 readonly property var tasks:workspace.insights.tasksFor(domain)
 readonly property var filtered:tasks.filter(t=>!search.text.trim() || [t.title,t.code,t.summary].some(v=>String(v || "").toLocaleLowerCase().includes(search.text.trim().toLocaleLowerCase())))
 readonly property var selected:tasks.find(t=>t.id===selectedId) || null
 readonly property var result:workspace.data(domain+"Result")
 readonly property bool resultMatches:!!selected && result.task_id===selected.id
 function back(){if(!split && detailOpen){detailOpen=false;return true;}return false;}
 Column {id:header;width:parent.width;spacing:10
  InsightsWorkspaceTitle {width:parent.width;title:root.domain==="console"?"Console":"Diagnostics";detail:root.domain==="console"?"Curated commands with an explicit Run step":"Select a read-only check, then inspect its result";actions:[QuietButton {text:"Refresh";enabled:!root.workspace.insights.busy;onClicked:root.workspace.insights.refresh(root.domain,false)}]}
  InsightsWorkspaceStatus {width:parent.width;workspace:root.workspace;route:root.domain}
 }
 Item {y:header.height+16;width:parent.width;height:Math.max(1,parent.height-y)
  Column {id:catalog;visible:root.split || !root.detailOpen;width:root.split?Math.floor((parent.width-24)*.36):parent.width;height:parent.height;spacing:10
   InsightsWorkspaceSearch {id:search;objectName:"insights-task-search";width:parent.width;placeholderText:"Find a check or command";text:root.workspace.readState(root.domain,"search","");onTextEdited:root.workspace.remember(root.domain,"search",text);Accessible.name:"Search curated tasks"}
   FocusDeviceList {id:list;width:parent.width;height:Math.max(1,parent.height-search.height-10);model:root.filtered;spacing:4;ScrollBar.vertical:ShellScrollBar {}
    delegate:InsightsWorkspaceChoice {required property var modelData;objectName:"task-"+modelData.id;width:list.width-12;text:modelData.title;hint:modelData.available===false?"Unavailable":modelData.code || "";active:root.selectedId===modelData.id;onClicked:{root.selectedId=modelData.id;root.workspace.remember(root.domain,"selected",root.selectedId);root.detailOpen=true;if(!root.split)Qt.callLater(()=>runButton.forceActiveFocus());}}
    Text {width:parent.width;visible:root.filtered.length===0;text:root.tasks.length?"No matching tasks.":"No task catalog was returned. Refresh to retry.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
   }
  }
  FocusScrollArea {id:detail;visible:root.split || root.detailOpen;x:root.split?catalog.width+24:0;width:parent.width-x;height:parent.height;contentHeight:detailColumn.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
   Column {id:detailColumn;width:detail.width-12;spacing:14
    QuietButton {visible:!root.split;text:"Back to tasks";glyph:"\uf104";onClicked:root.detailOpen=false}
    Text {visible:!root.selected;width:parent.width;text:"Choose a task to inspect its scope. Nothing runs until you choose Run.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
    Column {width:parent.width;visible:!!root.selected;spacing:12
     Text {width:parent.width;text:root.selected?root.selected.title:"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(22*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
     Text {width:parent.width;text:root.selected?root.selected.summary || "":"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
     Text {visible:!!text;width:parent.width;text:root.selected?root.selected.command_preview || root.selected.preview || "":"";textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
     Text {visible:!!text;width:parent.width;text:root.selected?root.selected.scope || "":"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
     QuietButton {id:runButton;objectName:"runSelectedTask";width:Math.min(parent.width,Math.max(180,implicitWidth));text:root.workspace.insights.actionState==="running"?"Running…":root.domain==="console"?"Run command":"Run check";enabled:!!root.selected && root.selected.available!==false && root.workspace.insights.actionState!=="running" && !root.workspace.state.modalActive;onClicked:root.workspace.insights.runTask(root.domain,root.selected.id)}
    }
    IslandRule {width:parent.width;leadingPoint:false}
    InsightsWorkspaceTitle {width:parent.width;title:"Result";actions:[ContextEvidenceMenu {contextKey:root.domain;componentKey:"insights-"+root.domain;ownerActive:root.workspace.requestedOpen && !root.workspace.state.modalActive;evidenceAvailable:root.resultMatches && (root.result.output || []).length>0;report:root.resultMatches?root.result:({});accessibleLabel:"Task result actions";copyLabel:"Copy result";textLabel:"Save result as text"}]}
    InsightsWorkspaceStatus {width:parent.width;workspace:root.workspace;route:root.domain+"Result";showActionFeedback:false}
    Text {width:parent.width;visible:!root.resultMatches;text:root.result.task_id?"The latest result belongs to another task. Select that task to inspect it, or run this one.":"No result for this task yet.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
    Text {visible:root.resultMatches && root.workspace.insights.actionState==="running" && root.workspace.insights.actionDomain===root.domain;width:parent.width;text:"Previous result · waiting for the requested check";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
    FocusScrollArea {id:output;objectName:"insights-task-output-view";visible:root.resultMatches;width:parent.width;height:visible?Math.min(Math.max(80,detail.height*.5),Math.max(80,resultText.implicitHeight)):0;contentHeight:resultText.implicitHeight;activeFocusOnTab:true;Accessible.role:Accessible.Pane;Accessible.name:"Selected task output. Use Page Up and Page Down to scroll.";ScrollBar.vertical:ShellScrollBar {}
     Keys.onPressed:event=>{const limit=Math.max(0,contentHeight-height);if(![Qt.Key_PageDown,Qt.Key_PageUp,Qt.Key_Home,Qt.Key_End].includes(event.key))return;contentY=event.key===Qt.Key_Home?0:event.key===Qt.Key_End?limit:Math.max(0,Math.min(limit,contentY+(event.key===Qt.Key_PageDown?1:-1)*height*.8));event.accepted=true;}
     TextEdit {id:resultText;objectName:"insights-task-output";visible:root.resultMatches;width:parent.width-12;text:(root.result.output || []).map(line=>typeof line==="string"?line:line.text || "").join("\n");readOnly:true;selectByMouse:true;activeFocusOnTab:false;textFormat:TextEdit.PlainText;wrapMode:TextEdit.Wrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.ink;selectionColor:Config.DirectoryStyle.selection;selectedTextColor:Config.DirectoryStyle.ink;Accessible.name:"Selected task result"}
    }
   }
  }
 }
}
