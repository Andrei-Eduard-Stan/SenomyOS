import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "components/control" as Control
import "components/calendar" as CalendarUi
import "services/calendar" as CalendarState
import "config" as Config

Window {
 id:test;visible:true;width:794;height:640;color:"transparent"
 // Use the service's current civil day: fixed October fixtures eventually fall
 // outside the upcoming briefing range even when the product is correct.
 readonly property string eventDay:CalendarState.Navigation.todayKey
 readonly property string eventEu:Qt.formatDate(CalendarState.Navigation.today,"dd/MM/yyyy")
 readonly property string eventUs:Qt.formatDate(CalendarState.Navigation.today,"MM/dd/yyyy")
 property string route:"month"
 property string waiting:""
 property string createdUid:""
 property int successes:0
 property int failedRequests:0
 property string openedLink:""
 TestCase {id:input;when:false}
 CalendarState.CalendarService {id:calendar;active:true;onRequestFinished:(id,op,result,ok)=>{if(!ok)test.failedRequests++;if(op==="save"&&ok){test.createdUid=result.uid;test.successes++;}}}
 Control.ControlCalendarPage {id:page;anchors.fill:parent;service:calendar;part:test.route;onRouteRequested:route=>test.route=route.split("/")[1];linkOpener:function(url){test.openedLink=url;return true;}
  Rectangle {anchors.fill:parent;color:"#0a0c0d";z:-1}
 }
 CalendarUi.EventEditor {
  id:importedEditor;visible:false;width:320;height:640;service:calendar
  initial:({source:"personal",title:"Imported event",start:"2026-10-15T09:00",end:"2026-10-15T10:00",timezone:"UTC",revision:1,reminder:"-10"})
 }
 CalendarUi.CalendarAgenda {
  id:grouping;visible:false;rangeStart:"2026-10-11";rangeEnd:"2026-10-15"
  entries:[{title:"Continuing",date:"2026-10-10",lastDate:"2026-10-12",allDay:true,startEpoch:0},{title:"Later",date:"2026-10-14",lastDate:"2026-10-14",allDay:false,startEpoch:2},{title:"Early",date:"2026-10-14",lastDate:"2026-10-14",allDay:false,startEpoch:1}]
 }
 function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message)}}
 function waitFor(predicate,message){console.log("CHECK: "+message);for(let i=0;i<150&&!predicate();i++)input.wait(20);check(predicate(),message)}
 function type(item,text){item.forceActiveFocus();item.selectAll();for(const c of text){if(c==="\n")input.keyClick(Qt.Key_Return);else input.keyClick(c)}}
 function captureWindow(name){console.log("CAPTURE: "+name);let done=false;test.contentItem.grabToImage(r=>{check(r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"window capture");done=true});for(let i=0;i<200&&!done;i++)input.wait(10);check(done,"capture completed: "+name)}
 function capture(name){console.log("CAPTURE: "+name);let done=false;page.grabToImage(r=>{check(r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture");done=true});for(let i=0;i<200&&!done;i++)input.wait(10);check(done,"capture completed: "+name)}
 Timer {interval:600;running:true;onTriggered:{
  test.waitFor(()=>calendar.available&&calendar.sources.length>0,"backend connected");
  test.check(importedEditor.retainedReminder&&!importedEditor.validate().reminder,"unchanged imported alarm timing does not prevent unrelated edits");
  test.check(grouping.groups.map(g=>g.date).join(",")==="2026-10-11,2026-10-12,2026-10-14","grouping includes continuing/multi-day dates and omits empty dates and exclusive end");
  test.check(grouping.groups[2].events[0].title==="Early","date group orders timed events");
  grouping.dateFilter="2026-10-12";test.check(grouping.groups.length===1&&grouping.groups[0].events.length===1,"selected-day agenda remains correct");
  input.mouseClick(input.findChild(page,"calendar-add-event"));input.wait(80);
  test.check(page.editorOpen&&!page.dirty,"clean new event draft");
  test.check(page.localTimeAt("2026-10-11",1440)==="2026-10-12T00:00","new-event time rolls to next date at midnight");
  calendar.request("preferencesSave",{dateFormat:"eu"});test.waitFor(()=>calendar.preferences.dateFormat==="eu"&&page.navigation.dateFormat==="eu","European format persisted and applied");
  const startInput=input.findChild(page,"event-start");test.check(startInput.text.includes("/"),"editor date uses European presentation");
  test.type(startInput,"31/02/2026");test.type(input.findChild(page,"event-start-time"),"29:15");
  input.mouseClick(input.findChild(page,"event-save"));input.wait(40);
  const editor=input.findChild(page,"event-editor");test.check(editor.fieldErrors.title&&editor.fieldErrors.start&&editor.fieldErrors.startTime,"all invalid fields have specific inline errors");test.check(test.successes===0&&test.failedRequests===0,"local validation sends no invalid save");
  test.capture("editor-errors-794");test.width=320;input.wait(40);test.capture("editor-errors-320");test.width=794;
  test.type(startInput,test.eventEu);test.type(input.findChild(page,"event-end"),test.eventEu);test.type(input.findChild(page,"event-start-time"),"09:00");test.type(input.findChild(page,"event-end-time"),"10:00");
  test.check(editor.formData.start===test.eventDay+"T09:00","European entry remains canonical on wire");
  calendar.request("preferencesSave",{dateFormat:"us"});test.waitFor(()=>page.navigation.dateFormat==="us","American format applied");test.check(startInput.text===test.eventUs&&editor.formData.start===test.eventDay+"T09:00","date preference changes presentation without changing the date");
  calendar.request("preferencesSave",{dateFormat:"iso"});test.waitFor(()=>page.navigation.dateFormat==="iso","ISO restored");
  test.type(input.findChild(page,"event-title"),"Design review");
  test.check(input.findChild(page,"event-reminder").text==="10","new events use configurable reminder default");
  const reminder=input.findChild(page,"event-reminder");reminder.text="1 week before";test.check(reminder.text==="10080","older textual reminder draft recovers to minutes");
  const preset=input.findChild(page,"event-reminder-preset");preset.currentIndex=9;preset.activated(9);input.wait(30);
  const amount=input.findChild(page,"event-reminder-amount"),unit=input.findChild(page,"event-reminder-unit");test.type(amount,"2");unit.currentIndex=2;unit.activated(2);test.check(reminder.text==="2880"&&reminder.custom,"custom two-day reminder stays editable");
  test.type(amount,"8");unit.currentIndex=3;unit.activated(3);input.mouseClick(input.findChild(page,"event-save"));test.check(!!editor.fieldErrors.reminder,"out of range reminder identified");
  test.type(amount,"2");unit.currentIndex=2;unit.activated(2);test.check(!editor.fieldErrors.reminder,"corrected custom reminder clears field error");
  editor.moreOptions=true;test.type(input.findChild(page,"event-timezone"),"Invalid/Timezone");input.findChild(page,"event-save").forceActiveFocus();input.mouseClick(input.findChild(page,"event-save"));test.waitFor(()=>test.failedRequests===1,"server timezone error returned");test.check(editor.fieldErrors.timezone&&page.editorOpen&&test.successes===0,"server validation targets timezone and preserves draft");test.capture("editor-timezone-error");
  test.type(input.findChild(page,"event-title"),"Design review");test.check(!!editor.fieldErrors.timezone,"editing another field retains timezone error");
  test.type(input.findChild(page,"event-timezone"),"UTC");test.check(!editor.fieldErrors.timezone,"corrected timezone clears server error");
  test.type(input.findChild(page,"event-link"),"https://meet.example.org/review");
  test.type(input.findChild(page,"event-notes"),"Discuss prototypes. Document https://example.org/notes");
  test.check(page.dirty,"editing marks draft dirty");
  test.capture("editor-794");
  test.width=320;input.wait(50);test.capture("editor-320");
  const save=input.findChild(page,"event-save");save.forceActiveFocus();input.wait(30);input.mouseClick(save);
  test.waitFor(()=>test.successes===1&&!page.editorOpen,"save succeeded");
  test.waitFor(()=>calendar.entries.length===1,"agenda refreshed");
  test.check(calendar.entries[0].title==="Design review","real stored event appears");
  test.width=794;test.route="month";input.wait(80);test.capture("month-794");
  for(const route of ["briefing","agenda","week","day","calendars","reminders","transfer","accounts","preferences"]){test.route=route;input.wait(80);if(route==="briefing")test.waitFor(()=>calendar.briefingEntries.length===1,"briefing populated before capture");test.capture(route+"-794");test.width=320;input.wait(50);test.capture(route+"-320");test.width=794;}
  Config.DirectoryStyle.touchMode=true;test.width=390;test.route="month";input.wait(60);test.capture("month-touch-390");Config.DirectoryStyle.touchMode=false;test.width=794;
  test.route="agenda";input.wait(50);test.check(!!input.findChild(page,"calendar-range-start"),"regional agenda range fields are available");
  test.type(input.findChild(page,"calendar-range-start"),"2026-02-31");test.check(page.applyRange()===undefined&&!!page.rangeErrors.start,"invalid agenda range targets the start field");
  test.route="month";input.wait(50);
  test.route="briefing";test.waitFor(()=>calendar.briefingEntries.length===1,"independent upcoming query returns saved event");
  const briefing=input.findChild(page,"calendar-event-briefing");test.check(briefing.groups.length===1&&briefing.groups[0].events.length===1,"briefing shows occupied dates only");
  const oldRange=calendar.queryStart;calendar.briefingDays=7;input.wait(180);test.check(calendar.queryStart===oldRange,"briefing range does not replace month/agenda range");
  test.route="agenda";input.wait(80);page.eventDetails(calendar.entries[0]);test.waitFor(()=>page.selectedEvent.links&&page.selectedEvent.links.length===2,"notes and event links loaded");test.capture("details-794");test.width=320;input.wait(40);test.capture("details-320");test.width=794;input.wait(40);
  const link=input.findChild(page,"calendar-event-link-0");test.check(!!link,"event link action shown");link.forceActiveFocus();input.keyClick(Qt.Key_Return);test.check(test.openedLink==="https://meet.example.org/review","link opens only through explicit click and injected opener");
  input.mouseClick(input.findChild(page,"calendar-edit-series"));test.waitFor(()=>page.editorOpen,"edit opens stored event");
  test.type(input.findChild(page,"event-title"),"Updated design review");
  input.findChild(page,"event-cancel").forceActiveFocus();input.wait(30);input.mouseClick(input.findChild(page,"event-cancel"));test.check(page.discardReview&&page.dirty,"Back reviews unsaved draft");
  page.discardReview=false;input.findChild(page,"event-save").forceActiveFocus();input.wait(30);input.mouseClick(input.findChild(page,"event-save"));test.waitFor(()=>test.successes===2,"edit saved");
  test.waitFor(()=>calendar.entries[0].title==="Updated design review","edit visible");page.eventDetails(calendar.entries[0]);input.wait(30);
  input.mouseClick(input.findChild(page,"calendar-edit-series"));test.waitFor(()=>page.editorOpen,"second edit opens");test.type(input.findChild(page,"event-title"),"Unfinished draft");input.wait(1000);
  page.editorOpen=false;calendar.request("draftGet",{});test.waitFor(()=>page.editorOpen,"draft restored from backend");test.check(input.findChild(page,"event-title").text==="Unfinished draft","draft contents preserved");page.reset();input.wait(40);
  page.eventDetails(calendar.entries[0]);input.wait(40);input.mouseClick(input.findChild(page,"calendar-edit-series"));test.waitFor(()=>page.editorOpen,"edit restored saved event");page.reset();input.wait(20);
  page.eventDetails(calendar.entries[0]);input.wait(40);page.preview("deletePreview",{source:"personal",uid:test.createdUid});test.waitFor(()=>!!page.review,"delete review provided");test.check(calendar.entries.length===1,"review did not delete");
  input.mouseClick(input.findChild(page,"calendar-confirm-action"));test.waitFor(()=>calendar.entries.length===0,"confirmed delete refreshes empty state");
  test.route="month";input.wait(150);
  const selectedIndex=page.navigation.monthDays.findIndex(d=>page.navigation.key(d)===page.navigation.selectedKey);
  const day=input.findChild(page,"calendar-day-"+selectedIndex);test.check(!!day,"date has visible action target");input.mouseClick(day);input.wait(60);
  const mini=input.findChild(page,"calendar-date-actions");test.check(mini.opened,"date click opens mini menu");test.captureWindow("date-actions-794");
  input.mouseClick(input.findChild(mini.contentItem,"date-add-note"));test.waitFor(()=>page.editorOpen,"date note action opens editor");
  test.check(page.initialDraft.kind==="note"&&page.initialDraft.start===page.navigation.selectedKey,"note uses chosen date");
  test.type(input.findChild(page,"event-notes"),"Remember the access link https://example.org/access");test.capture("note-editor-794");test.width=320;input.wait(50);test.capture("note-editor-320");
  const dateTrigger=input.findChild(page,"event-start-picker");dateTrigger.forceActiveFocus();input.wait(60);input.mouseClick(dateTrigger);input.wait(60);
  const datePicker=input.findChild(page,"event-start-picker-popup");test.check(datePicker.opened&&datePicker.compact,"narrow date picker opens compact week");test.captureWindow("date-picker-320");datePicker.close();test.width=794;
  input.findChild(page,"event-save").forceActiveFocus();input.mouseClick(input.findChild(page,"event-save"));test.waitFor(()=>test.successes===3&&!page.editorOpen,"dated note saved");test.waitFor(()=>calendar.entries.length===1,"note appears in calendar");test.check(calendar.entries[0].kind==="note","note is a first-class dated item");
  page.eventDetails(calendar.entries[0]);test.waitFor(()=>page.selectedEvent.notes!==undefined,"note detail loaded");test.capture("note-details-794");
  input.mouseClick(input.findChild(page,"calendar-edit-series"));test.waitFor(()=>page.editorOpen,"edit note action");
  input.mouseClick(input.findChild(page,"event-clear-notes"));test.check(input.findChild(page,"event-notes").text==="","clear notes changes only this draft");
  input.findChild(page,"event-save").forceActiveFocus();input.wait(50);input.mouseClick(input.findChild(page,"event-save"));input.wait(30);test.check(input.findChild(page,"event-editor").fieldErrors.notes&&test.successes===3,"empty-note save identifies the notes field and retains saved note");
  test.type(input.findChild(page,"event-notes"),"Updated note");input.mouseClick(input.findChild(page,"event-save"));test.waitFor(()=>test.successes===4&&!page.editorOpen,"edited note saved");
  test.route="transfer";input.wait(100);const batch=input.findChild(page,"calendar-batch-text");test.check(!!batch,"bulk paste available");
  const date=page.navigation.selectedKey;test.type(batch,"date,title,start,end,notes,kind\n"+date+",Imported meeting,09:00,10:00,Agenda,event\n"+date+",Imported note,,,Remember tickets,note");
  const bulk=input.findChild(page,"calendar-batch-preview");bulk.forceActiveFocus();input.wait(80);input.mouseClick(bulk);test.waitFor(()=>!!page.review,"bulk import requires review");test.check(calendar.snapshot.eventCount===1,"preview does not create items");test.capture("bulk-review-794");
  input.mouseClick(input.findChild(page,"calendar-confirm-action"));test.waitFor(()=>calendar.snapshot.eventCount===3,"confirmed bulk list creates two items");
  bulk.forceActiveFocus();input.wait(80);input.mouseClick(bulk);test.waitFor(()=>!!page.review,"repeat list review");test.check(page.review.impact.startsWith("Add 0 items"),"repeat list skips duplicates");page.review=null;
  test.capture("bulk-import-794");test.width=320;input.wait(60);test.capture("bulk-import-320");test.width=794;
  test.check(test.failedRequests===1,"only intentional invalid timezone reaches backend");
  console.log("PASS: production editor/agenda, private persisted events, update/draft recovery/delete review, Calendar routes at wide/narrow widths; no live data");Qt.quit();
 }}
}
