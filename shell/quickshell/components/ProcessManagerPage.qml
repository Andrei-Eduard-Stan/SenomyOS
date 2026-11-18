import QtQuick
import QtQuick.Controls
import "../config" as Config

FocusScope {
    id:root
    objectName:"process-manager"
    required property var performance
    property string query:""
    readonly property bool inspecting:performance.selectedProcessPid>0
    readonly property bool compact:width<850
    readonly property var filtered:(performance.processes || []).filter(p=>!query.trim() || [p.name,p.pid,p.user].join(" ").toLowerCase().includes(query.trim().toLowerCase()))
    function inspect(row) { if(row) performance.selectProcess(row.pid,row.name); }
    function number(value) {return value===undefined || value===null || !isFinite(Number(value))?"—":Number(value).toFixed(1);}

    Column {
        id:toolbar;width:parent.width;spacing:8
        Row {
            width:parent.width;spacing:8
            Text {text:"PROCESS MANAGER";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:16;anchors.verticalCenter:parent.verticalCenter;visible:root.width>=650}
            TextField {
                objectName:"process-search";width:Math.max(120,parent.width-(root.width>=650?220:0));height:Config.DirectoryStyle.touchMode?48:38
                placeholderTextColor:Config.DirectoryStyle.dim;placeholderText:"Search name, PID or user…";text:root.query;onTextEdited:root.query=text
                color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12
                Accessible.name:"Search processes"
                background:Rectangle {color:"transparent";border.color:parent.activeFocus?Config.DirectoryStyle.ink:Config.DirectoryStyle.muted;radius:2}
            }
        }
        Flow {
            width:parent.width;spacing:6
            Repeater {
                model:[{id:"cpu",label:"CPU ↓"},{id:"memory",label:"MEMORY ↓"},{id:"name",label:"NAME A–Z"}]
                DirectoryButton {
                    required property var modelData
                    width:112;height:Config.DirectoryStyle.touchMode?48:38;labelSize:11;text:modelData.label
                    active:root.performance.processSort===modelData.id
                    onClicked:root.performance.configureProcesses("sort",modelData.id)
                }
            }
            Repeater {
                model:[{id:"all",label:"ALL"},{id:"user",label:"MINE"},{id:"active",label:"ACTIVE"},{id:"heavy",label:"HEAVY"}]
                DirectoryButton {
                    required property var modelData
                    width:80;height:Config.DirectoryStyle.touchMode?48:38;labelSize:11;text:modelData.label
                    active:root.performance.processFilter===modelData.id
                    onClicked:root.performance.configureProcesses("filter",modelData.id)
                }
            }
        }
        Text {
            width:parent.width
            text:root.filtered.length+" SHOWN · "+(root.performance.processSummary.process_count || 0)+" TOTAL · "+(root.performance.processSummary.thread_count || 0)+" THREADS · sampled every 3s · up to 512 rows"
            color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;wrapMode:Text.WordWrap
        }
        Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
    }

    Item {
        id:workspace;anchors {left:parent.left;right:parent.right;top:toolbar.bottom;topMargin:12;bottom:parent.bottom}
        FocusScrollArea {
            id:table;objectName:"process-manager-table"
            visible:!root.compact || !root.inspecting
            width:root.inspecting && !root.compact?Math.max(1,parent.width-inspector.width-16):parent.width;height:parent.height
            contentWidth:Math.max(width,770);contentHeight:height;clip:true
            boundsBehavior:Flickable.StopAtBounds
            Column {
                width:table.contentWidth;height:table.height;spacing:4
                Row {
                    height:30
                    Repeater {
                        model:[{text:"PROCESS",width:230},{text:"PID",width:70},{text:"CPU %",width:80},{text:"MiB",width:90},{text:"STATE",width:70},{text:"THREADS",width:80},{text:"USER",width:140}]
                        Text {
                            required property var modelData
                            width:modelData.width;height:30;text:modelData.text
                            color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:11;verticalAlignment:Text.AlignVCenter
                        }
                    }
                }
                ListView {
                    id:list;objectName:"process-manager-list"
                    width:parent.width;height:Math.max(0,parent.height-34);clip:true
                    model:root.filtered;spacing:0;activeFocusOnTab:true
                    onCurrentIndexChanged:if(currentIndex>=0)positionViewAtIndex(currentIndex,ListView.Contain)
                    boundsBehavior:Flickable.StopAtBounds
                    ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
                    Keys.onReturnPressed:root.inspect(currentItem?currentItem.modelData:null)
                    Keys.onSpacePressed:root.inspect(currentItem?currentItem.modelData:null)
                    Keys.onPressed:event=>{if(event.key===Qt.Key_Home){currentIndex=0;event.accepted=true;}else if(event.key===Qt.Key_End){currentIndex=count-1;event.accepted=true;}}
                    delegate:Rectangle {
                        id:row;required property var modelData;required property int index
                        width:list.width;height:Config.DirectoryStyle.touchMode?52:40
                        color:"transparent"
                        border.width:0;border.color:Config.DirectoryStyle.muted
                        Accessible.role:Accessible.ListItem;Accessible.name:modelData.name+", PID "+modelData.pid
                        Row {
                            anchors.fill:parent
                            Repeater {
                                model:[{text:row.modelData.name,width:230},{text:row.modelData.pid,width:70},{text:root.number(row.modelData.cpu_percent),width:80},{text:root.number(row.modelData.memory_mib),width:90},{text:row.modelData.state,width:70},{text:row.modelData.threads ?? "—",width:80},{text:row.modelData.user,width:140}]
                                Text {
                                    required property var modelData
                                    width:modelData.width;height:parent.height;text:modelData.text ?? "—";textFormat:Text.PlainText
                                    color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight
                                }
                            }
                        }
                        Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:1;color:Config.DirectoryStyle.rule}
                        ButtonHoverFrame { focusTarget: list; focusEligible: list.currentIndex === row.index; pointerTarget: area; selected: root.performance.selectedProcessPid===Number(row.modelData.pid); anchors.fill: parent; engaged: row.enabled && area.containsMouse }
                        MouseArea {id:area;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{list.currentIndex=row.index;list.forceActiveFocus();root.inspect(row.modelData);}}
                    }
                }
            }
            Text {
                anchors.centerIn:parent;visible:list.count===0;width:Math.min(parent.width-32,420)
                text:root.performance.error || (root.query?"No processes match this search.":root.performance.processesObservedAt>0?"No processes in this filter.":"Collecting process samples…")
                color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:13;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter
            }
        }
        Rectangle {
            id:inspector;objectName:"process-manager-inspector"
            visible:root.inspecting;anchors.right:parent.right
            width:root.compact?parent.width:Math.min(420,parent.width*0.38);height:parent.height
            color:"transparent";border.color:Config.DirectoryStyle.rule
            FocusScrollArea {
                anchors.fill:parent;anchors.margins:12;contentHeight:details.implicitHeight;clip:true
                Column {
                    id:details;width:parent.width;spacing:10
                    Text {text:"PROCESS INSPECTOR";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:12}
                    Text {width:parent.width;text:root.performance.selectedProcessName+" · PID "+root.performance.selectedProcessPid;textFormat:Text.PlainText;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.valueFont;font.pixelSize:18;wrapMode:Text.WrapAnywhere}
                    DirectoryButton {width:parent.width;text:root.compact?"BACK TO PROCESSES":"CLOSE INSPECTOR";labelSize:11;enabled:root.performance.processActionState!=="running";onClicked:root.performance.selectProcess(0,"")}
                    Text {
                        width:parent.width
                        text:root.performance.processDetailError || ["USER    "+(root.performance.selectedProcess.user || "Loading…"),"STATE   "+(root.performance.selectedProcess.state || "—"),"THREADS "+(root.performance.selectedProcess.threads ?? "—"),"MEMORY  "+(root.performance.selectedProcess.rss_mib ?? "—")+" MiB","OPEN FD "+(root.performance.selectedProcess.fd_count ?? "—"),"EXE     "+(root.performance.selectedProcess.executable || "—"),"DIR     "+(root.performance.selectedProcess.cwd || "—"),"COMMAND "+(root.performance.selectedProcess.command || "—")].join("\n")
                        textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;lineHeight:1.4
                    }
                    Text {width:parent.width;visible:root.performance.selectedProcess.action_allowed!==true;text:"Read-only: process ownership or desktop/session protection prevents signals.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
                    Flow {
                        width:parent.width;spacing:6;visible:root.performance.processActionState!=="pending"
                        Repeater {
                            model:[{id:"terminate",label:"TERMINATE",detail:"Graceful SIGTERM"},{id:"stop",label:"PAUSE",detail:"SIGSTOP"},{id:"continue",label:"RESUME",detail:"SIGCONT"},{id:"kill",label:"FORCE KILL",detail:"Immediate SIGKILL"}]
                            DirectoryButton {
                                required property var modelData
                                objectName:"process-action-"+modelData.id
                                width:Math.max(130,(parent.width-6)/2);text:modelData.label;labelSize:11;detail:modelData.detail
                                enabled:root.performance.selectedProcess.action_allowed===true && root.performance.processActionState!=="running" && !root.performance.managedServices.actions.locked
                                onClicked:root.performance.requestProcessSignal(modelData.id)
                            }
                        }
                    }
                    Column {
                        width:parent.width;spacing:8;visible:root.performance.processActionState==="pending"
                        Text {width:parent.width;text:root.performance.processActionMessage+"\n"+(root.performance.pendingProcessAction==="kill"?"SIGKILL ends this process immediately; unsaved work may be lost.":root.performance.pendingProcessAction==="stop"?"This process will stop running until resumed.":root.performance.pendingProcessAction==="continue"?"This process will resume running.":"SIGTERM asks this process to exit; unsaved work may be lost.");textFormat:Text.PlainText;color:Config.Theme.warning;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;wrapMode:Text.WordWrap}
                        Row {
                            spacing:8
                            DirectoryButton {id:cancel;objectName:"process-cancel";width:112;text:"CANCEL";onClicked:root.performance.cancelProcessAction()}
                            DirectoryButton {objectName:"process-confirm";width:140;text:"CONFIRM";accentColor:Config.Theme.warning;onClicked:root.performance.confirmProcessAction()}
                        }
                    }
                    ConfirmationFocus {view:details;actions:root.performance;actionState:root.performance.processActionState;cancelButton:cancel}
                    Text {width:parent.width;visible:root.performance.processActionState!=="idle" && root.performance.processActionState!=="pending";text:root.performance.processActionState.toUpperCase()+" // "+root.performance.processActionMessage;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12}
                    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
                    SelectionActionReview {width:parent.width;actions:root.performance.managedServices.actions}
                    DirectoryButton {
                        width:parent.width;text:"REVIEW RESTART";labelSize:11
                        detail:root.performance.managedServices.processService?root.performance.managedServices.processService.unit:"No supported owning user service"
                        enabled:root.performance.managedServices.processService!==null && !root.performance.managedServices.actions.locked && !root.performance.managedServices.actions.blocked
                        onClicked:root.performance.managedServices.actions.request(root.performance.managedServices.processService)
                    }
                    Text {width:parent.width;text:"Signals recheck ownership and PID start identity. Restart is available for supported owning user services.";color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;wrapMode:Text.WordWrap}
                }
            }
        }
    }
}
