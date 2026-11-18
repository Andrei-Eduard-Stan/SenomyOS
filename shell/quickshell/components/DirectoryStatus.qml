import QtQuick
import "../config" as Config
Column {
    id:root
    required property var insights
    required property string route
    readonly property var status:(insights.statuses || {})[route] || ({state:"unloaded",observedAt:0,error:""})
    spacing:5
    DirectoryFreshness {
        width:parent.width;source:root.route==="updates"?"UPDATE CACHE":root.route.toUpperCase()
        observedAt:root.status.observedAt*1000;cached:true;staleAfter:root.route==="timeline"?15000:300000
        visible:root.status.state!=="loading" && root.status.state!=="unloaded"
    }
    Text {width:parent.width;visible:root.status.state==="loading" || root.status.state==="unloaded";text:root.status.state==="loading"?"Refreshing collected evidence…":"UNAVAILABLE · no collected evidence";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;wrapMode:Text.WordWrap}
    Text {width:parent.width;visible:root.status.state==="failed";text:"FAILED // "+(root.status.error || "Evidence could not be collected.");color:Config.Theme.warning;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;wrapMode:Text.WordWrap}
    Text {width:parent.width;visible:root.insights.actionMessage && (root.insights.actionDomain===root.route || root.insights.actionDomain+"Result"===root.route);text:root.insights.actionState.toUpperCase()+" // "+root.insights.actionMessage;color:root.insights.actionState==="failed"?Config.Theme.warning:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;wrapMode:Text.WordWrap}
}
