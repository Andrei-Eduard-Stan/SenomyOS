import QtQuick
import "../config" as Config

FocusScrollArea {
    id: root
    required property var insights
    required property string domain
    readonly property var result: (insights.payloads[domain+"Result"] || {}).data || ({})
    contentHeight: column.implicitHeight
    Column {
        id: column;width:parent.width;spacing:10
        Text {width:parent.width;text:root.domain==="console"?"CURATED CONSOLE // NO ARBITRARY COMMAND ENTRY":"ALLOWLISTED READ-ONLY DIAGNOSTICS";color:Config.Theme.accent;font.family:Config.Theme.fontFamily;font.pixelSize:9;wrapMode:Text.WordWrap}
        InsightsStatus {width:parent.width;insights:root.insights;route:root.domain}
        Flow {
            width:parent.width;spacing:7
            Repeater {
                model:root.insights.tasksFor(root.domain)
                delegate:SurfaceButton {
                    required property var modelData
                    width:root.domain==="console"?176:190
                    text:modelData.code+" // "+modelData.title;detail:modelData.summary
                    enabled:root.insights.actionState!=="running" && modelData.available!==false
                    onClicked:root.insights.runTask(root.domain,modelData.id)
                }
            }
        }
        Text {width:parent.width;visible:root.insights.tasksFor(root.domain).length===0;text:"No available task catalog. Refresh to retry.";color:Config.Theme.muted;font.family:Config.Theme.fontFamily;wrapMode:Text.WordWrap}
        SurfaceButton {width:parent.width;text:"REFRESH TASKS";enabled:!root.insights.busy;onClicked:root.insights.refresh(root.domain,false)}
        Rectangle {width:parent.width;height:1;color:Config.Theme.surfaceHover}
        Text {width:parent.width;text:(root.result.title||"Awaiting task").toUpperCase();textFormat:Text.PlainText;color:Config.Theme.foreground;font.family:Config.Theme.fontFamily;wrapMode:Text.WordWrap}
        InsightsStatus {width:parent.width;insights:root.insights;route:root.domain+"Result"}
        FocusScrollArea {
            id: output; width:parent.width;height:240;contentHeight:outputColumn.implicitHeight
            activeFocusOnTab:true;Accessible.role:Accessible.Pane;Accessible.name:"Diagnostic output. Use Page Up and Page Down to scroll."
            Keys.onPressed: event=>{
                if([Qt.Key_PageDown,Qt.Key_PageUp,Qt.Key_Home,Qt.Key_End].indexOf(event.key)<0)return;
                const limit=Math.max(0,contentHeight-height);
                contentY=event.key===Qt.Key_Home?0:event.key===Qt.Key_End?limit:
                    Math.max(0,Math.min(limit,contentY+(event.key===Qt.Key_PageDown?1:-1)*height*0.8));event.accepted=true;
            }
            Column {
                id:outputColumn;width:parent.width
                Repeater {
                    model:root.result.output||[]
                    delegate:Text {
                        required property var modelData
                        width:outputColumn.width;text:typeof modelData==="string"?modelData:modelData.text||"";textFormat:Text.PlainText
                        color:Config.Theme.muted;font.family:Config.Theme.fontFamily;font.pixelSize:9;wrapMode:Text.WrapAnywhere
                    }
                }
            }
        }
    }
}
