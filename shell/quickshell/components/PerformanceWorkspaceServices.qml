import QtQuick
import QtQuick.Controls
import "../config" as Config
FocusScrollArea {
 id:root;required property var workspace
 readonly property var services:workspace.performance.managedServices
 contentHeight:page.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
 Column {id:page;width:root.width-12;spacing:20
  InsightsWorkspaceTitle {width:parent.width;title:"Supported user services";actions:[QuietButton {objectName:"performance-services-refresh";text:"Refresh";enabled:!root.services.actions.locked;onClicked:root.services.refresh()}]}
  Text {width:parent.width;text:"Only supported user audio services can be restarted here. Other services remain read only.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  Text {visible:!!root.services.error;width:parent.width;text:root.services.error;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.Theme.warning}
  PerformanceWorkspaceServiceReview {width:parent.width;actions:root.services.actions}
  InsightsWorkspaceSearch {id:search;objectName:"performance-service-search";width:parent.width;placeholderText:"Find a supported service";text:root.workspace.readState("services","query","");onTextEdited:root.workspace.remember("services","query",text)}
  Repeater {model:root.services.items.filter(item=>!search.text.trim() || String(item.unit || "").toLocaleLowerCase().includes(search.text.trim().toLocaleLowerCase()))
   Column {required property var modelData;width:parent.width;spacing:8
    InsightsWorkspaceChoice {objectName:"performance-service-"+modelData.unit;width:parent.width;text:modelData.unit;detail:modelData.state || "State unavailable";hint:modelData.restartAllowed?"Review restart":"Read only";enabled:modelData.restartAllowed && !root.services.actions.locked && !root.services.actions.blocked;onClicked:root.services.actions.request(modelData)}
    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
   }
  }
  Text {visible:!root.services.available;width:parent.width;text:"Managed service inventory is unavailable.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
 }
}
