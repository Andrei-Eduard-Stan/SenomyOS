import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."
import "../../config" as Config

FocusScrollArea {
    id:root
    required property var service
    focusMargin:48
    property string section:"calendars"
    property bool showHeading:true
    property var preferenceErrors: ({})
    property string preferenceRequest: ""
    property string preferenceMessage: ""
    function savePreferences() {
        preferenceMessage="";
        preferenceRequest=provider.request("preferencesSave",{weekStart:weekStart.currentIndex-1,weekNumbers:weekNumbers.checked,timeFormat:clockFormat.currentIndex?"12":"24",dateFormat:["eu","us","iso"][dateFormat.currentIndex],timezone:displayZone.text,workStart:workStart.text,workEnd:workEnd.text,defaultCalendar:provider.sources[defaultCalendar.currentIndex]?provider.sources[defaultCalendar.currentIndex].id:"",defaultReminder:defaultReminder.text});
    }
    Connections {target:root.service;function onRequestFinished(id,op,result,ok){
        if(id!==root.preferenceRequest||op!=="preferencesSave")return;
        root.preferenceErrors=ok?{}:(result.fieldErrors||{});root.preferenceMessage=ok?"Preferences saved":result.error||root.service.error;
        const fields={weekStart:weekStart,timeFormat:clockFormat,dateFormat:dateFormat,timezone:displayZone,workStart:workStart,workEnd:workEnd,defaultCalendar:defaultCalendar,defaultReminder:defaultReminder};
        const keys=Object.keys(root.preferenceErrors);if(keys.length)Qt.callLater(()=>{const item=fields[keys[0]];if(item){if(typeof item.focusInput==="function")item.focusInput();else item.forceActiveFocus();root.revealFocus();}});
    }}
    readonly property var provider:service || ({sources:[],preferences:{},snapshot:{},reminders:[],available:false,busy:false})
    signal reviewRequested(string operation,var args)
    contentHeight:body.implicitHeight
    ScrollBar.vertical:ShellScrollBar {}
    property string credentialMessage:""
    Process {id:credentialTerminal;stdout:StdioCollector {id:credentialReceipt}
        onExited:(code,status)=>{try{const result=JSON.parse(credentialReceipt.text);root.credentialMessage=result.ok?"Credential terminal opened; credential storage is not yet verified.":result.message;}catch(_){root.credentialMessage="Credential launch result unavailable. Check for the terminal before retrying.";}}}
    function credential(id) {
        if (!/^[a-f0-9]{32}$/.test(id) || credentialTerminal.running) return;
        const source=String(Quickshell.env("SENOMY_SOURCE_ROOT")||Quickshell.shellDir+"/../..");
        credentialMessage="Starting credential terminal…";
        credentialTerminal.exec(["python3","-B",source+"/scripts/senomy_app_launch.py","tool","calendar-credential",id]);
    }
    Column {
        id:body;width:parent.width;spacing:12
        Text {width:parent.width;visible:root.credentialMessage.length>0;text:root.credentialMessage;wrapMode:Text.WordWrap;color:Config.Theme.warning}
        Text {visible:root.showHeading;width:parent.width;text:root.section.toUpperCase();font.family:Config.DirectoryStyle.headingFont;font.pixelSize:16;color:Config.DirectoryStyle.ink}
        Column {
            visible:root.section==="calendars"||root.section==="accounts";width:parent.width;spacing:8
            Repeater {
                model:root.provider.sources.filter(s=>root.section!=="accounts"||s.provider==="caldav")
                delegate:Column {
                    required property var modelData
                    width:body.width;spacing:6
                    ShellCheckBox {text:modelData.name+" // "+modelData.provider;checked:!!modelData.visible;onClicked:root.provider.request("sourceSave",{id:modelData.id,name:modelData.name,color:modelData.color,visible:checked})}
                    CalendarTextField {id:editSourceName;width:parent.width;text:modelData.name;Accessible.name:"Calendar name"}
                    CalendarTextField {id:editSourceColor;width:parent.width;text:modelData.color;Accessible.name:"Calendar colour as hexadecimal"}
                    ShellCheckBox {id:sourceReadOnly;text:"READ ONLY ON THIS DEVICE";checked:!modelData.writable}
                    Flow {width:parent.width;spacing:6
                        DashboardButton {width:Math.min(150,parent.width);text:"SAVE CALENDAR";enabled:root.provider.available&&!root.provider.busy;onClicked:root.provider.request("sourceSave",{id:modelData.id,name:editSourceName.text,color:editSourceColor.text,visible:!!modelData.visible,writable:!sourceReadOnly.checked})}
                        DashboardButton {visible:modelData.id!=="personal";width:Math.min(160,parent.width);text:"REVIEW REMOVE";enabled:root.provider.available&&!root.provider.busy;onClicked:root.reviewRequested("sourceDeletePreview",{source:modelData.id})}
                    }
                    Text {width:parent.width;text:modelData.provider==="local"?"LOCAL // saved on this device":modelData.sync_state+" // "+(modelData.last_sync?Qt.formatDateTime(new Date(modelData.last_sync*1000),"ddd d MMM HH:mm"):"never synced")+" // explicit two-way sync";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted}
                    Flow {
                        visible:modelData.provider==="caldav";width:parent.width;spacing:6
                        DashboardButton {width:Math.min(160,parent.width);text:"CREDENTIAL";onClicked:root.credential(modelData.id)}
                        DashboardButton {width:Math.min(120,parent.width);text:"REVIEW SYNC";enabled:root.provider.available&&!root.provider.busy;onClicked:root.reviewRequested("syncPreview",{source:modelData.id})}
                    }
                    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
                }
            }
            Text {width:parent.width;text:root.section==="accounts"?"ADD CALDAV COLLECTION // HTTPS\nUse the full calendar collection URL. Passwords are entered in a separate terminal and stored in Secret Service. No invitations are sent.":"ADD LOCAL CALENDAR";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted}
            CalendarTextField {id:sourceName;width:parent.width;placeholderText:"Calendar name";Accessible.name:"New calendar name"}
            CalendarTextField {id:sourceColor;visible:root.section!=="accounts";width:parent.width;text:"#a997ef";Accessible.name:"Calendar colour as hexadecimal"}
            CalendarTextField {id:sourceUrl;visible:root.section==="accounts";width:parent.width;placeholderText:"https://server/calendar/";Accessible.name:"CalDAV collection URL"}
            CalendarTextField {id:sourceUser;visible:root.section==="accounts";width:parent.width;placeholderText:"Username (blank for anonymous)";Accessible.name:"CalDAV username"}
            DashboardButton {width:parent.width;text:root.section==="accounts"?"ADD ACCOUNT SOURCE":"CREATE CALENDAR";enabled:root.provider.available&&!root.provider.busy;onClicked:root.provider.request(root.section==="accounts"?"accountAdd":"sourceSave",root.section==="accounts"?{name:sourceName.text,url:sourceUrl.text,username:sourceUser.text}:{name:sourceName.text,color:sourceColor.text,visible:true})}
            Repeater {
                model:root.provider.snapshot.conflicts||[]
                delegate:Column {
                    required property var modelData
                    width:body.width;spacing:6
                    Text {width:parent.width;text:"SYNC CONFLICT // event revision "+modelData.revision;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.Theme.warning}
                    Flow {
                        width:parent.width;spacing:6
                        DashboardButton {width:Math.min(140,parent.width);text:"KEEP LOCAL";onClicked:root.reviewRequested("conflictPreview",{source:modelData.source,uid:modelData.uid,choice:"local"})}
                        DashboardButton {width:Math.min(140,parent.width);text:"USE REMOTE";onClicked:root.reviewRequested("conflictPreview",{source:modelData.source,uid:modelData.uid,choice:"remote"})}
                    }
                }
            }
        }
        CalendarImport {visible:root.section==="transfer";width:parent.width;service:root.provider;onReviewRequested:(op,args)=>root.reviewRequested(op,args)}
        Column {
            visible:root.section==="preferences";width:parent.width;spacing:10
            Text {width:parent.width;text:"DATE AND TIMETABLE PREFERENCES";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted}
            ShellComboBox {id:weekStart;width:parent.width;model:["Week start: locale","Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];currentIndex:Number(root.provider.preferences.weekStart===undefined?-1:root.provider.preferences.weekStart)+1;Accessible.name:"Week start"}
            CalendarFieldMessage {message:root.preferenceErrors.weekStart||""}
            Text {width:parent.width;text:"DATE FORMAT";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
            ShellComboBox {id:dateFormat;objectName:"calendar-date-format";width:parent.width;model:["European · DD/MM/YYYY","American · MM/DD/YYYY","ISO · YYYY-MM-DD"];currentIndex:Math.max(0,["eu","us","iso"].indexOf(root.provider.preferences.dateFormat||"iso"));Accessible.name:"Calendar date format"}
            CalendarFieldMessage {message:root.preferenceErrors.dateFormat||""}
            ShellCheckBox {id:weekNumbers;checked:!!root.provider.preferences.weekNumbers;text:"SHOW WEEK NUMBERS"}
            ShellComboBox {id:clockFormat;width:parent.width;model:["24-hour time","12-hour time"];currentIndex:root.provider.preferences.timeFormat==="12"?1:0;Accessible.name:"Time format"}
            CalendarFieldMessage {message:root.preferenceErrors.timeFormat||""}
            Text {width:parent.width;text:"DISPLAY TIMEZONE // IANA NAME OR local";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
            CalendarTextField {id:displayZone;validationMessage:root.preferenceErrors.timezone||"";width:parent.width;text:root.provider.preferences.timezone||"local";Accessible.name:"Display timezone"}
            CalendarFieldMessage {message:root.preferenceErrors.timezone||""}
            Text {width:parent.width;text:"WORKDAY START / END // HH:MM";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
            CalendarTextField {id:workStart;validationMessage:root.preferenceErrors.workStart||"";width:parent.width;text:root.provider.preferences.workStart||"09:00";Accessible.name:"Workday starts at HH:MM"}
            CalendarFieldMessage {message:root.preferenceErrors.workStart||""}
            CalendarTextField {id:workEnd;validationMessage:root.preferenceErrors.workEnd||"";width:parent.width;text:root.provider.preferences.workEnd||"17:00";Accessible.name:"Workday ends at HH:MM"}
            CalendarFieldMessage {message:root.preferenceErrors.workEnd||""}
            Text {text:"DEFAULT REMINDER";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
            ReminderControl {id:defaultReminder;objectName:"calendar-default-reminder";fieldObjectName:"calendar-default-reminder";width:parent.width;text:root.provider.preferences.defaultReminder===undefined?"10":String(root.provider.preferences.defaultReminder)}
            CalendarFieldMessage {message:root.preferenceErrors.defaultReminder||""}
            Text {width:parent.width;text:"Applies to new events. Each event can override this; existing reminders stay unchanged.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
            Text {width:parent.width;text:"DEFAULT CALENDAR";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
            ShellComboBox {id:defaultCalendar;width:parent.width;model:root.provider.sources;textRole:"name";Accessible.name:"Default calendar";currentIndex:Math.max(0,root.provider.sources.findIndex(s=>s.id===root.provider.preferences.defaultCalendar))}
            CalendarFieldMessage {message:root.preferenceErrors.defaultCalendar||""}
            DashboardButton {width:parent.width;text:"SAVE PREFERENCES";enabled:root.provider.available&&!root.provider.busy;onClicked:root.savePreferences()}
            Text {width:parent.width;visible:root.preferenceMessage.length>0;text:root.preferenceMessage;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Object.keys(root.preferenceErrors).length?Config.Theme.danger:Config.DirectoryStyle.muted}
        }
        Column {
            visible:root.section==="reminders";width:parent.width;spacing:10
            Text {width:parent.width;text:"REMINDERS // persistent during this login\nMissed reminders remain here. Notification dismissal does not delete an event. The service does not wake a sleeping computer.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted}
            Text {visible:!root.provider.reminders.length;width:parent.width;text:"NO PENDING OR MISSED REMINDERS";font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted}
            Repeater {
                model:root.provider.reminders
                delegate:Column {
                    required property var modelData
                    width:body.width;spacing:6
                    Text {width:parent.width;text:modelData.title;textFormat:Text.PlainText;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:13;color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
                    Text {width:parent.width;text:modelData.status+" // "+Qt.formatDateTime(new Date((modelData.snooze||modelData.due)*1000),"ddd d MMM HH:mm");font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
                    Flow {
                        width:parent.width;spacing:6
                        DashboardButton {width:Math.min(120,parent.width);text:"OPEN EVENT";onClicked:root.provider.open({source:modelData.source,uid:modelData.uid,rid:modelData.occurrence})}
                        DashboardButton {width:Math.min(145,parent.width);text:"SNOOZE 10 MIN";onClicked:root.provider.request("reminderAction",{key:modelData.key,action:"snooze",minutes:10})}
                        DashboardButton {width:Math.min(100,parent.width);text:"DISMISS";onClicked:root.provider.request("reminderAction",{key:modelData.key,action:"dismiss"})}
                    }
                    Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
                }
            }
        }
    }
}
