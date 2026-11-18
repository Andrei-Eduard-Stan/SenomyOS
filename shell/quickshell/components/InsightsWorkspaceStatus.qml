import QtQuick
import "interaction" as Interaction
import "../config" as Config
import "DirectoryFreshness.js" as Freshness
Column {
 id:root;objectName:"insights-status-"+route
 required property var workspace
 required property string route
 readonly property var status:(workspace.insights.statuses || {})[route] || ({state:"unloaded",observedAt:0,error:""})
 property bool showActionFeedback:true
 readonly property bool actionHere:showActionFeedback && (workspace.insights.actionDomain===route || workspace.insights.actionDomain+"Result"===route || route==="updates" && workspace.insights.actionDomain==="maintenance")
 spacing:6
 Text {width:parent.width;visible:root.status.state!=="ready";text:root.status.state==="loading"?"Refreshing evidence…":root.status.state==="failed"?(root.status.error || "Evidence could not be collected. Refresh to retry."):root.status.state==="running"?"Running requested action…":"No collected evidence yet";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:root.status.state==="failed"?Config.Theme.warning:Config.DirectoryStyle.muted}
 Text {width:parent.width;visible:root.status.observedAt>0;text:"Observed "+Freshness.ageLabel(root.status.observedAt*1000,workspace.briefingNow)+(workspace.briefingNow-root.status.observedAt*1000>(route==="timeline"?15000:300000)?" · older evidence":"");wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
 Interaction.ContentMotion {targetItem:feedback;context:root.actionHere?String(root.workspace.insights.actionState):"";active:root.workspace.requestedOpen;floorOpacity:0.92;duration:Config.Motion.statusMs}
 Text {id:feedback;objectName:"insights-action-feedback";width:parent.width;visible:root.actionHere && !!workspace.insights.actionMessage;text:workspace.insights.actionMessage;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:workspace.insights.actionState==="failed"?Config.Theme.warning:Config.DirectoryStyle.ink}
}
