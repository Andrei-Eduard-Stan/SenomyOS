import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config
import "BriefingModel.js" as Model
FocusScrollArea {
 id:root;objectName:"insights-briefing"
 required property var workspace
 readonly property var assessment:Model.assessment(workspace.senomy.systemHealth,workspace.senomy.message)
 readonly property var sources:Model.sources(workspace.data("briefing"),workspace.briefingNow)
 readonly property bool wide:width>=760*Config.DirectoryStyle.textScale
 contentWidth:width;contentHeight:page.implicitHeight
 ScrollBar.vertical:ShellScrollBar {}
 Column {
  id:page;width:root.width-12;spacing:24
  InsightsWorkspaceTitle {width:parent.width;title:"Briefing";detail:Qt.formatDateTime(new Date(root.workspace.briefingNow),"dddd d MMMM · HH:mm")
   actions:[ContextEvidenceMenu {contextKey:"briefing";componentKey:"insights-briefing";ownerActive:root.workspace.requestedOpen && !root.workspace.state.modalActive;accessibleLabel:"Briefing evidence actions";report:({assessment:root.assessment,attention:root.workspace.attention,observations:root.workspace.briefingObservations(),sources:root.sources});copyLabel:"Copy briefing";textLabel:"Save briefing as text"}]
  }
  Text {objectName:"briefing-assessment";width:parent.width;text:root.workspace.attention.length?(root.workspace.attention.length===1?"One thing to review":root.workspace.attention.length+" things to review"):root.assessment.title;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(30*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
  Text {width:parent.width;text:root.workspace.attention.length?root.assessment.title+". "+root.assessment.detail:root.assessment.detail;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:root.assessment.state==="warning"?Config.Theme.warning:Config.DirectoryStyle.muted}
  GridLayout {width:parent.width;columns:root.wide?2:1;columnSpacing:32;rowSpacing:24
   Column {Layout.fillWidth:true;Layout.preferredWidth:3;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop;spacing:12
    Column {visible:!!root.workspace.priorityAttention;width:parent.width;spacing:10
     Text {width:parent.width;text:root.workspace.priorityAttention?root.workspace.priorityAttention.title:"";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(22*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
     Text {width:parent.width;text:root.workspace.priorityAttention?root.workspace.priorityAttention.state:"";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:root.workspace.priorityAttention && root.workspace.priorityAttention.tone==="attention"?Config.Theme.warning:Config.DirectoryStyle.muted}
     Text {width:parent.width;text:root.workspace.priorityAttention?root.workspace.priorityAttention.detail:"";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted;lineHeight:1.3}
     QuietButton {objectName:"briefing-priority-action";text:root.workspace.priorityAttention?root.workspace.priorityAttention.action:"Review";width:Math.min(parent.width,Math.max(180,implicitWidth));glyph:"\uf061";enabled:!root.workspace.state.modalActive;onClicked:root.workspace.navigate(root.workspace.priorityAttention.route)}
    }
    Text {visible:!root.workspace.priorityAttention;width:parent.width;text:"Nothing to review in the available evidence.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
    Repeater {model:root.workspace.attention.slice(1)
     InsightsWorkspaceChoice {required property var modelData;objectName:"briefing-attention-"+modelData.id;width:parent.width;text:modelData.title;hint:modelData.state;enabled:!root.workspace.state.modalActive;onClicked:root.workspace.navigate(modelData.route)}
    }
   }
   Column {Layout.fillWidth:true;Layout.preferredWidth:2;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop;spacing:12
    Text {text:"Evidence coverage";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
    Repeater {model:root.sources
     Column {required property var modelData;width:parent.width;spacing:6
      Text {width:parent.width;text:modelData.label+" · "+modelData.state;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:modelData.tone==="attention"?Config.Theme.warning:Config.DirectoryStyle.ink}
      Text {width:parent.width;text:modelData.age;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
      Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
     }
    }
    QuietButton {objectName:"briefing-sources-toggle";text:root.workspace.showSources?"Hide source details":"Source details";width:Math.min(parent.width,Math.max(160,implicitWidth));onClicked:root.workspace.showSources=!root.workspace.showSources}
    Text {visible:root.workspace.showSources;width:parent.width;text:root.sources.map(s=>s.label+" · "+s.meaning).join("\n");wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted;lineHeight:1.3}
   }
  }
  IslandRule {width:parent.width;leadingPoint:false}
  Column {width:parent.width;spacing:10
   Text {text:"Since opening";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
   Text {width:parent.width;text:root.workspace.compactChanges();wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
   Flow {width:parent.width;spacing:8
    QuietButton {objectName:"briefing-changes-toggle";text:root.workspace.showChangeDetails?"Hide changes":"View changes";onClicked:root.workspace.showChangeDetails=!root.workspace.showChangeDetails}
    QuietButton {text:"Timeline";glyph:"\uf017";onClicked:root.workspace.navigate("timeline")}
    QuietButton {objectName:"briefing-system-toggle";text:root.workspace.showSystemDetails?"Hide readings":"Current readings";onClicked:root.workspace.showSystemDetails=!root.workspace.showSystemDetails}
   }
   Text {visible:root.workspace.showChangeDetails;width:parent.width;text:root.workspace.changes().map(row=>row.label+" / "+row.value).join("\n");wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted;lineHeight:1.4}
  }
  GridLayout {objectName:"briefing-system-summary";visible:root.workspace.showSystemDetails;width:parent.width;columns:root.wide?5:2;columnSpacing:16;rowSpacing:16
   Repeater {model:root.workspace.briefingObservations()
    Column {required property var modelData;Layout.fillWidth:true;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop;spacing:6
     Text {width:parent.width;text:modelData.label;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
     Text {width:parent.width;text:modelData.value;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
    }
   }
  }
 }
}
