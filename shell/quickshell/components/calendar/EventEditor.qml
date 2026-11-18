import QtQuick
import QtQuick.Controls
import ".."
import "CalendarFormat.js" as Format
import "../../config" as Config

FocusScrollArea {
    id:root
    required property var service
    required property var initial
    property bool externalActions:false
    enabled:!service.busy
    objectName:"event-editor"
    focusMargin:48
    property var fieldErrors: ({})
    property var serverErrors: ({})
    property var rejectedForm: ({})
    property string saveError: ""
    property bool attempted: false
    readonly property bool note:initial.kind==="note"
    property bool moreOptions:false
    property string savedForm:""
    property string previousNoteDate:""
    property bool restoredDraft:!!initial.restored
    readonly property var frequencies:["NONE","DAILY","WEEKLY","MONTHLY","YEARLY"]
    readonly property var reminderValues:["","0","5","10","15","30","60"]
    readonly property var formData:({source:calendarChoice.currentIndex>=0?calendarChoice.model[calendarChoice.currentIndex].id:initial.source,uid:initial.uid||"",revision:initial.revision||0,rid:initial.rid||"",scope:initial.scope||"series",kind:note?"note":"event",title:titleField.text,start:startDate.text+(allDay.checked?"":"T"+startTime.text),end:endDate.text+(allDay.checked?"":"T"+endTime.text),allDay:allDay.checked,timezone:timezoneField.text,fold:foldChoice.currentIndex,endFold:foldChoice.currentIndex,location:locationField.text,notes:notesField.text,url:linkField.text,frequency:frequencies[repeatChoice.currentIndex],interval:intervalField.text,count:countField.text,until:untilField.text,reminder:reminderField.text})
    readonly property bool retainedReminder: initial.revision>0&&formData.reminder===String(initial.reminder===undefined?"":initial.reminder)&&!reminderField.valid
    readonly property bool canSave: true
    readonly property bool dirty:restoredDraft||(savedForm.length>0&&JSON.stringify(formData)!==savedForm)
    property string requestId:""
    signal finished()
    signal cancelRequested()
    function load() {
        const f=initial;calendarChoice.currentIndex=calendarChoice.model.findIndex(s=>s.id===f.source);
        titleField.text=f.title||"";allDay.checked=note||!!f.allDay;
        startDate.text=(f.start||"").slice(0,10);endDate.text=(f.end||f.start||"").slice(0,10);
        startTime.text=(f.start||"").slice(11,16)||"09:00";endTime.text=(f.end||"").slice(11,16)||"10:00";
        timezoneField.text=f.timezone||"local";foldChoice.currentIndex=f.fold||0;
        locationField.text=f.location||"";notesField.text=f.notes||"";linkField.text=f.url||"";
        repeatChoice.currentIndex=Math.max(0,frequencies.indexOf(f.frequency||"NONE"));intervalField.text=String(f.interval||1);countField.text=f.count||"";untilField.text=f.until||"";
        reminderField.text=f.reminder===undefined?"":String(f.reminder);
        moreOptions=note&&startDate.text!==endDate.text;
        savedForm=JSON.stringify(formData);focusTimer.restart();
    }
    function validate() {
        const errors={};
        if(note&&!notesField.text.trim())errors.notes="Write your note before saving.";
        if(!note&&!titleField.text.trim())errors.title="Enter an event title.";
        if(!startDate.valid)errors.start="Enter a real start date as "+Format.hint(startDate.dateFormat)+".";
        if(!endDate.valid)errors.end="Enter a real end date as "+Format.hint(endDate.dateFormat)+".";
        if(!allDay.checked){
            if(!/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(startTime.text))errors.startTime="Use HH:MM, from 00:00 to 23:59.";
            if(!/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(endTime.text))errors.endTime="Use HH:MM, from 00:00 to 23:59.";
        }
        if(!errors.start&&!errors.end&&!errors.startTime&&!errors.endTime&&(allDay.checked?endDate.text<startDate.text:formData.end<=formData.start))errors.end="End must follow start; all-day events may end on the same day.";
        if(!reminderField.valid&&!retainedReminder)errors.reminder="Choose a whole amount from zero to 1 week before start, or No reminder.";
        if(repeatChoice.currentIndex>0){
            if(!/^\d+$/.test(intervalField.text)||Number(intervalField.text)<1||Number(intervalField.text)>365)errors.interval="Repeat every 1–365 periods.";
            if(countField.text&&(!/^\d+$/.test(countField.text)||Number(countField.text)<1||Number(countField.text)>10000))errors.count="Use 1–10000 occurrences, or leave blank.";
            if(countField.text&&untilField.text)errors.until="Choose either a count or an end date, then clear the other.";
            else if(untilField.text&&(!untilField.valid||untilField.text<startDate.text))errors.until="Choose a repeat end date on or after the start.";
        }
        for(const key of Object.keys(serverErrors)){const sourceKey=key==="startTime"?"start":key==="endTime"?"end":key;if(formData[sourceKey]===rejectedForm[sourceKey])errors[key]=serverErrors[key];}
        return errors;
    }
    function errorFor(field) {return String(fieldErrors[field]||"");}
    function focusError() {
        const names=Object.keys(fieldErrors);if(!names.length)return;
        const key=names[0];if(["timezone","fold"].includes(key))moreOptions=true;
        const fields={title:titleField,source:calendarChoice,start:startDate,end:endDate,startTime:startTime,endTime:endTime,notes:notesField,url:linkField,reminder:reminderField,timezone:timezoneField,fold:foldChoice,frequency:repeatChoice,interval:intervalField,count:countField,until:untilField};
        Qt.callLater(()=>{const field=fields[key]||titleField;if(typeof field.focusInput==="function")field.focusInput();else field.forceActiveFocus();Qt.callLater(root.revealFocus);});
    }
    function save() {
        attempted=true;fieldErrors=validate();saveError="";
        if(Object.keys(fieldErrors).length){focusError();return;}
        draftTimer.stop();requestId=service.request("save",formData);
        if(!requestId)saveError=service.error||"Calendar service unavailable. Your draft is retained.";
    }
    Component.onCompleted:load()
    onInitialChanged:if(savedForm.length)load()
    onFormDataChanged:{if(dirty)draftTimer.restart();if(attempted){fieldErrors=validate();saveError="";}}
    Timer {id:focusTimer;interval:1;onTriggered:if(root.note||root.initial.focusNotes)notesField.forceActiveFocus();else titleField.forceActiveFocus();}
    Timer {id:draftTimer;interval:800;onTriggered:root.service.request("draftSave",root.formData)}
    Connections {target:root.service;function onRequestFinished(id,op,result,ok){if(id===root.requestId&&op==="save"){if(ok){root.restoredDraft=false;root.savedForm=JSON.stringify(root.formData);root.finished();}else{root.serverErrors=result.fieldErrors||{};root.rejectedForm=Object.assign({},root.formData);root.fieldErrors=root.validate();root.saveError=result.error||root.service.error||"Save failed. Your draft is retained.";root.focusError();}}}}
    contentHeight:form.implicitHeight
    ScrollBar.vertical:ShellScrollBar {}
    Column {
        id:form;width:Math.max(1,parent.width-10);spacing:10
        Text {width:parent.width;text:(root.initial.revision>0?"EDIT ":"NEW ")+(root.note?"DATED NOTE":"EVENT");font.family:Config.DirectoryStyle.headingFont;font.pixelSize:16;color:Config.DirectoryStyle.ink}
        CalendarFieldMessage {objectName:"event-save-error";message:root.saveError}
        DirectoryButton {objectName:"event-errors-summary";visible:Object.keys(root.fieldErrors).length>0;width:parent.width;text:"CHECK "+Object.keys(root.fieldErrors).length+" FIELD"+(Object.keys(root.fieldErrors).length===1?"":"S");detail:"Select to return to the first field that needs attention. Your draft is retained.";wrapDetail:true;onClicked:root.focusError()}
        Text {visible:!!root.initial.rid&&root.initial.frequency!=="NONE";width:parent.width;text:root.initial.scope==="occurrence"?"Editing this occurrence only":"Editing the entire repeating series";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
        Text {text:root.note?"TITLE (OPTIONAL)":"TITLE";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
        CalendarTextField {id:titleField;validationMessage:root.errorFor("title");objectName:"event-title";width:parent.width;maximumLength:200;placeholderText:root.note?"Leave blank to use the first line of your note":"What’s happening?";Accessible.name:root.note?"Note title, optional":"Event title"}
        CalendarFieldMessage {message:root.errorFor("title")}
        Column {
            visible:root.service.sources.length>1;width:parent.width;spacing:6
            Text {text:"SAVE IN";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
            ShellComboBox {id:calendarChoice;width:parent.width;model:root.service.sources;textRole:"name";enabled:root.initial.revision===0;Accessible.name:"Calendar for this item"}
            CalendarFieldMessage {message:root.errorFor("source")}
        }
        ShellCheckBox {id:allDay;visible:!root.note;text:"ALL DAY";Accessible.name:"All-day event"}
        Flow {
            width:parent.width;spacing:10
            Column {
                width:root.note&&!root.moreOptions?parent.width:parent.width<440?parent.width:(parent.width-10)/2;spacing:6
                Text {text:root.note?"DATE":allDay.checked?"FIRST DAY":"START";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
                CalendarDateField {id:startDate;validationMessage:root.errorFor("start");onTextChanged:{if(root.note&&endDate.text===root.previousNoteDate)endDate.text=text;root.previousNoteDate=text;}fieldObjectName:"event-start";width:parent.width;accessibleName:root.note?"Note date":"Start date"}
                CalendarFieldMessage {message:root.errorFor("start")}
                CalendarTextField {id:startTime;validationMessage:root.errorFor("startTime");objectName:"event-start-time";visible:!allDay.checked;width:parent.width;maximumLength:5;placeholderText:"HH:MM";Accessible.name:"Start time in HH:MM"}
                CalendarFieldMessage {message:root.errorFor("startTime")}
            }
            Column {
                visible:!root.note||root.moreOptions;width:parent.width<440?parent.width:(parent.width-10)/2;spacing:6
                Text {text:root.note||allDay.checked?"LAST DAY":"END";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
                CalendarDateField {id:endDate;validationMessage:root.errorFor("end");fieldObjectName:"event-end";width:parent.width;accessibleName:"End date"}
                CalendarFieldMessage {message:root.errorFor("end")}
                CalendarTextField {id:endTime;validationMessage:root.errorFor("endTime");objectName:"event-end-time";visible:!allDay.checked;width:parent.width;maximumLength:5;placeholderText:"HH:MM";Accessible.name:"End time in HH:MM"}
                CalendarFieldMessage {message:root.errorFor("endTime")}
            }
        }
        Row {
            width:parent.width;spacing:6
            Text {width:parent.width-110;height:44;verticalAlignment:Text.AlignVCenter;text:root.note?"YOUR NOTE":"NOTES";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
            DashboardButton {objectName:"event-clear-notes";width:104;text:"CLEAR";accessibleLabel:"Clear note text in this draft";enabled:notesField.text.length>0;onClicked:{notesField.clear();notesField.forceActiveFocus();}}
        }
        TextArea {
            id:notesField;placeholderTextColor:Config.DirectoryStyle.muted;objectName:"event-notes";width:parent.width;height:root.note?160:110
            placeholderText:root.note?"Write a thought, checklist, reminder or useful links…":"Agenda, checklist, instructions or useful links…"
            textFormat:TextEdit.PlainText;wrapMode:TextEdit.Wrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12
            selectByMouse:true;Accessible.name:root.note?"Dated note text":"Event notes"
            background:Rectangle {color:Config.Theme.glassRaised;border.width:notesField.activeFocus||root.errorFor("notes")?1:0;border.color:root.errorFor("notes")?Config.Theme.danger:Config.DirectoryStyle.ink}
        }
        CalendarFieldMessage {message:root.errorFor("notes")}
        Text {text:"LINK (OPTIONAL)";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
        CalendarTextField {id:linkField;validationMessage:root.errorFor("url");objectName:"event-link";width:parent.width;maximumLength:2048;placeholderText:"Meeting, document or website: https://…";Accessible.name:"Meeting or website link"}
        CalendarFieldMessage {message:root.errorFor("url")}
        Column {
            width:parent.width;spacing:6
            Text {text:"REMIND ME";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
            ReminderControl {id:reminderField;objectName:"event-reminder";fieldObjectName:"event-reminder";width:parent.width}
            CalendarFieldMessage {message:root.errorFor("reminder")}
            Text {visible:root.retainedReminder;width:parent.width;text:"Existing imported reminder will be kept. Choose a preset or valid custom amount to replace it.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
        }

        DashboardButton {objectName:"event-more-options";width:parent.width;text:root.moreOptions?"FEWER OPTIONS":"MORE OPTIONS";onClicked:root.moreOptions=!root.moreOptions}
        Column {
            visible:root.moreOptions;width:parent.width;spacing:10
            Text {visible:!root.note;text:"LOCATION";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
            CalendarTextField {id:locationField;visible:!root.note;width:parent.width;maximumLength:1000;Accessible.name:"Event location"}
            Text {visible:!allDay.checked;text:"TIMEZONE";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
            CalendarTextField {id:timezoneField;validationMessage:root.errorFor("timezone");objectName:"event-timezone";visible:!allDay.checked;width:parent.width;Accessible.name:"Timezone: IANA name, local or floating"}
            CalendarFieldMessage {message:root.errorFor("timezone")}
            ShellComboBox {id:foldChoice;visible:!allDay.checked;width:parent.width;model:["Repeated DST hour: first","Repeated DST hour: second"];Accessible.name:"Which repeated daylight-saving hour"}
            CalendarFieldMessage {message:root.errorFor("fold")}
        }
        Column {
            visible:root.initial.scope!=="occurrence";width:parent.width;spacing:6
            Text {text:"REPEAT";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
            ShellComboBox {id:repeatChoice;objectName:"event-repeat";width:parent.width;model:["Does not repeat","Daily","Weekly","Monthly","Yearly"];Accessible.name:"Repeat frequency"}
            Flow {
                visible:repeatChoice.currentIndex>0;width:parent.width;spacing:6
                Column {width:parent.width<440?parent.width:(parent.width-6)/2;spacing:6
                    Text {text:"EVERY // PERIODS";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
                    CalendarTextField {id:intervalField;validationMessage:root.errorFor("interval");width:parent.width;placeholderText:"1";Accessible.name:"Repeat interval";inputMethodHints:Qt.ImhDigitsOnly}
                    CalendarFieldMessage {message:root.errorFor("interval")}
                }
                Column {width:parent.width<440?parent.width:(parent.width-6)/2;spacing:6
                    Text {text:"OCCURRENCES // OPTIONAL";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
                    CalendarTextField {id:countField;validationMessage:root.errorFor("count");width:parent.width;placeholderText:"No count limit";Accessible.name:"Repeat count, optional";inputMethodHints:Qt.ImhDigitsOnly}
                    CalendarFieldMessage {message:root.errorFor("count")}
                }
                Column {width:parent.width;spacing:6
                    Text {text:"OR END ON // OPTIONAL";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11}
                    CalendarDateField {id:untilField;validationMessage:root.errorFor("until");fieldObjectName:"event-until";width:parent.width;accessibleName:"Repeat end date, optional"}
                    CalendarFieldMessage {message:root.errorFor("until")}
                }
            }
        }
        Row {
            visible:!root.externalActions;width:parent.width;spacing:6
            DashboardButton {objectName:root.externalActions?"embedded-event-save":"event-save";width:(parent.width-6)/2;text:root.note?"SAVE NOTE":"SAVE EVENT";enabled:root.service.available&&!root.service.busy;onClicked:root.save()}
            DashboardButton {objectName:root.externalActions?"embedded-event-cancel":"event-cancel";width:(parent.width-6)/2;text:"CANCEL";enabled:!root.service.busy;onClicked:root.cancelRequested()}
        }
        Text {width:parent.width;text:root.dirty?"Unsaved changes — draft kept on this device":"Ready to edit";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
    }
}
