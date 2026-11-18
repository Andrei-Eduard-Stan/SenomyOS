import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config

FocusScrollArea {
    id: root
    property bool contextualActions: false
    required property var insights
    readonly property var report: insights.payloads.reports && insights.payloads.reports.ok ? insights.payloads.reports.data || ({}) : ({})
    readonly property var profiles: [
        {id:"overview",label:"System overview"}, {id:"performance",label:"Performance"},
        {id:"network",label:"Network"}, {id:"power",label:"Power"}, {id:"full",label:"Full evidence"}
    ]
    contentHeight: column.implicitHeight
    ScrollBar.vertical: ShellScrollBar {}
    Column {
        id: column
        width: parent.width
        spacing: Config.DirectoryStyle.sectionGap
        RowLayout {
            width: parent.width
            spacing: Config.DirectoryStyle.controlGap
            Column {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 8
                Text {
                    width: parent.width; text:"PRIVATE EVIDENCE REPORTS"; wrapMode:Text.Wrap
                    color:Config.DirectoryStyle.ink; font.family:Config.DirectoryStyle.headingFont
                    font.pixelSize:Math.round(18*Config.DirectoryStyle.textScale)
                }
                Text {
                    width:parent.width; text:root.report.exists ? (root.report.latest.profile_label || "Latest report ready") : "No report generated"
                    textFormat:Text.PlainText; wrapMode:Text.Wrap
                    color:Config.DirectoryStyle.ink; font.family:Config.DirectoryStyle.bodyFont; font.pixelSize:Config.DirectoryStyle.bodySize
                }
                Text {
                    width:parent.width; text:String(root.report.history_count || 0)+" retained · private files (0600) · no automatic upload"
                    wrapMode:Text.Wrap; color:Config.DirectoryStyle.muted
                    font.family:Config.DirectoryStyle.bodyFont; font.pixelSize:Config.DirectoryStyle.detailSize
                }
            }
            ComponentReportMenu {
                visible:!root.contextualActions; Layout.alignment:Qt.AlignTop
                componentKey:"insights-reports"; targetItem:column
                report:({latest:root.report.latest || {},preview:root.report.preview || []})
            }
            Loader {
                active:root.contextualActions; visible:active; Layout.alignment:Qt.AlignTop
                Layout.preferredWidth:active ? Config.DirectoryStyle.controlTarget : 0
                Layout.preferredHeight:Layout.preferredWidth
                sourceComponent:ContextEvidenceMenu {
                    contextKey:"reports"; componentKey:"insights-reports"; accessibleLabel:"Report actions"
                    evidenceAvailable:Boolean(root.report.exists); unavailableReason:"Generate a report first"
                    report:({latest:root.report.latest || {},preview:root.report.preview || []})
                    copyLabel:"Copy report preview"; textLabel:"Save report preview as text"
                    extraActions:[{id:"open",label:"Open latest report",enabled:Boolean(root.report.exists) && root.insights.actionState!=="running",reason:root.insights.actionState==="running"?"Report action in progress":"Generate a report first"}]
                    onExtraActionRequested:action=>{if(action==="open" && root.report.exists && root.insights.actionState!=="running")root.insights.openLatestReport();}
                }
            }
        }
        Column {
            width:parent.width; spacing:Config.DirectoryStyle.controlGap
            Text {text:"Report scope";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
            GridLayout {
                width:parent.width; columns:width<520*Config.DirectoryStyle.textScale?1:2
                columnSpacing:Config.DirectoryStyle.controlGap; rowSpacing:Config.DirectoryStyle.controlGap
                ShellComboBox {
                    id:profile; objectName:"report-profile"
                    Layout.fillWidth:true; Layout.minimumWidth:0
                    model:root.profiles; textRole:"label"
                    Accessible.name:"Report scope"; enabled:root.insights.actionState!=="running"
                }
                DirectoryButton {
                    objectName:"report-generate"; Layout.fillWidth:true; Layout.minimumWidth:0
                    text:root.insights.actionState==="running"?"Generating…":"Generate report"
                    wrapLabel:true; active:true; enabled:root.insights.actionState!=="running"
                    onClicked:root.insights.generateReport(root.profiles[profile.currentIndex].id)
                }
            }
            DirectoryButton {visible:!root.contextualActions;width:parent.width;text:"Open latest report";enabled:Boolean(root.report.exists) && root.insights.actionState!=="running";onClicked:root.insights.openLatestReport()}
            DirectoryStatus {width:parent.width;insights:root.insights;route:"reports"}
        }
        Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
        Column {
            width:parent.width;spacing:Config.DirectoryStyle.controlGap
            Text {text:"Latest preview";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Config.DirectoryStyle.bodySize}
            Text {width:parent.width;visible:!root.report.exists;text:"Choose a scope and generate a report. Evidence stays on this device.";wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
            EvidenceDocument {width:parent.width;lines:root.report.preview || []}
        }
    }
}
