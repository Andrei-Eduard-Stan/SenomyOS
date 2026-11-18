import QtQuick
import "../config" as Config
Column {
 id:root
 property var controller:null
 readonly property bool pending:!!controller && ["pending-start","pending-stop"].includes(controller.state)
 readonly property bool owned:!!controller && controller.owned
 readonly property bool busy:!!controller && (controller.startPending || controller.state==="stop-requested")
 readonly property var provider:controller?controller.provider:null
 readonly property string observed:!controller?"Unavailable":pending?controller.state==="pending-start"?"Start keyboard?":"Stop keyboard?":busy?"Request in progress":!owned?controller.available()?"Stopped":"Unavailable":provider.visibilityKnown?provider.visible?"Visible":"Hidden":"Running · visibility unverified"
 spacing:16
 Text {objectName:"osk-status";width:parent.width;text:root.observed;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(18*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
 Flow {width:parent.width;spacing:8
  QuietButton {objectName:"oskShow";text:root.owned?"Show keyboard":"Start keyboard";glyph:"\uf11c";enabled:!!root.controller && !root.pending && !root.busy && (root.owned || root.controller.available());onClicked:root.controller.requestShow()}
  QuietButton {objectName:"oskHide";text:"Hide";enabled:root.owned && !root.pending && !root.busy;onClicked:root.controller.requestHide()}
  QuietButton {objectName:"oskStop";text:"Stop";enabled:root.owned && !root.pending && !root.busy;onClicked:root.controller.requestStop()}
 }
 Column {width:parent.width;spacing:8;visible:root.owned && !!root.provider && root.provider.modeSupported===true
  Text {width:parent.width;text:"Placement";font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
  Flow {width:parent.width;spacing:8
   QuietButton {objectName:"oskMode";text:root.provider && root.provider.floating?"Floating · switch":"Window refit · switch";enabled:!root.pending && !!root.provider && root.provider.signalReady;onClicked:root.provider.toggleMode(root.controller.serial)}
  }
 }
 Column {id:review;width:parent.width;spacing:12;visible:root.pending
  ConfirmationFocus {view:review;actions:root.controller;actionState:root.controller?root.controller.state:"idle";pendingStates:["pending-start","pending-stop"];cancelButton:cancel}
  Text {width:parent.width;text:root.controller?root.controller.message:"";textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
  Flow {width:parent.width;spacing:8
   QuietButton {id:cancel;objectName:"oskCancel";text:"Cancel";onClicked:{if(root.controller.state==="pending-start")root.controller.cancelStart();else root.controller.cancelStop();}}
   QuietButton {objectName:"oskConfirm";text:root.controller && root.controller.state==="pending-start"?"Start for session":"Confirm stop";onClicked:{if(root.controller.state==="pending-start")root.controller.confirmStart();else root.controller.confirmStop();}}
  }
 }
 Text {width:parent.width;visible:!!root.controller && !root.pending;text:root.controller?root.controller.message+(root.owned && root.provider.lockMessage!==undefined?"\n"+root.provider.lockMessage:""):"Keyboard controls are unavailable.";textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
}
