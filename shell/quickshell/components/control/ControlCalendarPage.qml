import QtQuick
import QtQuick.Controls
import ".."
import "../calendar" as CalendarUi
import "../calendar/CalendarFormat.js" as Format
import "../../services/calendar" as CalendarState
import "../../config" as Config
import "../../services" as Services

FocusScrollArea {
    id:root
    contentWidth:width
    contentHeight:service?workspace.height:height
    property var service:null
    property string part:"overview"
    // Explicit user clicks only; injectable in private QA, never a shell command.
    property var linkOpener: function(url) {return webLaunch.request("open",url,[]);}
    Services.ApplicationLaunch {id:webLaunch;onFinished:(accepted,detail)=>{if(!accepted)root.linkError=detail;}}
    property string linkError:""
    property string feedback:""
    property var rangeErrors: ({})
    function applyRange() {
        const errors={};
        if(!rangeStart.valid)errors.start="Choose a real start date.";
        if(!rangeEnd.valid)errors.end="Choose a real end date (exclusive).";
        if(!errors.start&&!errors.end){
            const a=root.navigation.dateAt(Number(rangeStart.text.slice(0,4)),Number(rangeStart.text.slice(5,7))-1,Number(rangeStart.text.slice(8,10)));
            const b=root.navigation.dateAt(Number(rangeEnd.text.slice(0,4)),Number(rangeEnd.text.slice(5,7))-1,Number(rangeEnd.text.slice(8,10)));
            const days=Math.round((b-a)/86400000);
            if(days<1||days>93)errors.end="End must be 1–93 days after start (exclusive).";
        }
        rangeErrors=errors;
        if(Object.keys(errors).length){if(errors.start)rangeStart.focusInput();else rangeEnd.focusInput();return;}
        service.queryStart=rangeStart.text;service.queryEnd=rangeEnd.text;
    }
    Timer {id:feedbackTimer;interval:6000;onTriggered:root.feedback=""}
    function openLink(url) {
        linkError=linkOpener(url)?"":"Could not open the link. Check your default browser.";
    }
    property var initialDraft: null
    property bool editorOpen:false
    property bool discardReview:false
    property var review:null
    property string reviewRequest:""
    property string detailRequest:""
    property string viewDetailRequest:""
    property string detailScope:"series"
    property var selectedEvent:null
    property bool detailsOpen:false
    readonly property var navigation:CalendarState.Navigation
    readonly property bool compact: legacy.item ? legacy.item.compact : width<336
    readonly property bool dirty: editorOpen && editor.item ? editor.item.dirty : false
    readonly property bool browsing:["month","agenda","briefing","day","week"].includes(mode)
    readonly property string mode:part==="overview"?(width<700?"agenda":"month"):part
    function focusSelected() {if(legacy.item) legacy.item.focusSelected();else if(monthBrowser)monthBrowser.focusSelected();}
    function reset() {editorOpen=false;detailsOpen=false;discardReview=false;review=null;if(service)service.request("draftDiscard",{});}
    function load() { reset(); }
    function localTimeAt(day,minutes) {
        const date=navigation.dateAt(Number(day.slice(0,4)),Number(day.slice(5,7))-1,Number(day.slice(8,10))+Math.floor(minutes/1440));
        const within=minutes%1440;
        return navigation.key(date)+"T"+String(Math.floor(within/60)).padStart(2,"0")+":"+String(within%60).padStart(2,"0");
    }
    function newEvent(selectedDate,kind) {
        feedback="";feedbackTimer.stop();
        const date=selectedDate||navigation.selectedKey;
        kind=kind||"event";
        navigation.selectDateText(date);
        const now=service.snapshot.nowLocal||"";
        const minute=date===now.slice(0,10)?Math.ceil((Number(now.slice(11,13))*60+Number(now.slice(14,16))+15)/15)*15:9*60;
        initialDraft={source:service.preferences.defaultCalendar||"personal",uid:service.newId()+"@senomyos",revision:0,kind:kind,title:"",notes:"",allDay:kind==="note",start:kind==="note"?date:localTimeAt(date,minute),end:kind==="note"?date:localTimeAt(date,minute+60),timezone:service.preferences.timezone||"local",frequency:"NONE",scope:"series",reminder:kind==="note"?"":service.preferences.defaultReminder===undefined?"10":service.preferences.defaultReminder};
        editorOpen=true;detailsOpen=false;
    }
    function eventDetails(entry) {
        linkError="";selectedEvent=entry;detailsOpen=true;editorOpen=false;
        viewDetailRequest=service.request("detail",{source:entry.source,uid:entry.uid,rid:entry.rid||""});
    }
    signal routeRequested(string route)
    property bool editNotesFocus:false
    function consumeCompose() {if(service&&service.requestedCompose&&!dirty){const request=service.requestedCompose;service.requestedCompose=null;newEvent(request.date,request.kind);}}
    function consumeRequested() {
        if(service && service.requestedEvent && !dirty) {
            const entry=service.requestedEvent;service.requestedEvent=null;eventDetails(entry);
        }
    }
    property string briefingConsumerId:""
    function syncBriefing() {
        if(!service)return;
        if(!briefingConsumerId)briefingConsumerId=service.newId();
        service.setBriefingConsumer(briefingConsumerId,visible&&mode==="briefing");
    }
    Component.onDestruction: if(service&&briefingConsumerId)service.setBriefingConsumer(briefingConsumerId,false)
    Component.onCompleted: {consumeRequested();consumeCompose();syncBriefing();}
    onModeChanged: syncBriefing()
    onVisibleChanged: syncBriefing()
    onServiceChanged: syncBriefing()
    onDirtyChanged: if(!dirty){Qt.callLater(consumeRequested);Qt.callLater(consumeCompose);}
    function editEvent(scope,notesFocus) {editNotesFocus=!!notesFocus;detailScope=scope;detailRequest=service.request("detail",{source:selectedEvent.source,uid:selectedEvent.uid,rid:scope==="occurrence"?selectedEvent.rid:""});}
    function preview(operation,args) {feedback="";feedbackTimer.stop();reviewRequest=service.request(operation,args);}
    function cancelEditor() {if(dirty)discardReview=true;else {editorOpen=false;service.request("draftDiscard",{});}}
    Connections {
        target:root.service
        function onRequestedEventChanged() {root.consumeRequested();}
        function onRequestedComposeChanged() {root.consumeCompose();}
        function onRequestFinished(id,op,result,ok) {
            if(!ok)return;
            if(["batchConfirm","importConfirm"].includes(op)){root.feedback=result.imported?result.imported+" item"+(result.imported===1?"":"s")+" added":"No new items — identical rows are already saved";feedbackTimer.restart();}
            if(op==="deleteConfirm"){root.feedback="Item deleted";feedbackTimer.restart();}
            if(id===root.viewDetailRequest) {
                const source=root.service.sources.find(s=>s.id===result.source);
                root.selectedEvent=Object.assign({},root.selectedEvent,result,{calendar:source?source.name:"Calendar",date:result.start.slice(0,10),time:result.start.slice(11),endTime:result.end.slice(11),recurring:result.frequency!=="NONE"});
                if(root.navigation.selectedKey!==result.start.slice(0,10))root.navigation.selectDateText(result.start.slice(0,10));
            }
            if(id===root.detailRequest) {root.initialDraft=Object.assign({},result,{scope:root.detailScope,focusNotes:root.editNotesFocus});root.editorOpen=true;root.detailsOpen=false;}
            if(op==="draftGet" && result.uid) {root.initialDraft=Object.assign({},result,{restored:true});root.editorOpen=true;root.detailsOpen=false;}
            if(id===root.reviewRequest) root.review={operation:op.replace("Preview","Confirm"),token:result.token,impact:result.impact||("Import "+result.count+" event series; "+result.duplicates+" duplicate UIDs skipped. "+result.policy),titles:result.titles||[],items:result.items||[],count:result.count||0};
        }
    }
    Loader {id:legacy;anchors.fill:parent;active:!root.service;sourceComponent:CalendarUi.CalendarBrowser {}}
    Column {
        id:workspace;visible:!!root.service;width:root.width;height:Math.max(root.height,bodyArea.y+160);spacing:8
        Flow {
            visible:!root.editorOpen&&!root.detailsOpen&&(root.browsing||!!(root.service&&root.service.snapshot.hasDraft));width:parent.width;spacing:6
            ControlWorkspaceButton {objectName:"calendar-add-event";visible:root.browsing;width:parent.width<380?(parent.width-6)/2:124;text:"ADD EVENT";enabled:root.service&&root.service.available&&!root.service.busy&&!root.editorOpen;onClicked:root.newEvent()}
            ControlWorkspaceButton {objectName:"calendar-add-note";visible:root.browsing;width:parent.width<380?(parent.width-6)/2:124;text:"ADD NOTE";enabled:root.service&&root.service.available&&!root.service.busy;onClicked:root.newEvent(root.navigation.selectedKey,"note")}
            ControlWorkspaceButton {visible:root.browsing&&parent.width>=380;width:116;text:"TODAY";enabled:!root.editorOpen;onClicked:root.navigation.goToday()}
            ControlWorkspaceButton {visible:!!(root.service&&root.service.snapshot.hasDraft&&!root.editorOpen);width:Math.min(148,parent.width);text:"RESUME DRAFT";onClicked:root.service.request("draftGet",{})}
        }
        Row {
            visible:root.editorOpen;width:parent.width;spacing:6
            ControlWorkspaceButton {objectName:"event-save";width:(parent.width-6)/2;text:root.service&&root.service.busy?"SAVING…":root.initialDraft&&root.initialDraft.kind==="note"?"SAVE NOTE":"SAVE EVENT";enabled:!!(root.service&&root.service.available&&!root.service.busy&&editor.item&&editor.item.canSave);onClicked:editor.item.save()}
            ControlWorkspaceButton {objectName:"event-cancel";width:(parent.width-6)/2;text:"BACK";enabled:!!(root.service&&!root.service.busy);onClicked:root.cancelEditor()}
        }
        ShellTextField {
            objectName:"calendar-event-search";visible:!root.editorOpen&&!root.detailsOpen&&["month","agenda","briefing","day","week"].includes(root.mode)
            width:parent.width;placeholderText:root.mode==="briefing"?"Search upcoming events, notes and links…":"Search events in displayed range…";Accessible.name:root.mode==="briefing"?"Search upcoming events, notes and links":"Search events in displayed range"
            text:root.service?root.service.search:"";onTextEdited:if(root.service)root.service.search=text
        }
        Text {
            visible:root.service&&!!root.service.error&&!(root.editorOpen&&root.service.errorOperation==="save")&&!(root.mode==="preferences"&&root.service.errorOperation==="preferencesSave");width:parent.width;text:root.service?root.service.error:"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;maximumLineCount:5;elide:Text.ElideRight;color:Config.Theme.danger;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12
        }
        Text {visible:root.feedback.length>0;width:parent.width;text:root.feedback;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.ink}
        Text {visible:!!(root.service&&root.service.snapshot.healthError);width:parent.width;text:root.service?root.service.snapshot.healthError||"":"";wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
        ShellComboBox {
            visible:!root.editorOpen&&!root.detailsOpen&&["month","agenda","briefing","day","week"].includes(root.mode)
            width:parent.width;model:[{id:"",name:"All visible calendars"}].concat(root.service?root.service.sources:[]);textRole:"name";Accessible.name:"Filter events by calendar"
            onActivated:if(root.service)root.service.sourceFilter=model[currentIndex].id
        }
        Flow {
            visible:!root.editorOpen&&!root.detailsOpen&&root.mode==="agenda";width:parent.width;spacing:6
            Column {width:parent.width<440?parent.width:(parent.width-6)/2;spacing:6
                Text {text:"FROM // INCLUSIVE";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
                CalendarUi.CalendarDateField {id:rangeStart;fieldObjectName:"calendar-range-start";width:parent.width;text:root.service?root.service.queryStart:"";accessibleName:"Agenda range starts";validationMessage:root.rangeErrors.start||""}
                CalendarUi.CalendarFieldMessage {message:root.rangeErrors.start||""}
            }
            Column {width:parent.width<440?parent.width:(parent.width-6)/2;spacing:6
                Text {text:"UNTIL // EXCLUSIVE";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
                CalendarUi.CalendarDateField {id:rangeEnd;fieldObjectName:"calendar-range-end";width:parent.width;text:root.service?root.service.queryEnd:"";accessibleName:"Agenda range ends, exclusive";validationMessage:root.rangeErrors.end||""}
                CalendarUi.CalendarFieldMessage {message:root.rangeErrors.end||""}
            }
            ControlWorkspaceButton {width:Math.min(144,parent.width);text:"APPLY RANGE";enabled:root.service&&root.service.available;onClicked:root.applyRange()}
            ControlWorkspaceButton {width:Math.min(150,parent.width);text:"MONTH RANGE";onClicked:{root.rangeErrors={};rangeStart.text=Qt.binding(()=>root.service.queryStart);rangeEnd.text=Qt.binding(()=>root.service.queryEnd);root.service.queryStart=Qt.binding(()=>root.navigation.key(root.navigation.monthDays[0]));root.service.queryEnd=Qt.binding(()=>root.navigation.key(root.navigation.dateAt(root.navigation.monthDays[0].getFullYear(),root.navigation.monthDays[0].getMonth(),root.navigation.monthDays[0].getDate()+42)));}}
        }
        Flow {
            visible:!root.editorOpen&&!root.detailsOpen&&root.mode==="briefing";width:parent.width;spacing:6
            ShellComboBox {objectName:"calendar-briefing-range";width:Math.min(210,parent.width);model:["Next 7 days","Next 30 days","Next 90 days"];currentIndex:root.service?[7,30,90].indexOf(root.service.briefingDays):1;Accessible.name:"Event briefing range";onActivated:root.service.briefingDays=[7,30,90][currentIndex]}
            Text {width:parent.width;text:"DATES WITH EVENTS // "+(root.service?Qt.formatDate(root.navigation.today,"d MMM yyyy")+" — "+Qt.formatDate(root.navigation.dateAt(root.navigation.today.getFullYear(),root.navigation.today.getMonth(),root.navigation.today.getDate()+root.service.briefingDays-1),"d MMM yyyy"):"");wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
        }
        Text {visible:root.service&&(root.mode==="briefing"?root.service.briefingTruncated:root.service.truncated);width:parent.width;text:"RESULT LIMIT // refine the range or search";wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
        Column {
            visible:root.discardReview;width:parent.width;spacing:6
            Text {width:parent.width;text:"Discard unsaved event changes? The saved event remains unchanged.";wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12}
            Row {width:parent.width;spacing:6
                ControlWorkspaceButton {width:(parent.width-6)/2;text:"KEEP EDITING";onClicked:root.discardReview=false}
                ControlWorkspaceButton {width:(parent.width-6)/2;text:"DISCARD DRAFT";onClicked:root.reset()}
            }
        }
        Column {
            visible:!!root.review;width:parent.width;spacing:6
            Text {width:parent.width;text:root.review?root.review.impact:"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.Theme.warning;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12}
            Text {visible:root.review&&root.review.titles.length&&!root.review.items.length;width:parent.width;text:root.review?root.review.titles.join(" · "):"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;maximumLineCount:3;elide:Text.ElideRight}
            Text {visible:!!(root.review&&root.review.items.length);width:parent.width;text:root.review?root.review.items.map(e=>e.start.slice(0,10)+(e.start.length>10?" · "+e.start.slice(11,16):"")+" // "+e.kind.toUpperCase()+" // "+e.title).join("\n")+(root.review.count>root.review.items.length?"\nShowing first "+root.review.items.length+" of "+root.review.count+" items.":""):"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;maximumLineCount:8;elide:Text.ElideRight;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}

            Row {width:parent.width;spacing:6
                ControlWorkspaceButton {objectName:"calendar-confirm-action";width:(parent.width-6)/2;text:"CONFIRM";enabled:root.service&&!root.service.busy;onClicked:{const r=root.review;root.review=null;root.service.request(r.operation,{token:r.token});root.detailsOpen=false;}}
                ControlWorkspaceButton {width:(parent.width-6)/2;text:"CANCEL";onClicked:root.review=null}
            }
        }
        Item {
            id:bodyArea
            width:parent.width;height:Math.max(160,parent.height-y)
            Loader {
                id:editor;anchors.fill:parent;active:root.editorOpen
                sourceComponent:CalendarUi.EventEditor {
                    service:root.service;initial:root.initialDraft;externalActions:true
                    onFinished:{root.navigation.selectDateText(editor.item.formData.start.slice(0,10));root.feedback=root.initialDraft.kind==="note"?"Note saved":"Event saved";feedbackTimer.restart();root.editorOpen=false;root.detailsOpen=false;root.service.refresh()}
                    onCancelRequested:root.cancelEditor()
                }
            }
            FocusScrollArea {
                id:details;visible:root.detailsOpen&&!root.editorOpen;anchors.fill:parent;contentHeight:detailsBody.implicitHeight
                Column {id:detailsBody;width:parent.width;spacing:12
                    Text {width:parent.width;text:root.selectedEvent?root.selectedEvent.title:"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:18;color:Config.DirectoryStyle.ink}
                    Text {width:parent.width;text:root.selectedEvent?root.selectedEvent.calendar+" // "+Format.display(root.selectedEvent.date,root.navigation.dateFormat)+" // "+(root.selectedEvent.allDay?"ALL DAY":root.selectedEvent.time+"–"+root.selectedEvent.endTime)+"\n"+(root.selectedEvent.location||""):"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted}
                    Text {width:parent.width;text:root.selectedEvent?root.selectedEvent.notes||"":"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.ink}
                    Column {
                        width:parent.width;spacing:6
                        Repeater {
                            model:root.selectedEvent?root.selectedEvent.links||[]:[]
                            delegate:ControlWorkspaceButton {
                                required property string modelData
                                required property int index
                                objectName:"calendar-event-link-"+index
                                width:parent.width;text:index===0&&root.selectedEvent.url===modelData?"OPEN EVENT LINK":"OPEN NOTES LINK";detail:modelData;wrapDetail:true;detailWrapMode:Text.WrapAtWordBoundaryOrAnywhere
                                Accessible.name:"Open event web link "+modelData
                                onClicked:root.openLink(modelData)
                            }
                        }
                    }
                    Text {visible:root.linkError.length>0;width:parent.width;text:root.linkError;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.Theme.warning}
                    Text {width:parent.width;text:root.selectedEvent?"REMINDER // "+(root.selectedEvent.reminder!==undefined&&root.selectedEvent.reminder!==""?root.selectedEvent.reminder+" minutes before start":"OFF"):"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
                    Text {width:parent.width;text:root.selectedEvent?"TIMEZONE // "+(root.selectedEvent.timezone||""):"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
                    Flow {width:parent.width;spacing:6
                        ControlWorkspaceButton {objectName:"calendar-edit-series";width:Math.min(148,parent.width);text:root.selectedEvent&&root.selectedEvent.recurring?"EDIT SERIES":root.selectedEvent&&root.selectedEvent.kind==="note"?"EDIT NOTE":"EDIT EVENT";enabled:root.selectedEvent&&root.selectedEvent.writable;onClicked:root.editEvent("series")}
                        ControlWorkspaceButton {objectName:"calendar-edit-notes";visible:root.selectedEvent&&root.selectedEvent.kind!=="note";width:Math.min(160,parent.width);text:root.selectedEvent&&root.selectedEvent.notes?"EDIT NOTES":"ADD NOTES";enabled:root.selectedEvent&&root.selectedEvent.writable;onClicked:root.editEvent(root.selectedEvent.recurring?"occurrence":"series",true)}
                        ControlWorkspaceButton {visible:root.selectedEvent&&root.selectedEvent.recurring;width:Math.min(170,parent.width);text:"EDIT OCCURRENCE";enabled:root.selectedEvent&&root.selectedEvent.writable;onClicked:root.editEvent("occurrence")}
                        ControlWorkspaceButton {width:Math.min(148,parent.width);objectName:"calendar-delete-item";text:root.selectedEvent&&root.selectedEvent.kind==="note"?"DELETE NOTE":"DELETE EVENT";enabled:root.selectedEvent&&root.selectedEvent.writable;onClicked:root.preview("deletePreview",{source:root.selectedEvent.source,uid:root.selectedEvent.uid,scope:"series"})}
                        ControlWorkspaceButton {visible:root.selectedEvent&&root.selectedEvent.recurring;width:Math.min(190,parent.width);text:"DELETE OCCURRENCE";enabled:root.selectedEvent&&root.selectedEvent.writable;onClicked:root.preview("deletePreview",{source:root.selectedEvent.source,uid:root.selectedEvent.uid,rid:root.selectedEvent.rid,scope:"occurrence"})}
                        ControlWorkspaceButton {width:Math.min(100,parent.width);text:"BACK";onClicked:root.detailsOpen=false}
                    }
                }
            }
            Item {
                visible:!root.editorOpen&&!root.detailsOpen&&root.mode==="month";anchors.fill:parent
                CalendarUi.CalendarBrowser {id:monthBrowser;x:0;width:parent.width>=730?parent.width*0.54:parent.width;height:parent.height;service:root.service;showAgenda:parent.width<730;onAddEventRequested:date=>root.newEvent(date,"event");onAddNoteRequested:date=>root.newEvent(date,"note");onViewDayRequested:date=>root.routeRequested("calendar/day");onImportRequested:root.routeRequested("calendar/transfer");onEventRequested:entry=>root.eventDetails(entry)}
                CalendarUi.CalendarAgenda {visible:parent.width>=730;x:parent.width*0.56;width:parent.width-x;height:parent.height;entries:root.service?root.service.entries:[];dateFilter:root.navigation.selectedKey;heading:"SELECTED DAY";onEventRequested:entry=>root.eventDetails(entry)}
            }
            CalendarUi.CalendarAgenda {visible:!root.editorOpen&&!root.detailsOpen&&root.mode==="agenda";anchors.fill:parent;entries:root.service?root.service.entries:[];rangeStart:root.service?root.service.queryStart:"";rangeEnd:root.service?root.service.queryEnd:"";heading:"AGENDA // DISPLAYED RANGE";onEventRequested:entry=>root.eventDetails(entry)}
            CalendarUi.CalendarAgenda {objectName:"calendar-event-briefing";visible:!root.editorOpen&&!root.detailsOpen&&root.mode==="briefing";anchors.fill:parent;entries:root.service?root.service.briefingEntries:[];rangeStart:root.service?root.service.briefingStart:"";rangeEnd:root.service?root.service.briefingEnd:"";heading:"EVENT BRIEFING";showHeading:false;onEventRequested:entry=>root.eventDetails(entry)}
            CalendarUi.CalendarTimetable {visible:!root.editorOpen&&!root.detailsOpen&&["week","day"].includes(root.mode);anchors.fill:parent;service:root.service;week:root.mode==="week";onEventRequested:entry=>root.eventDetails(entry)}
            CalendarUi.CalendarTools {visible:!root.editorOpen&&!root.detailsOpen&&["calendars","accounts","preferences","reminders","transfer"].includes(root.mode);anchors.fill:parent;service:root.service;section:root.mode;showHeading:false;onReviewRequested:(op,args)=>root.preview(op,args)}
        }
    }
}
