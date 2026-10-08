import QtQuick
import "../config" as Config
Column {
    id: root
    required property var insights
    required property string route
    readonly property var status: (insights.statuses || {})[route] || ({state:"unloaded",observedAt:0,error:""})
    spacing:5
    Text {
        width:parent.width
        text: root.status.state === "loading" ? "Loading " + root.route + "…"
            : root.status.state === "unloaded" ? "No collected data yet."
            : (root.status.state === "failed" ? "Unavailable or failed" : "Collected data")
                + (root.status.observedAt > 0 ? " · observed " + Qt.formatDateTime(new Date(root.status.observedAt*1000),"dd MMM hh:mm:ss") : " · observation time unknown")
        textFormat:Text.PlainText;color:Config.Theme.muted;font.family:Config.Theme.fontFamily;font.pixelSize:10;wrapMode:Text.WordWrap
    }
    Text {
        width:parent.width;visible:root.status.error.length>0;text:root.status.error;textFormat:Text.PlainText
        color:Config.Theme.warning;font.family:Config.Theme.fontFamily;font.pixelSize:10;wrapMode:Text.WordWrap
    }
    Text {
        width:parent.width;visible:root.insights.actionMessage && root.insights.actionMessage.length>0
            && (root.insights.actionDomain === root.route || root.insights.actionDomain+"Result" === root.route)
        text:root.insights.actionState.toUpperCase()+" // "+root.insights.actionMessage;textFormat:Text.PlainText
        color:root.insights.actionState==="failed"?Config.Theme.warning:Config.Theme.muted;font.family:Config.Theme.fontFamily;font.pixelSize:10;wrapMode:Text.WordWrap
    }
}
