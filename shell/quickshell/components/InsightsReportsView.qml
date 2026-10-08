import QtQuick
import "../config" as Config
FocusScrollArea {
    id:root
    required property var insights
    readonly property var report: insights.payloads.reports && insights.payloads.reports.ok ? insights.payloads.reports.data || ({}) : ({})
    contentHeight:column.implicitHeight
    Column {
        id:column;width:parent.width;spacing:12
        SurfaceCard {width:parent.width;title:"PRIVATE EVIDENCE REPORTS";value:root.report.exists?(root.report.latest.profile_label||"READY"):"NONE";detail:String(root.report.history_count||0)+" retained report(s) · mode 0600 · no automatic upload"}
        InsightsStatus {width:parent.width;insights:root.insights;route:"reports"}
        Flow {
            width:parent.width;spacing:8
            Repeater {
                model:["overview","performance","network","power","full"]
                delegate:SurfaceButton {required property string modelData;width:130;text:"GENERATE "+modelData.toUpperCase();enabled:root.insights.actionState!=="running";onClicked:root.insights.generateReport(modelData)}
            }
            SurfaceButton {width:130;text:"OPEN LATEST";enabled:Boolean(root.report.exists) && root.insights.actionState!=="running";onClicked:root.insights.openLatestReport()}
        }
        Text {text:"LATEST PREVIEW";color:Config.Theme.dim;font.family:Config.Theme.fontFamily;font.pixelSize:8}
        Repeater {
            model:root.report.preview||[]
            delegate:Text {required property var modelData;width:column.width;text:String(modelData.line_no).padStart(3,"0")+"  "+modelData.text;textFormat:Text.PlainText;color:Config.Theme.muted;font.family:Config.Theme.fontFamily;font.pixelSize:9;wrapMode:Text.WrapAnywhere}
        }
    }
}
