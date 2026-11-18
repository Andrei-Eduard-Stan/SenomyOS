import QtQuick
import QtQuick.Controls
import ".."
import "../../services/calendar" as CalendarState
import "../../config" as Config

Item {
    id:root
    property var service:null
    property bool week:false
    readonly property var days:week?CalendarState.Navigation.weekDays:[CalendarState.Navigation.selectedDate]
    readonly property bool listMode:height<360||width<(week?730:320)
    signal eventRequested(var entry)
    function minutes(value) {const parts=String(value).split(":");return Number(parts[0])*60+Number(parts[1]);}
    function hourLabel(hour) {return service&&service.preferences.timeFormat==="12" ? String(hour%12||12)+(hour<12?"a":"p") : String(hour).padStart(2,"0")+":00";}
    function key(day) {return CalendarState.Navigation.key(day);}
    function events(day) {const date=key(day);return service?service.entries.filter(e=>e.date<=date&&e.lastDate>=date):[];}
    function segments(day) {
        const date=key(day), sorted=events(day).filter(e=>!e.allDay).map(e=>({event:e,start:e.date===date?e.startMinute:0,end:e.endDate===date?e.endMinute:1440})).sort((a,b)=>a.start-b.start);
        const ends=[];
        for(const segment of sorted){let lane=ends.findIndex(end=>end<=segment.start);if(lane<0)lane=ends.length;ends[lane]=Math.max(segment.end,segment.start+49);segment.lane=lane;}
        for(const segment of sorted)segment.lanes=Math.max(1,ends.length);
        return sorted;
    }
    readonly property bool crowded:days.some(day=>segments(day).some(s=>s.lanes>3||(root.width-40)/days.length/s.lanes-4<44))
    readonly property var allDayEntries:service?service.entries.filter(e=>e.allDay&&e.date<=key(days[days.length-1])&&e.lastDate>=key(days[0])):[]
    Column {
        anchors.fill:parent;spacing:8
        Row {
            width:parent.width;spacing:6
            DashboardButton {width:44;height:44;text:"‹";headerControl:true;accessibleLabel:root.week?"Previous week":"Previous day";onClicked:CalendarState.Navigation.moveDays(root.week?-7:-1)}
            Text {width:Math.max(1,parent.width-100);height:44;verticalAlignment:Text.AlignVCenter;text:(root.week?"WEEK OF ":"")+Qt.formatDate(root.days[0],CalendarState.Navigation.dateFormat==="us"?"MMM d, yyyy":"d MMM yyyy");font.family:Config.DirectoryStyle.headingFont;font.pixelSize:13;color:Config.DirectoryStyle.ink;elide:Text.ElideRight}
            DashboardButton {width:44;height:44;text:"›";headerControl:true;accessibleLabel:root.week?"Next week":"Next day";onClicked:CalendarState.Navigation.moveDays(root.week?7:1)}
        }
        CalendarAgenda {
            visible:root.listMode||root.crowded;width:parent.width;height:parent.height-y
            heading:root.crowded?"OVERLAPPING EVENTS // LIST":root.week?"WEEK // COMPACT AGENDA":"DAY // COMPACT AGENDA"
            entries:root.service?root.service.entries.filter(e=>e.date<=root.key(root.days[root.days.length-1])&&e.lastDate>=root.key(root.days[0])):[]
            onEventRequested:entry=>root.eventRequested(entry)
        }
        CalendarAgenda {
            visible:!root.listMode&&!root.crowded&&root.allDayEntries.length>0
            width:parent.width;height:Math.min(160,root.allDayEntries.length*80+30)
            heading:"ALL DAY";entries:root.allDayEntries
            onEventRequested:entry=>root.eventRequested(entry)
        }
        Item {
            visible:!root.listMode&&!root.crowded;width:parent.width;height:Math.max(0,parent.height-y)
            Row {
                x:40;width:parent.width-40;height:44
                Repeater {model:root.days;delegate:Text {required property var modelData;width:(root.width-40)/root.days.length;height:44;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;text:Qt.formatDate(modelData,"ddd d");font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.ink}}
            }
            FocusScrollArea {
                id:timetable;y:44;width:parent.width;height:parent.height-44;contentHeight:24*54;ScrollBar.vertical:ShellScrollBar {}
                Component.onCompleted:contentY=8*54
                Column {width:40;Repeater {model:24;delegate:Text {required property int index;width:40;height:54;text:root.hourLabel(index);font.family:Config.DirectoryStyle.dataFont;font.pixelSize:10;color:Config.DirectoryStyle.muted}}}
                Repeater {
                    model:root.days
                    delegate:Item {
                        id:day;required property var modelData;required property int index
                        readonly property var segments:root.segments(modelData)
                        x:40+index*(timetable.width-40)/root.days.length;width:(timetable.width-40)/root.days.length;height:24*54
                        Rectangle {width:parent.width;height:parent.height;color:"transparent";border.width:1;border.color:Config.DirectoryStyle.rule}
                        Rectangle {width:parent.width;y:root.minutes(root.service?root.service.preferences.workStart||"09:00":"09:00")*54/60;height:(root.minutes(root.service?root.service.preferences.workEnd||"17:00":"17:00")-root.minutes(root.service?root.service.preferences.workStart||"09:00":"09:00"))*54/60;color:Qt.rgba(1,1,1,0.035)}
                        Repeater {model:24;delegate:Rectangle {required property int index;y:index*54;width:day.width;height:1;color:Config.DirectoryStyle.rule}}
                        Repeater {
                            model:day.segments
                            delegate:DashboardButton {
                                required property var modelData
                                x:modelData.lane*day.width/modelData.lanes+2
                                y:modelData.start*54/60
                                width:Math.max(44,day.width/modelData.lanes-4)
                                height:Math.max(44,(modelData.end-modelData.start)*54/60-2)
                                text:modelData.event.title;detail:modelData.event.time+"–"+modelData.event.endTime;accentColor:modelData.event.color
                                labelSize:10;centered:false;active:true
                                accessibleLabel:modelData.event.title+" "+detail
                                onClicked:root.eventRequested(modelData.event)
                            }
                        }
                    }
                }
            }
        }
    }
}
