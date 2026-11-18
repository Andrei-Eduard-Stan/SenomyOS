import QtQuick
import QtQuick.Controls
import "../config" as Config

FocusScrollArea {
    id: root
    property bool contextualActions: false
    required property var insights
    required property string domain
    readonly property var result: (insights.payloads[domain+"Result"] || {}).data || ({})
    readonly property var tasks: insights.tasksFor(domain)
    property string selectedTaskId: ""
    readonly property bool hasResult: (result.output || []).length > 0
    readonly property var selectedTask: tasks.find(t => t.id === selectedTaskId) || tasks[0] || null
    readonly property bool split: width >= 700 * Config.DirectoryStyle.textScale
    contentHeight: column.implicitHeight
    Column {
        id: column;width:parent.width;spacing:10
        ComponentReportMenu {parent:taskHeader;visible:!root.contextualActions;anchors.right:parent.right;componentKey:"insights-"+root.domain;targetItem:column;report:root.result}
        Loader {
            parent:taskHeader;active:root.contextualActions; visible:active; anchors.right:parent.right
            width:active?(Config.DirectoryStyle.touchMode?48:38):0; height:width
            sourceComponent: ContextEvidenceMenu {
                contextKey:root.domain; componentKey:"insights-"+root.domain
                accessibleLabel:root.domain === "console" ? "Console result actions" : "Diagnostic result actions"
                evidenceAvailable:(root.result.output || []).length > 0
                report:root.result; copyLabel:"Copy task result"; textLabel:"Save task result as text"
                extraActions:[{id:"refresh",label:"Refresh task catalog",enabled:!root.insights.busy,reason:"Catalog refresh in progress"}]
                onExtraActionRequested:action => { if(action === "refresh" && !root.insights.busy) root.insights.refresh(root.domain,false); }
            }
        }
        Item {id:taskHeader;width:parent.width;height:Config.DirectoryStyle.controlTarget
            Text {x:Config.DirectoryStyle.controlInset;width:Math.max(1,parent.width-x-48);anchors.verticalCenter:parent.verticalCenter;text:root.domain==="console"?"Commands":"Read-only checks";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.weight:Font.DemiBold;font.pixelSize:Config.DirectoryStyle.bodySize+2;wrapMode:Text.WordWrap}
        }
        DirectoryStatus {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;insights:root.insights;route:root.domain}
        Flow {
            width:parent.width;spacing:Config.DirectoryStyle.sectionGap
            Column {
                id:commands;width:root.split?Math.floor((parent.width-parent.spacing)*0.48):parent.width;spacing:2
                Repeater {
                    model:root.tasks
                    delegate:ItemDelegate {
                        id:command
                        required property var modelData
                        objectName:"task-"+modelData.id
                        text:modelData.title
                        Keys.onReturnPressed:root.selectedTaskId=modelData.id
                        readonly property bool current:!!root.selectedTask && root.selectedTask.id===modelData.id
                        width:commands.width
                        implicitHeight:Math.max(Config.DirectoryStyle.controlTarget,commandLabel.implicitHeight+2*Config.DirectoryStyle.controlVerticalInset)
                        leftPadding:Config.DirectoryStyle.controlInset;rightPadding:Config.DirectoryStyle.controlInset
                        topPadding:Config.DirectoryStyle.controlVerticalInset;bottomPadding:Config.DirectoryStyle.controlVerticalInset
                        hoverEnabled:true;focusPolicy:Qt.TabFocus;activeFocusOnTab:true
                        Accessible.name:modelData.title;Accessible.selected:current
                        onClicked:root.selectedTaskId=modelData.id
                        background:Rectangle {color:command.current?Config.DirectoryStyle.selection:"transparent"}
                        ButtonHoverFrame {anchors.fill:parent;focused:command.visualFocus;engaged:command.hovered}
                        contentItem:Item {
                            implicitHeight:commandLabel.implicitHeight
                            Text {id:commandLabel;width:Math.max(1,parent.width-code.width-Config.DirectoryStyle.controlGap);text:command.modelData.title;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:command.current?Font.DemiBold:Font.Normal;anchors.verticalCenter:parent.verticalCenter}
                            Text {id:code;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;text:command.modelData.code || "";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                        }
                    }
                }
            }
            Column {
                id:taskDetail;width:root.split?parent.width-commands.width-parent.spacing:parent.width;spacing:Config.DirectoryStyle.controlGap
                visible:!!root.selectedTask
                Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:root.selectedTask?root.selectedTask.title:"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:Font.DemiBold}
                Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:root.selectedTask?root.selectedTask.summary || "":"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:root.selectedTask?root.selectedTask.command_preview || root.selectedTask.preview || "":"";visible:!!text;textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:root.selectedTask?root.selectedTask.scope || "":"";visible:!!text;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:root.selectedTask && root.selectedTask.available===false?"Unavailable":"";visible:!!text;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                DirectoryButton {
                    objectName:"runSelectedTask";width:Math.min(parent.width,180*Config.DirectoryStyle.textScale)
                    wrapLabel:true;text:root.insights.actionState==="running"?"Running…":root.domain==="console"?"Run command":"Run check"
                    enabled:!!root.selectedTask && root.selectedTask.available!==false && root.insights.actionState!=="running"
                    onClicked:root.insights.runTask(root.domain,root.selectedTask.id)
                }
            }
        }
        Text {width:parent.width;visible:root.insights.tasksFor(root.domain).length===0;text:"No commands available. Refresh to retry.";color:Config.DirectoryStyle.muted;font.family:Config.Theme.fontFamily;wrapMode:Text.WordWrap}
        DirectoryButton {visible:!root.contextualActions;width:parent.width;text:"Refresh commands";enabled:!root.insights.busy;onClicked:root.insights.refresh(root.domain,false)}
        Rectangle {width:parent.width;height:1;color:Config.Theme.surfaceHover}
        Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;text:root.result.title||"Results";textFormat:Text.PlainText;color:Config.Theme.foreground;font.family:Config.Theme.fontFamily;wrapMode:Text.WordWrap}
        DirectoryStatus {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;visible:root.hasResult || root.insights.actionState!=="idle";insights:root.insights;route:root.domain+"Result"}
        Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;visible:!root.hasResult && root.insights.actionState==="idle";text:"Choose a check and run it to view its result here.";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;wrapMode:Text.WordWrap}
        FocusScrollArea {
            id: output;x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;visible:root.hasResult;height:visible?Math.min(360,Math.max(80,contentHeight)):0;contentHeight:outputColumn.implicitHeight
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
                        color:Config.DirectoryStyle.muted;font.family:Config.Theme.fontFamily;font.pixelSize: Config.DirectoryStyle.detailSize;wrapMode:Text.WrapAnywhere
                    }
                }
            }
        }
    }
}
