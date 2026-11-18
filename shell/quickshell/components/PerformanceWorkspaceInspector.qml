import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config
FocusScope {
 id:root;required property var workspace
 readonly property var perf:workspace.performance
 readonly property var process:perf.selectedProcess || {}
 readonly property var serviceActions:perf.managedServices.actions
 readonly property var owningService:perf.managedServices.processService
 property bool moreDetails:false
 function back(){if(perf.processActionState==="pending"){perf.cancelProcessAction();return true;}if(serviceActions.actionState==="pending"){serviceActions.cancel();return true;}if(perf.processActionState==="running" || serviceActions.locked)return false;perf.selectProcess(0,"");return true;}
 onVisibleChanged:if(visible)scroller.contentY=0
 ConfirmationFocus {view:root;actions:root.perf;actionState:root.perf.processActionState;cancelButton:cancel}
 Column {id:identity;width:root.width-12;spacing:10
  QuietButton {objectName:"process-inspector-back";text:"Back to processes";glyph:"\uf104";enabled:root.perf.processActionState!=="running" && !root.serviceActions.locked;onClicked:root.back()}
  Text {width:parent.width;text:root.perf.selectedProcessName || "Process";textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(22*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
  Text {width:parent.width;text:"PID "+root.perf.selectedProcessPid;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
 }
 FocusScrollArea {id:scroller;y:identity.height+16;width:parent.width;height:Math.max(1,parent.height-y-(review.visible?review.height+12:0));contentHeight:details.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
  Column {id:details;width:scroller.width-12;spacing:16
   Text {visible:!!root.perf.processDetailError;width:parent.width;text:root.perf.processDetailError;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.Theme.warning}
   GridLayout {width:parent.width;columns:2;columnSpacing:16;rowSpacing:12
    Repeater {model:[{label:"User",value:root.process.user},{label:"State",value:root.process.state},{label:"Threads",value:root.process.threads},{label:"Resident memory",value:root.process.rss_mib===undefined?undefined:root.process.rss_mib+" MiB"}]
     Column {required property var modelData;Layout.fillWidth:true;Layout.preferredWidth:1;Layout.minimumWidth:0;spacing:4
      Text {width:parent.width;text:modelData.label;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
      Text {width:parent.width;text:String(modelData.value ?? "Unavailable");textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
     }
    }
   }
   Text {visible:root.process.action_allowed!==true;width:parent.width;text:"Read only. Ownership or desktop/session protection prevents signals.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
   Flow {id:signals;visible:root.perf.processActionState!=="pending";width:parent.width;spacing:8
    readonly property int columns:width>=340*Config.DirectoryStyle.textScale?2:1
    Repeater {model:[{id:"terminate",label:"End process"},{id:"stop",label:"Pause"},{id:"continue",label:"Resume"},{id:"kill",label:"Force quit"}]
     QuietButton {required property var modelData;objectName:"process-action-"+modelData.id;width:(signals.width-8*(signals.columns-1))/signals.columns;text:modelData.label;warning:modelData.id==="kill";enabled:root.process.action_allowed===true && root.perf.processActionState!=="running" && !root.serviceActions.locked;onClicked:root.perf.requestProcessSignal(modelData.id)}
    }
   }
   Text {visible:!["idle","pending"].includes(root.perf.processActionState);width:parent.width;text:root.perf.processActionMessage;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:root.perf.processActionState==="failed"?Config.Theme.warning:Config.DirectoryStyle.muted}
   QuietButton {objectName:"process-details-toggle";text:root.moreDetails?"Hide details":"More details";onClicked:root.moreDetails=!root.moreDetails}
   Column {visible:root.moreDetails;width:parent.width;spacing:12
    Repeater {model:[{label:"Open files",value:root.process.fd_count},{label:"Executable",value:root.process.executable},{label:"Directory",value:root.process.cwd},{label:"Command",value:root.process.command}]
     Column {required property var modelData;width:parent.width;spacing:4
      Text {text:modelData.label;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
      Text {width:parent.width;text:String(modelData.value ?? "Unavailable");textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
     }
    }
    Text {visible:!root.owningService;width:parent.width;text:"No supported owning user service";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
   }
   PerformanceWorkspaceServiceReview {width:parent.width;actions:root.serviceActions}
   QuietButton {visible:!!root.owningService;objectName:"process-service-restart";width:Math.min(parent.width,Math.max(180,implicitWidth));text:"Review service restart";wrapLabel:true;enabled:!!root.owningService && !root.serviceActions.locked && !root.serviceActions.blocked;onClicked:root.serviceActions.request(root.owningService)}
   Text {visible:!!root.owningService;width:parent.width;text:root.owningService?root.owningService.unit:"";textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
  }
 }
 Column {id:review;visible:root.perf.processActionState==="pending";anchors.bottom:parent.bottom;width:parent.width-12;spacing:10
  Text {width:parent.width;text:root.perf.processActionMessage;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.Theme.warning}
  Text {width:parent.width;text:({kill:"Ends immediately. Unsaved work may be lost.",stop:"Stops running until resumed.",continue:"Resumes the paused process.",terminate:"Asks the process to exit. Unsaved work may be lost."})[root.perf.pendingProcessAction] || "Review this process action.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
  Row {width:parent.width;spacing:8
   QuietButton {id:cancel;objectName:"process-cancel";text:"Cancel";width:(parent.width-8)/2;height:Math.max(Config.QuickPanelStyle.target,2*Config.DirectoryStyle.bodySize+12);onClicked:root.perf.cancelProcessAction()}
   QuietButton {objectName:"process-confirm";text:"Confirm action";warning:true;wrapLabel:true;width:(parent.width-8)/2;height:Math.max(Config.QuickPanelStyle.target,2*Config.DirectoryStyle.bodySize+12);onClicked:root.perf.confirmProcessAction()}
  }
 }
}
