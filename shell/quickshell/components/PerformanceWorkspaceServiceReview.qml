import QtQuick
import "../config" as Config
Column {
 id:root;required property var actions
 visible:actions.actionState!=="idle";spacing:10
 ConfirmationFocus {view:root;actions:root.actions;cancelButton:cancel}
 Text {width:parent.width;text:root.actions.title || "Service review";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
 Text {width:parent.width;text:root.actions.actionState==="pending"?root.actions.impact:root.actions.message;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:root.actions.actionState==="failed"?Config.Theme.warning:Config.DirectoryStyle.muted}
 Flow {visible:root.actions.actionState==="pending";width:parent.width;spacing:8
  QuietButton {id:cancel;objectName:"selectionCancel";text:"Cancel";width:Math.min(parent.width,Math.max(120,implicitWidth));onClicked:root.actions.cancel()}
  QuietButton {objectName:"selectionConfirm";text:"Confirm restart";warning:true;width:Math.min(parent.width,Math.max(160,implicitWidth));onClicked:root.actions.confirm()}
 }
}
