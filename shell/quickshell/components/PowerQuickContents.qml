import QtQuick
import "interaction" as Interaction
import QtQuick.Controls
import "../config" as Config
import "calendar" as CalendarUi

FocusScope {
    id: root
    Interaction.ContentMotion {targetItem:body;context:[root.selectedAction,root.mode,root.method,root.reviewing,root.monitoring].join(":");active:root.surfaceOpen}
    objectName:"power-contents"
    required property var service
    property bool surfaceOpen: true
    property bool resetOnOpen: true
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
    readonly property bool stacked: width<400*Config.DirectoryStyle.textScale
    readonly property real executionHeight:body.implicitHeight
    readonly property real preferredHeight:header.height+12+body.implicitHeight+(footer.visible?footer.implicitHeight+12:0)
    property string localTimezone: Qt.formatDateTime(new Date(),"t")
    readonly property var actions: [
        {id:"lock",label:"Lock",icon:"\uf023"},
        {id:"suspend",label:"Sleep",icon:"\uf186"},
        {id:"logout",label:"Log out",icon:"\uf2f5"},
        {id:"reboot",label:"Restart",icon:"\uf2f1"},
        {id:"poweroff",label:"Shut down",icon:"\uf011"}
    ]
    signal dismissRequested()
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
    function revealExecution(){Qt.callLater(()=>outerScroll.contentY=0);}
    function focusError(){const errors=service.fieldErrors||{};const item=errors.seconds?hoursField:errors.date?dateField:errors.time?timeField:errors.fold?foldChoice:null;if(item)Qt.callLater(()=>{if(typeof item.focusInput==="function")item.focusInput();else item.forceActiveFocus();outerScroll.revealFocus();});}
    function selectAction(action){selectedAction=action;editorOpen=true;service.clearFeedback();revealExecution();Qt.callLater(()=>executionMode.focusFirst());}
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
    function reveal(){if(ready)revealExecution();}
    onModeChanged: reveal()
    onMethodChanged: reveal()
    onSelectedActionChanged: reveal()
    onEditorOpenChanged: reveal()
    onStackedChanged: if(ready)outerScroll.contentY=0
    onSurfaceOpenChanged: if(surfaceOpen && resetOnOpen)opening()
    Component.onCompleted:{ready=true;opening();}
    Connections {
        target:root.service
        function onStateChanged(){root.settle();}
        function onScheduleChanged(){root.settle();if(!root.selectedAction&&root.hasRecord){root.editorOpen=false;root.selectedAction=root.current.action||"";}}
        function onPrepared(){if(root.surfaceOpen){Qt.callLater(()=>cancelReview.forceActiveFocus());root.revealExecution();}}
        function onFieldErrorsChanged(){if(root.surfaceOpen)root.focusError();}
    }
    function chooseAnother(){selectedAction="";mode="now";editorOpen=true;service.clearFeedback();Qt.callLater(focusInitial);}
    function back(){if(reviewing || working || monitoring || !selectedAction)return false;if(hasRecord)monitorSchedule();else chooseAnother();return true;}
    // Review text remains keyboard-readable even when the footer owns focus.
    Keys.onPressed:event=>{
        if(!root.reviewing)return;
        const limit=Math.max(0,outerScroll.contentHeight-outerScroll.height);
        if(event.key===Qt.Key_PageDown)outerScroll.contentY=Math.min(limit,outerScroll.contentY+outerScroll.height*.8);
        else if(event.key===Qt.Key_PageUp)outerScroll.contentY=Math.max(0,outerScroll.contentY-outerScroll.height*.8);
        else if(event.key===Qt.Key_End)outerScroll.contentY=limit;
        else if(event.key===Qt.Key_Home)outerScroll.contentY=0;
        else return;
        event.accepted=true;
    }
    ConfirmationFocus {view:root;actions:root.service;actionState:root.service.state;cancelButton:cancelReview}
    Row {
        id:header;width:parent.width;height:Math.max(Config.DirectoryStyle.controlTarget,identity.implicitHeight);spacing:8
        QuietButton {id:backButton;objectName:"session-back";visible:!!root.selectedAction&&!root.reviewing&&!root.monitoring&&!root.working;width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf104";accessibleLabel:root.hasRecord?"Back to schedule":"Choose another action";onClicked:root.back()}
        Column {
            id:identity;width:Math.max(1,parent.width-close.width-8-(backButton.visible?backButton.width+8:0));anchors.verticalCenter:parent.verticalCenter;spacing:4
            Text {width:parent.width;text:"// "+(root.reviewing?"Confirm":root.monitoring?"Timer":root.selectedAction?root.actionLabel(root.selectedAction):"Power");color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Math.round(16*Config.DirectoryStyle.textScale)}
        }
        QuietButton {id:close;objectName:"session-close";width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf00d";accessibleLabel:"Close Power";enabled:!root.working;onClicked:{if(root.reviewing)root.service.cancel();root.dismissRequested();}}
    }
    Column {
        id:footer;width:parent.width;anchors.bottom:parent.bottom;spacing:12;visible:root.reviewing || (!!root.selectedAction&&!root.monitoring)
        IslandRule {width:parent.width;leadingPoint:false}
        Flow {
            id:reviewFooter;visible:root.reviewing;width:parent.width;spacing:8
            readonly property string confirmText:root.service.pendingKind==="cancel"?"Cancel timer":root.service.review&&root.service.review.mode!=="now"?(root.service.review.replaces?"Replace timer":"Confirm timer"):"Confirm "+root.actionLabel(root.service.pendingAction)
            TextMetrics {id:confirmMeasure;text:reviewFooter.confirmText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
            readonly property int columns:width>=2*(confirmMeasure.advanceWidth+2*Config.DirectoryStyle.controlInset)+8?2:1
            readonly property real cellWidth:(width-(columns-1)*8)/columns
            QuietButton {id:cancelReview;objectName:"powerCancel";width:reviewFooter.cellWidth;text:"Back";onClicked:root.service.cancel()}
            QuietButton {objectName:"session-confirm";width:reviewFooter.cellWidth;text:reviewFooter.confirmText;warning:["logout","reboot","poweroff"].includes(root.service.pendingAction);enabled:!!root.service.review&&!root.service.busy;onClicked:root.service.confirm()}
        }
        QuietButton {id:reviewButton;objectName:"session-review-schedule";visible:!root.reviewing;width:parent.width;text:root.working?"Sending request…":root.mode==="now"?"Review "+root.actionLabel(root.selectedAction):"Review schedule";enabled:!!root.selectedAction&&!root.working&&!root.service.busy&&(root.mode==="now" || root.service.schedulingAvailable);onClicked:root.reviewSchedule()}
    }
    FocusScrollArea {
        id:outerScroll;objectName:"power-viewport";anchors.fill:parent;anchors.topMargin:header.height+12;anchors.bottomMargin:footer.visible?footer.implicitHeight+12:0
        contentHeight:body.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
        Column {
            id:body;width:outerScroll.width-(Config.DirectoryStyle.touchMode?24:10);spacing:12
            Text {visible:!!root.service.error;width:parent.width;text:root.service.error;wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:Config.Theme.danger;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
            Text {visible:root.working;width:parent.width;text:"Sending request. Waiting for the session manager…";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
            Text {visible:!root.service.available;width:parent.width;text:root.service.unavailableReason;wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
            QuietButton {visible:!root.service.available;objectName:"session-refresh";width:parent.width;text:"Retry status";enabled:!root.service.busy;onClicked:root.service.refresh()}
            QuietButton {objectName:"session-view-active";visible:root.hasRecord&&!root.monitoring&&!root.reviewing;width:parent.width;text:(root.current.state==="scheduled"?"Timer active · ":"Saved instruction · ")+root.actionLabel(root.current.action);onClicked:root.monitorSchedule()}
            Text {visible:root.hasRecord&&!root.monitoring&&!root.reviewing&&root.current.state==="scheduled";width:parent.width;text:"Your existing timer remains active while you review other actions.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
            Item {
                id:chooser;objectName:"power-action-chooser";visible:!root.selectedAction&&!root.monitoring&&!root.reviewing;width:parent.width
                readonly property real minCell:Math.max(72,52*Config.DirectoryStyle.textScale)
                readonly property int columns:width>=5*minCell?5:width>=3*minCell?3:width>=2*minCell?2:1
                readonly property real cellWidth:width/columns
                readonly property real cellHeight:Math.max(76,Math.ceil(22*Config.DirectoryStyle.textScale)+2*Math.ceil(Config.DirectoryStyle.bodySize*1.25)+16)
                implicitHeight:Math.ceil(root.actions.length/columns)*cellHeight+(Math.ceil(root.actions.length/columns)-1)*8
                Repeater {
                    id:commands;model:root.actions
                    QuietButton {
                        id:command;required property var modelData;required property int index
                        readonly property int row:Math.floor(index/chooser.columns)
                        readonly property int rowCount:Math.min(chooser.columns,root.actions.length-row*chooser.columns)
                        objectName:"session-action-"+modelData.id
                        x:(index%chooser.columns)*chooser.cellWidth+(chooser.columns-rowCount)*chooser.cellWidth/2
                        y:row*(chooser.cellHeight+8);width:chooser.cellWidth;height:chooser.cellHeight
                        enabled:root.service.supported(modelData.id)&&!root.service.busy&&!root.reviewing&&!root.working
                        accessibleLabel:modelData.label
                        ToolTip.visible:false
                        background.visible:visualFocus || down
                        function focusForReason(reason){focusReason=reason;forceActiveFocus(reason);}
                        function focusIndex(next){if(next>=0 && next<commands.count)commands.itemAt(next).focusForReason(Qt.TabFocusReason);}
                        Keys.onRightPressed:focusIndex(index+1)
                        Keys.onLeftPressed:focusIndex(index-1)
                        Keys.onDownPressed:focusIndex(index+chooser.columns)
                        Keys.onUpPressed:focusIndex(index-chooser.columns)
                        Keys.onPressed:event=>{if(event.key===Qt.Key_Home){focusIndex(0);event.accepted=true;}else if(event.key===Qt.Key_End){focusIndex(commands.count-1);event.accepted=true;}}
                        onClicked:root.selectAction(modelData.id)
                        contentItem:Item {
                            Text {id:icon;width:parent.width;height:Math.ceil(24*Config.DirectoryStyle.textScale);y:(parent.height-height-8-caption.implicitHeight)/2;text:command.modelData.icon;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:Math.round(22*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink;Accessible.ignored:true}
                            Text {id:caption;x:4;width:parent.width-8;y:icon.y+icon.height+8;text:command.modelData.label;textFormat:Text.PlainText;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink;Accessible.ignored:true}
                        }
                        Rectangle {anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:1;height:Math.min(32*Config.DirectoryStyle.textScale,parent.height-20);visible:command.index%chooser.columns<chooser.columns-1 && command.index<root.actions.length-1;color:Config.DirectoryStyle.rule;Accessible.ignored:true}
                    }
                }
            }
            Column {
                visible:root.reviewing;width:parent.width;spacing:12
                Text {width:parent.width;text:root.service.review?root.service.review.label:"Preparing review…";wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.valueFont;font.pixelSize:Math.round(26*Config.DirectoryStyle.textScale)}
                Text {width:parent.width;text:root.service.review?root.service.review.dueLabel:"Checking this login…";wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
                Text {width:parent.width;text:root.service.pendingKind==="cancel"?"Cancel this instruction. Nothing will run.":root.impact(root.service.pendingAction);wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
                Text {visible:!!(root.service.review&&root.service.review.replaces);width:parent.width;text:root.service.review?"Replaces · "+root.service.review.replaces:"";wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
                Text {visible:!!(root.service.review&&root.service.review.mode!=="now");width:parent.width;text:root.service.review&&root.service.review.mode==="at"?"Persistent instruction. No wake or logged-out execution. Missed deadlines require review.":"Temporary for this login. Starts on confirmation. Missed deadlines require review.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                Text {visible:!!(root.service.review&&root.service.review.requiresAuth);width:parent.width;text:"System authentication may be required. Permission and inhibitor checks remain in force.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
            }
            PowerQuickScheduleMonitor {id:scheduleView;objectName:"session-schedule-card";visible:root.monitoring;width:parent.width;service:root.service;onEditRequested:root.editSchedule()}
            QuietButton {visible:root.monitoring;width:parent.width;objectName:"session-other-actions";text:"Other actions";onClicked:root.chooseAnother()}
            Column {
                visible:!!root.selectedAction&&!root.monitoring&&!root.reviewing;width:parent.width;spacing:12
                PowerQuickSegments {id:executionMode;width:parent.width;value:root.mode;choices:[{id:"now",label:"Now"},{id:"schedule",label:"Schedule",enabled:root.service.schedulingAvailable}];enabled:!root.working;onChosen:value=>root.setMode(value)}
                Column {
                    visible:root.mode==="schedule";width:parent.width;spacing:12;enabled:!root.working&&!root.service.busy
                    PowerQuickSegments {width:parent.width;value:root.method;choices:[{id:"delay",label:"Countdown"},{id:"at",label:"Date & time"}];onChosen:value=>{root.method=value;root.service.clearFeedback();}}
                    Row {
                        visible:root.method==="delay";width:parent.width;spacing:8
                        PowerQuickCountdownField {id:hoursField;objectName:"session-hours";width:(parent.width-16)/3;label:"HH";maximum:168;onEdited:root.service.clearFeedback()}
                        PowerQuickCountdownField {id:minutesField;objectName:"session-minutes";width:(parent.width-16)/3;label:"MM";text:"30";onEdited:root.service.clearFeedback()}
                        PowerQuickCountdownField {id:secondsField;objectName:"session-seconds";width:(parent.width-16)/3;label:"SS";onEdited:root.service.clearFeedback()}
                    }
                    CalendarUi.CalendarFieldMessage {visible:root.method==="delay"&&!!root.service.fieldErrors.seconds;message:root.service.fieldErrors.seconds||""}
                    Column {
                        visible:root.method==="at";width:parent.width;spacing:8
                        Text {text:"Local date";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                        PowerQuickDateField {id:dateField;objectName:"session-date-editor";fieldObjectName:"session-date";width:parent.width;text:Qt.formatDate(root.suggestedTime,"yyyy-MM-dd");validationMessage:root.service.fieldErrors.date||"";accessibleName:"Scheduled local date"}
                        CalendarUi.CalendarFieldMessage {message:root.service.fieldErrors.date||""}
                        Text {text:"Local time · HH:MM";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                        CalendarUi.CalendarTextField {id:timeField;implicitHeight:Math.max(Config.DirectoryStyle.controlTarget,contentHeight+2*Config.DirectoryStyle.controlVerticalInset);topPadding:Config.DirectoryStyle.controlVerticalInset;bottomPadding:Config.DirectoryStyle.controlVerticalInset;verticalAlignment:TextInput.AlignVCenter;objectName:"session-time";width:parent.width;text:Qt.formatTime(root.suggestedTime,"HH:mm");placeholderText:"HH:MM · local time";maximumLength:5;validationMessage:root.service.fieldErrors.time||"";Accessible.name:"Local time, 24-hour HH:MM";onTextEdited:root.service.clearFeedback()}
                        CalendarUi.CalendarFieldMessage {message:root.service.fieldErrors.time||""}
                        ShellComboBox {id:foldChoice;objectName:"session-clock-fold";visible:!!root.service.fieldErrors.fold||currentIndex>0;width:parent.width;model:["Repeated hour: choose occurrence","First occurrence","Second occurrence"];Accessible.name:"Which repeated clock hour"}
                        CalendarUi.CalendarFieldMessage {message:root.service.fieldErrors.fold||""}
                    }
                    Text {objectName:"session-execution-preview";width:parent.width;text:root.method==="delay"?root.durationPreview():dateField.text+" / "+timeField.text+" LOCAL · "+root.localTimezone;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
                    Text {width:parent.width;text:root.method==="at"?"Persists across login and reboot. No wake or logged-out execution.":"Temporary for this login. Missed deadlines require review.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                }
                Text {visible:root.service.available&&!root.service.schedulingAvailable;width:parent.width;text:root.service.unavailableReason;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
            }
            Text {visible:!!root.service.message&&!root.hasRecord;width:parent.width;text:root.service.message;wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
        }
    }
}
