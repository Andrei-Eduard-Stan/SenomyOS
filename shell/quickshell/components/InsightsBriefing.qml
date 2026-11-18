import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config
import "BriefingModel.js" as Model

FocusScrollArea {
    id:root
    objectName:"insights-briefing"
    required property var briefing
    readonly property var assessment:Model.assessment(briefing.senomy.systemHealth,briefing.senomy.message)
    readonly property var sources:Model.sources(briefing.data("briefing"),briefing.briefingNow)
    readonly property bool wide:width>=900*Config.DirectoryStyle.textScale
    contentHeight:page.implicitHeight
    ScrollBar.vertical:ShellScrollBar {}
    function navigate(route){if(briefing.state.allowInteraction())briefing.state.insightsSection=route;}
    Column {
        id:page;width:parent.width;spacing:24
        RowLayout {
            width:parent.width
            ExpandedLabel {Layout.fillWidth:true;Layout.minimumWidth:0;text:"BRIEFING";font.pixelSize:22}
            ContextEvidenceMenu {
                Layout.preferredWidth:Config.DirectoryStyle.controlTarget;Layout.preferredHeight:Config.DirectoryStyle.controlTarget
                ownerActive:root.briefing.requestedOpen && !root.briefing.state.modalActive
                contextKey:root.briefing.state.insightsSection
                accessibleLabel:"Briefing actions";componentKey:"insights-briefing"
                copyLabel:"Copy briefing";textLabel:"Save briefing as text"
                report:({message:root.briefing.senomy.message,observations:root.briefing.briefingObservations(),context:root.briefing.briefingContext()})
            }
        }
        GridLayout {
            width:parent.width;columns:root.wide?2:1;columnSpacing:32;rowSpacing:20
            Column {
                Layout.fillWidth:true;Layout.preferredWidth:3;Layout.minimumWidth:0;spacing:10
                Text {objectName:"briefing-assessment";width:parent.width;text:root.assessment.title;textFormat:Text.PlainText;wrapMode:Text.Wrap;color:root.assessment.state==="warning"?Config.Theme.warning:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(28*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold}
                Text {width:parent.width;text:root.assessment.detail;textFormat:Text.PlainText;wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;lineHeight:1.3}
            }
            GridLayout {
                Layout.fillWidth:true;Layout.preferredWidth:2;Layout.minimumWidth:0
                columns:2;columnSpacing:20;rowSpacing:8
                Repeater {
                    model:[{label:"CPU",value:root.briefing.metrics.ready?Math.round(root.briefing.metrics.cpuPercent)+"%":"Unavailable"},{label:"Memory",value:root.briefing.metrics.memoryTotalKib>0?Math.round(root.briefing.metrics.memoryPercent)+"%":"Unavailable"}]
                    Column {
                        required property var modelData
                        Layout.fillWidth:true;Layout.preferredWidth:1;Layout.minimumWidth:0;spacing:6
                        Text {text:modelData.label;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                        Text {width:parent.width;text:modelData.value;wrapMode:Text.NoWrap;color:Config.DirectoryStyle.ink;font.family:modelData.value==="Unavailable"?Config.DirectoryStyle.bodyFont:Config.DirectoryStyle.valueFont;font.pixelSize:modelData.value==="Unavailable"?Config.DirectoryStyle.bodySize:Math.round(24*Config.DirectoryStyle.textScale)}
                    }
                }
            }
        }
        Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
        GridLayout {
            width:parent.width;columns:root.wide?2:1;columnSpacing:32;rowSpacing:28
            Column {
                Layout.fillWidth:true;Layout.preferredWidth:3;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop;spacing:10
                RowLayout {
                    width:parent.width
                    ExpandedLabel {text:"ATTENTION";font.pixelSize:16;Layout.fillWidth:true}
                    Text {text:root.briefing.attention.length+" item"+(root.briefing.attention.length===1?"":"s");color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                }
                Text {width:parent.width;visible:root.briefing.attention.length===0;text:"Nothing to review in the available evidence.";wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
                Repeater {
                    model:root.briefing.attention
                    BriefingAttentionRow {
                        required property var modelData
                        required property int index
                        objectName:index===0?"briefing-priority-action":"briefing-attention-"+modelData.id
                        width:parent.width;entry:modelData
                        enabled:!root.briefing.state.modalActive
                        onDestinationRequested:route=>root.navigate(route)
                    }
                }
            }
            Column {
                Layout.fillWidth:true;Layout.preferredWidth:2;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop;spacing:16
                ExpandedLabel {text:"EVIDENCE COVERAGE";font.pixelSize:16}
                Text {width:parent.width;text:"Package status follows the last verified source checks.";wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;lineHeight:1.3}
                Repeater {
                    model:root.sources
                    Column {
                        required property var modelData
                        width:parent.width;spacing:7
                        GridLayout {
                            width:parent.width;columns:width<420*Config.DirectoryStyle.textScale?1:2;rowSpacing:6
                            Text {Layout.fillWidth:true;Layout.minimumWidth:0;text:modelData.label;wrapMode:Text.Wrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:Font.DemiBold}
                            Text {Layout.fillWidth:true;Layout.minimumWidth:0;wrapMode:Text.Wrap;horizontalAlignment:parent.columns===1?Text.AlignLeft:Text.AlignRight;text:modelData.state;color:modelData.tone==="attention"?Config.Theme.warning:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                        }
                        Text {width:parent.width;text:modelData.age+" · "+modelData.meaning;wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;lineHeight:1.3}
                        Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
                    }
                }
                DirectoryButton {objectName:"briefing-sources-toggle";width:parent.width;text:root.briefing.showSources?"Hide evidence sources":"Evidence sources";wrapLabel:true;onClicked:root.briefing.showSources=!root.briefing.showSources}
            }
        }
        Column {
            width:parent.width;spacing:12
            Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
            ExpandedLabel {text:"SINCE OPENING";font.pixelSize:16}
            Text {width:parent.width;text:root.briefing.compactChanges();wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
            Flow {
                width:parent.width;spacing:8
                DirectoryButton {objectName:"briefing-changes-toggle";width:Math.min(parent.width,180);wrapLabel:true;text:root.briefing.showChangeDetails?"Hide changes":"Show changes";onClicked:root.briefing.showChangeDetails=!root.briefing.showChangeDetails}
                DirectoryButton {width:Math.min(parent.width,180);wrapLabel:true;text:"View timeline";onClicked:root.navigate("timeline")}
                DirectoryButton {objectName:"briefing-system-toggle";width:Math.min(parent.width,220);wrapLabel:true;text:root.briefing.showSystemDetails?"Hide current readings":"Show current readings";onClicked:root.briefing.showSystemDetails=!root.briefing.showSystemDetails}
                DirectoryButton {width:Math.min(parent.width,200);wrapLabel:true;text:"Open Performance";onClicked:if(root.briefing.state.allowInteraction())root.briefing.state.showPrimary("performance",root.briefing.targetScreen?root.briefing.targetScreen.name:"","overview")}
            }
            Text {visible:root.briefing.showChangeDetails;width:parent.width;text:root.briefing.changes().map(r=>r.label+" / "+r.value).join(" · ");wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;lineHeight:1.4}
        }
        GridLayout {
            objectName:"briefing-system-summary";visible:root.briefing.showSystemDetails
            width:parent.width;columns:width>=760?5:width>=480?3:2;columnSpacing:16;rowSpacing:16
            Repeater {model:root.briefing.briefingObservations()
                Column {
                    required property var modelData
                    Layout.fillWidth:true;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop;spacing:8
                    Text {width:parent.width;text:modelData.label;wrapMode:Text.Wrap;color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                    Text {width:parent.width;text:modelData.value;wrapMode:Text.Wrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.valueFont;font.pixelSize:16}
                    Text {width:parent.width;text:modelData.detail;wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                }
            }
        }
        Column {
            width:parent.width;visible:root.briefing.showSources;spacing:12
            ExpandedLabel {text:"SOURCE REGISTER";font.pixelSize:16}
            Repeater {model:root.briefing.briefingContext()
                RowLayout {
                    required property var modelData
                    width:parent.width;spacing:16
                    Text {Layout.preferredWidth:parent.width*.32;text:modelData.label;wrapMode:Text.Wrap;color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                    Text {Layout.fillWidth:true;Layout.minimumWidth:0;text:modelData.value;wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                }
            }
        }
    }
}
