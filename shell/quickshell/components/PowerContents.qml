import QtQuick
import QtQuick.Controls
import "../config" as Config
import "calendar" as CalendarUi

FocusScope {
    id: root
    required property var service
    property bool surfaceOpen: true
    property string mode: "now"
    property string method: "delay"
    property string selectedAction: ""
    property bool editorOpen: true
    property bool ready: false
    property date suggestedTime: new Date(Date.now()+3600000)
    readonly property bool reviewing: service.state==="pending"
    readonly property bool working: service.state==="running"
    readonly property var current: service.schedule||{}
    readonly property bool hasRecord: ["scheduled","running","missed","failed","unverified"].includes(current.state)
    readonly property bool monitoring: hasRecord&&!editorOpen&&!reviewing
    readonly property bool stacked: width<520*Config.DirectoryStyle.textScale
    readonly property real chamberGap: 24
    readonly property real navigationWidth: Math.round((width-chamberGap)*0.36)
    readonly property real executionHeight: chamberHeader.height+12+body.implicitHeight+(reviewing?reviewFooter.height+12:0)
    property real preferredHeight: Math.max(280,stacked?navigation.implicitHeight+chamberGap+executionHeight:Math.max(navigation.implicitHeight,executionHeight))
    property string localTimezone: Qt.formatDateTime(new Date(),"t")
    readonly property var actions: [
        {id:"lock",label:"Lock",icon:"\uf023"},
        {id:"suspend",label:"Sleep",icon:"\uf186"},
        {id:"logout",label:"Log out",icon:"\uf2f5"},
        {id:"reboot",label:"Restart",icon:"\uf2f1"},
        {id:"poweroff",label:"Shut down",icon:"\uf011"}
    ]
    signal dismissRequested()
    Behavior on preferredHeight {NumberAnimation {duration:Config.Motion.duration(140);easing.type:Easing.OutCubic}}
    function actionLabel(action){return {lock:"Lock",suspend:"Sleep",logout:"Log out",reboot:"Restart",poweroff:"Shut down"}[action]||"Session";}
    function commandTitle(action){return {lock:"LOCK DESKTOP",suspend:"SLEEP SYSTEM",logout:"END SESSION",reboot:"RESTART SYSTEM",poweroff:"SHUT DOWN"}[action]||"";}
    function description(action){return {lock:"Secure this desktop. Applications keep running.",suspend:"Pause this device. Applications remain in memory.",logout:"Close applications and end this login.",reboot:"Close applications and restart the machine.",poweroff:"Close applications and turn off the machine."}[action]||"";}
    function consequence(action){return ["logout","reboot","poweroff"].includes(action)?"Unsaved work may be lost.":action==="suspend"?"Save your work before this device sleeps.":"";}
    function impact(action){return description(action)+(consequence(action)?" "+consequence(action):"");}
    function focusInitial(){if(reviewing)cancelReview.forceActiveFocus();else if(monitoring)scheduleView.focusCancel();else if(commands.count)commands.itemAt(0).focusForReason(Qt.PopupFocusReason);}
    function opening(){
        localTimezone=Qt.formatDateTime(new Date(),"t");suggestedTime=new Date(Date.now()+3600000);
        if(!hasRecord&&!reviewing){dateField.text=Qt.formatDate(suggestedTime,"yyyy-MM-dd");timeField.text=Qt.formatTime(suggestedTime,"HH:mm");foldChoice.currentIndex=0;}
        if(!reviewing){editorOpen=!hasRecord;selectedAction=hasRecord?current.action:"";mode="now";}
        Qt.callLater(focusInitial);
    }
    function revealExecution(){if(stacked)Qt.callLater(()=>outerScroll.contentY=Math.min(Math.max(0,outerScroll.contentHeight-outerScroll.height),execution.y));}
    function focusError(){const errors=service.fieldErrors||{};const item=errors.seconds?hoursField:errors.date?dateField:errors.time?timeField:errors.fold?foldChoice:null;if(item)Qt.callLater(()=>{if(typeof item.focusInput==="function")item.focusInput();else item.forceActiveFocus();scroller.revealFocus();outerScroll.revealFocus();});}
    function selectAction(action){selectedAction=action;editorOpen=true;service.clearFeedback();revealExecution();}
    function setMode(value){mode=value;editorOpen=true;service.clearFeedback();}
    function monitorSchedule(){editorOpen=false;selectedAction=current.action||"";service.clearFeedback();Qt.callLater(()=>scheduleView.focusCancel());revealExecution();}
    function settle(){
        if(service.state!=="succeeded")return;
        if(hasRecord){editorOpen=false;selectedAction=current.action||"";mode="now";}
        else {editorOpen=true;selectedAction="";mode="now";}
    }
    function editSchedule(){
        const form=current.form||{};selectedAction=current.action||"";mode="schedule";method=current.mode||"delay";editorOpen=true;
        const seconds=Number(form.seconds||Number(form.amount||30)*(form.unit==="hours"?3600:60));
        hoursField.text=String(Math.floor(seconds/3600)).padStart(2,"0");minutesField.text=String(Math.floor(seconds%3600/60)).padStart(2,"0");secondsField.text=String(seconds%60).padStart(2,"0");
        dateField.text=form.date||Qt.formatDate(new Date(current.dueEpoch*1000),"yyyy-MM-dd");timeField.text=form.time||Qt.formatTime(new Date(current.dueEpoch*1000),"HH:mm");foldChoice.currentIndex=form.fold===0?1:form.fold===1?2:0;
        service.clearFeedback();Qt.callLater(()=>reviewButton.forceActiveFocus());revealExecution();
    }
    function durationPreview(){
        const values=[hoursField.text,minutesField.text,secondsField.text];
        if(!values.every(v=>/^\d+$/.test(v))||Number(values[1])>59||Number(values[2])>59)return "Enter a valid duration";
        const n=values.map(Number),parts=[];
        if(n[0])parts.push(n[0]+(n[0]===1?" hour":" hours"));
        if(n[1])parts.push(n[1]+(n[1]===1?" minute":" minutes"));
        if(n[2])parts.push(n[2]+(n[2]===1?" second":" seconds"));
        return parts.length?"In "+parts.join(" "):"Enter a duration";
    }
    function reviewSchedule(){
        if(mode==="now"){service.request(selectedAction);return;}
        const values=[hoursField.text,minutesField.text,secondsField.text];
        if(method==="delay"&&(!values.every(v=>/^\d+$/.test(v))||Number(values[1])>59||Number(values[2])>59)){service.fieldErrors={seconds:"Enter valid hours, minutes and seconds."};focusError();return;}
        service.prepare({action:selectedAction,mode:method,seconds:String(Number(values[0])*3600+Number(values[1])*60+Number(values[2])),date:dateField.text,time:timeField.text,fold:foldChoice.currentIndex?foldChoice.currentIndex-1:null});
    }
    function reveal(){if(ready)chamberReveal.restart();}
    onModeChanged: reveal()
    onMethodChanged: reveal()
    onSelectedActionChanged: reveal()
    onEditorOpenChanged: reveal()
    onStackedChanged: if(ready)outerScroll.contentY=0
    onSurfaceOpenChanged: if(surfaceOpen)opening()
    Component.onCompleted:{ready=true;opening();}
    Connections {
        target:root.service
        function onStateChanged(){root.settle();}
        function onScheduleChanged(){root.settle();if(!root.selectedAction&&root.hasRecord){root.editorOpen=false;root.selectedAction=root.current.action||"";}}
        function onPrepared(){if(root.surfaceOpen){Qt.callLater(()=>cancelReview.forceActiveFocus());root.revealExecution();}}
        function onFieldErrorsChanged(){if(root.surfaceOpen)root.focusError();}
    }
    NumberAnimation {id:chamberReveal;target:body;property:"opacity";from:0.72;to:1;duration:Config.Motion.duration(100)}
    ConfirmationFocus {view:root;actions:root.service;actionState:root.service.state;cancelButton:cancelReview}
    FocusScrollArea {
        id:outerScroll;anchors.fill:parent;anchors.bottomMargin:root.stacked&&root.reviewing?reviewFooter.height+12:0
        contentHeight:root.stacked?navigation.implicitHeight+root.chamberGap+execution.height:Math.max(height,navigation.implicitHeight)
        interactive:contentHeight>height
        ScrollBar.vertical:ShellScrollBar {}
        Item {
            width:outerScroll.width;height:outerScroll.contentHeight
            Column {
                id:navigation;objectName:"session-action-chamber";width:root.stacked?parent.width:root.navigationWidth;spacing:8
                Text {width:parent.width;height:Config.QuickPanelStyle.target;text:"SESSION /";verticalAlignment:Text.AlignVCenter;color:Config.QuickPanelStyle.ink;font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Config.QuickPanelStyle.titleSize;elide:Text.ElideRight}
                Text {width:parent.width;text:"SYS.CONTROL / LOCAL";color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize;wrapMode:Text.WordWrap}
                Item {width:1;height:4}
                Column {
                    width:parent.width;spacing:2
                    Repeater {
                        id:commands;model:root.actions
                        SessionCommand {
                            required property var modelData
                            required property int index
                            Keys.onDownPressed:if(index+1<commands.count)commands.itemAt(index+1).focusForReason(Qt.TabFocusReason)
                            Keys.onUpPressed:if(index>0)commands.itemAt(index-1).focusForReason(Qt.BacktabFocusReason)
                            Keys.onRightPressed:if(root.monitoring)scheduleView.focusCancel();else executionMode.focusFirst()
                            objectName:"session-action-"+modelData.id;width:parent.width;text:modelData.label;icon:modelData.icon;selected:root.selectedAction===modelData.id
                            enabled:root.service.supported(modelData.id)&&!root.service.busy&&!root.reviewing&&!root.working
                            onClicked:root.selectAction(modelData.id)
                        }
                    }
                }
            }
            FocusScope {
                id:execution;objectName:"session-execution-chamber"
                x:root.stacked?0:navigation.width+root.chamberGap;y:root.stacked?navigation.implicitHeight+root.chamberGap:0
                width:root.stacked?parent.width:parent.width-x
                height:root.stacked?chamberHeader.height+12+body.implicitHeight:root.height
                Row {
                    id:chamberHeader;width:parent.width;height:Config.QuickPanelStyle.target;spacing:4
                    Text {width:parent.width-48;height:parent.height;verticalAlignment:Text.AlignVCenter;text:root.monitoring?"03 / ACTIVE SCHEDULE":root.reviewing?"02 / REVIEW":"02 / EXECUTION";color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize;elide:Text.ElideRight}
                    DashboardButton {objectName:"session-close";width:44;height:parent.height;text:"×";accessibleLabel:"Close session controls";headerControl:true;enabled:!root.working;onClicked:{if(root.reviewing)root.service.cancel();root.dismissRequested();}}
                }
                FocusScrollArea {
                    id:scroller;y:chamberHeader.height+12;width:parent.width
                    height:root.stacked?body.implicitHeight:Math.max(0,parent.height-y-(root.reviewing?reviewFooter.height+12:0))
                    contentHeight:body.implicitHeight;interactive:!root.stacked&&contentHeight>height;focusMargin:12
                    ScrollBar.vertical:ShellScrollBar {}
                    Column {
                        id:body;width:Math.max(1,scroller.width-4);spacing:12
                        Text {visible:!!root.service.error;width:parent.width;text:root.service.error;wrapMode:Text.WordWrap;color:Config.Theme.danger;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize}
                        Text {visible:root.working&&!root.monitoring;width:parent.width;text:"Sending request…";color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize}
                        Text {visible:!root.service.available;width:parent.width;text:root.service.unavailableReason;wrapMode:Text.WordWrap;color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize}
                        DashboardButton {visible:!root.service.available;objectName:"session-refresh";width:parent.width;text:"RETRY STATUS";headerControl:true;enabled:!root.service.busy;onClicked:root.service.refresh()}
                        SessionScheduleMonitor {id:scheduleView;objectName:"session-schedule-card";visible:root.monitoring;width:parent.width;service:root.service;onEditRequested:root.editSchedule()}
                        Column {
                            visible:root.reviewing;width:parent.width;spacing:12
                            Text {width:parent.width;text:root.service.review?root.service.review.label:"Checking this login…";color:Config.QuickPanelStyle.ink;font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Config.QuickPanelStyle.deviceSize;wrapMode:Text.WordWrap}
                            Text {width:parent.width;text:root.service.review?root.service.review.dueLabel:"Preparing review…";color:Config.QuickPanelStyle.ink;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize;wrapMode:Text.WordWrap}
                            Text {width:parent.width;text:root.service.pendingKind==="cancel"?"Cancel this instruction. Nothing will run.":root.impact(root.service.pendingAction);color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize;wrapMode:Text.WordWrap}
                            Text {visible:!!(root.service.review&&root.service.review.replaces);width:parent.width;text:root.service.review?"REPLACE / "+root.service.review.replaces:"";color:Config.QuickPanelStyle.ink;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize;wrapMode:Text.WordWrap}
                            Text {visible:!!(root.service.review&&root.service.review.mode!=="now");width:parent.width;text:root.service.review&&root.service.review.mode==="at"?"Persistent instruction. No wake or logged-out execution. Missed deadlines require review.":"Temporary for this login. Starts on confirmation. Missed deadlines require review.";color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.metadataSize;wrapMode:Text.WordWrap}
                            Text {visible:!!(root.service.review&&root.service.review.requiresAuth);width:parent.width;text:"System authentication may be required. Permission and inhibitor checks remain in force.";color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize;wrapMode:Text.WordWrap}
                        }
                        Column {
                            visible:!root.monitoring&&!root.reviewing;width:parent.width;spacing:12
                            SessionSegments {id:executionMode;width:parent.width;value:root.mode;choices:[{id:"now",label:"NOW"},{id:"schedule",label:"SCHEDULE",enabled:root.service.schedulingAvailable}];enabled:!root.working;onChosen:value=>root.setMode(value)}
                            Text {objectName:"session-idle-instruction";visible:!root.selectedAction;width:parent.width;text:"Select a command";color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize}
                            DashboardButton {objectName:"session-view-active";visible:root.hasRecord;width:parent.width;text:root.current.state==="scheduled"?"← ACTIVE SCHEDULE":"← "+String(root.current.state||"").toUpperCase()+" SCHEDULE";headerControl:true;labelSize:Config.QuickPanelStyle.metadataSize;onClicked:root.monitorSchedule()}
                            Column {
                                visible:!!root.selectedAction&&root.editorOpen;width:parent.width;spacing:10
                                Text {width:parent.width;text:root.commandTitle(root.selectedAction);color:Config.QuickPanelStyle.ink;font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Config.QuickPanelStyle.deviceSize;wrapMode:Text.WordWrap}
                                Text {visible:root.mode==="now";width:parent.width;text:root.description(root.selectedAction);color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize;wrapMode:Text.WordWrap}
                                Text {visible:root.mode==="now"&&!!root.consequence(root.selectedAction);width:parent.width;text:root.consequence(root.selectedAction);color:Config.QuickPanelStyle.ink;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize;wrapMode:Text.WordWrap}
                                Column {
                                    visible:root.mode==="schedule";width:parent.width;spacing:10
                                    SessionSegments {width:parent.width;value:root.method;choices:[{id:"delay",label:"COUNTDOWN"},{id:"at",label:"DATE & TIME"}];onChosen:value=>{root.method=value;root.service.clearFeedback();}}
                                    Row {
                                        visible:root.method==="delay";width:parent.width;spacing:width<300?2:8
                                        CountdownField {id:hoursField;objectName:"session-hours";width:(parent.width-2*parent.spacing)/3;label:"HH";maximum:168;onEdited:root.service.clearFeedback()}
                                        CountdownField {id:minutesField;objectName:"session-minutes";width:(parent.width-2*parent.spacing)/3;label:"MM";text:"30";onEdited:root.service.clearFeedback()}
                                        CountdownField {id:secondsField;objectName:"session-seconds";width:(parent.width-2*parent.spacing)/3;label:"SS";onEdited:root.service.clearFeedback()}
                                    }
                                    CalendarUi.CalendarFieldMessage {visible:root.method==="delay"&&!!root.service.fieldErrors.seconds;message:root.service.fieldErrors.seconds||""}
                                    Column {
                                        visible:root.method==="at";width:parent.width;spacing:8
                                        CalendarUi.CalendarDateField {id:dateField;objectName:"session-date-editor";fieldObjectName:"session-date";width:parent.width;text:Qt.formatDate(root.suggestedTime,"yyyy-MM-dd");validationMessage:root.service.fieldErrors.date||"";accessibleName:"Scheduled local date"}
                                        CalendarUi.CalendarFieldMessage {message:root.service.fieldErrors.date||""}
                                        CalendarUi.CalendarTextField {id:timeField;objectName:"session-time";width:parent.width;text:Qt.formatTime(root.suggestedTime,"HH:mm");placeholderText:"HH:MM · local time";maximumLength:5;validationMessage:root.service.fieldErrors.time||"";Accessible.name:"Local time, 24-hour HH:MM";onTextEdited:root.service.clearFeedback()}
                                        CalendarUi.CalendarFieldMessage {message:root.service.fieldErrors.time||""}
                                        ShellComboBox {id:foldChoice;objectName:"session-clock-fold";visible:!!root.service.fieldErrors.fold||currentIndex>0;width:parent.width;model:["Repeated hour: choose occurrence","First occurrence","Second occurrence"];Accessible.name:"Which repeated clock hour"}
                                        CalendarUi.CalendarFieldMessage {message:root.service.fieldErrors.fold||""}
                                    }
                                    Text {objectName:"session-execution-preview";width:parent.width;text:root.method==="delay"?root.durationPreview():dateField.text+" / "+timeField.text+" LOCAL · "+root.localTimezone;color:Config.QuickPanelStyle.ink;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize;wrapMode:Text.WordWrap}
                                    Text {width:parent.width;text:root.method==="at"?"Persists across login and reboot. No wake or logged-out execution.":"Temporary for this login. Missed deadlines require review.";color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.metadataSize;wrapMode:Text.WordWrap}
                                }
                                DashboardButton {id:reviewButton;objectName:"session-review-schedule";width:parent.width;text:root.mode==="now"?"REVIEW "+root.actionLabel(root.selectedAction).toUpperCase():"REVIEW SCHEDULE";enabled:!!root.selectedAction&&!root.working&&!root.service.busy&&(root.mode==="now"||root.service.schedulingAvailable);onClicked:root.reviewSchedule()}
                                Text {visible:root.service.available&&!root.service.schedulingAvailable;width:parent.width;text:root.service.unavailableReason;color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize;wrapMode:Text.WordWrap}
                            }
                            Text {visible:!!root.service.message&&!root.hasRecord;width:parent.width;text:root.service.message;wrapMode:Text.WordWrap;color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize}
                        }
                    }
                }
            }
        }
    }
    Row {
        id:reviewFooter;visible:root.reviewing;anchors.bottom:parent.bottom
        x:root.stacked?0:root.navigationWidth+root.chamberGap;width:root.stacked?parent.width:parent.width-x
        height:Config.QuickPanelStyle.target;spacing:8
        DashboardButton {id:cancelReview;objectName:"powerCancel";width:(parent.width-8)/2;height:parent.height;text:"BACK";headerControl:true;onClicked:root.service.cancel()}
        DashboardButton {objectName:"session-confirm";width:(parent.width-8)/2;height:parent.height;text:root.service.pendingKind==="cancel"?"CANCEL SCHEDULE":root.service.review&&root.service.review.mode!=="now"?(root.service.review.replaces?"REPLACE SCHEDULE":"CONFIRM SCHEDULE"):"CONFIRM NOW";labelSize:Config.QuickPanelStyle.metadataSize;enabled:!!root.service.review&&!root.service.busy;onClicked:root.service.confirm()}
    }
}
