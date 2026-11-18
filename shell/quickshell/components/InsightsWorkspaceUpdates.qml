import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config
import "BriefingModel.js" as Model
import "calendar" as CalendarUi
FocusScrollArea {
 id:root;required property var workspace
 property string filter:workspace.readState("updates","filter","all")
 property bool maintenanceOpen:false
 readonly property var data:workspace.data("updates")
 readonly property var sources:Model.sources(data,workspace.briefingNow)
 readonly property var packages:[].concat(((data.official || {}).packages || []).map(p=>Object.assign({},p,{bucket:"official"})),((data.aur || {}).packages || []).map(p=>Object.assign({},p,{bucket:"aur"})))
 readonly property var filtered:packages.filter(p=>(filter==="all" || p.bucket===filter) && (!search.text.trim() || String(p.name || "").toLocaleLowerCase().includes(search.text.trim().toLocaleLowerCase())))
 contentHeight:page.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
 Column {id:page;width:root.width-12;spacing:20
  InsightsWorkspaceTitle {width:parent.width;title:"Updates";detail:"Verified source checks and reported packages"}
  InsightsWorkspaceStatus {width:parent.width;workspace:root.workspace;route:"updates"}
  GridLayout {width:parent.width;columns:width>=640*Config.DirectoryStyle.textScale?2:1;columnSpacing:24;rowSpacing:20
   Repeater {model:root.sources
    Column {required property var modelData;Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:1;spacing:10
     Text {width:parent.width;text:modelData.label;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
     Text {width:parent.width;objectName:"insights-update-state-"+modelData.id;text:modelData.current?modelData.count+" reported":modelData.state;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(22*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:modelData.tone==="attention"?Config.Theme.warning:Config.DirectoryStyle.ink}
     Text {width:parent.width;text:modelData.age+" · "+modelData.meaning;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
     Text {width:parent.width;visible:!!text;text:[((root.data[modelData.id] || {}).error || {}).message,(root.data[modelData.id] || {}).warning].filter(Boolean).join(" · ");textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
     QuietButton {objectName:"insights-check-"+modelData.id;text:modelData.id==="official"?"Check official":"Check AUR";width:Math.min(parent.width,Math.max(150,implicitWidth));enabled:root.workspace.insights.actionState!=="running" && !root.workspace.state.modalActive;onClicked:root.workspace.insights.runUpdate(modelData.id)}
    }
   }
  }
  QuietButton {objectName:"insights-maintenance-toggle";text:root.maintenanceOpen?"Hide upgrade options":"Upgrade options";onClicked:root.maintenanceOpen=!root.maintenanceOpen}
  Column {width:parent.width;visible:root.maintenanceOpen;spacing:12
   Text {width:parent.width;text:"Official package upgrades open in a native terminal for transaction review and normal authentication. SenomyOS release activation is separate.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
   Text {width:parent.width;text:"Reboot · "+(((root.data.maintenance || {}).reboot || {}).state || "Unknown")+" · "+(((root.data.maintenance || {}).reboot || {}).reason || "Not assessed");wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
   QuietButton {objectName:"insights-maintenance-open";width:Math.min(parent.width,Math.max(240,implicitWidth));text:"Review upgrade in terminal";wrapLabel:true;enabled:root.workspace.insights.actionState!=="running" && Boolean((root.data.maintenance || {}).handoffAvailable) && !root.workspace.state.modalActive;onClicked:root.workspace.insights.openMaintenance()}
  }
  IslandRule {width:parent.width;leadingPoint:false}
  Flow {width:parent.width;spacing:8
   Repeater {model:[{id:"all",label:"All reported"},{id:"official",label:"Official"},{id:"aur",label:"AUR"}]
    QuietButton {required property var modelData;objectName:"insights-package-filter-"+modelData.id;text:modelData.label;Accessible.checkable:true;Accessible.checked:active;active:root.filter===modelData.id;onClicked:{root.filter=modelData.id;root.workspace.remember("updates","filter",root.filter);}}
   }
  }
  InsightsWorkspaceSearch {id:search;objectName:"insights-package-search";width:parent.width;placeholderText:"Find a reported package";text:root.workspace.readState("updates","search","");onTextEdited:root.workspace.remember("updates","search",text);Accessible.name:"Search reported packages"}
  Text {width:parent.width;visible:Boolean((root.data.official || {}).truncated || (root.data.aur || {}).truncated);text:"Showing the returned package sample. Source checks may report more packages than are listed.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
  Column {width:parent.width;spacing:8
   Repeater {model:root.filtered
    Item {required property var modelData;width:parent.width;implicitHeight:Math.max(52,labels.implicitHeight+16)
     Column {id:labels;x:10;y:8;width:parent.width-20;spacing:5
      Text {width:parent.width;text:modelData.name || "Package";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
      Text {width:parent.width;text:String(modelData.current || "Version unavailable")+" → "+String(modelData.available || "Version unavailable")+" · "+String(modelData.source || "Source unavailable");textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
     }
     Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:Config.DirectoryStyle.rule}
    }
   }
   Text {width:parent.width;visible:root.filtered.length===0;text:root.packages.length?"No reported packages match these filters.":root.sources.every(s=>s.current)?"No updates were reported by the current source checks.":"No package list to show. Source checks above are incomplete.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  }

 }
}
