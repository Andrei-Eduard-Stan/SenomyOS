import QtQuick
import QtQuick.Controls
import ".."
import "CalendarFormat.js" as Format
import "../../config" as Config
import "../../services/calendar" as CalendarState

FocusScrollArea {
    id:root
    property var entries: []
    property string dateFilter: ""
    property string rangeStart: ""
    property string rangeEnd: ""
    property string heading: "AGENDA"
    property bool showHeading:true
    property bool embedded:false
    interactive:!embedded
    readonly property var shown: dateFilter ? entries.filter(e => e.date<=dateFilter && e.lastDate>=dateFilter) : entries
    // A spanning event appears on each occupied date, clipped to this view's
    // range. This includes continuing events and excludes empty dates/DTEND.
    readonly property var grouping: {
        const grouped={};
        for(const entry of shown) {
            const first=dateFilter||((rangeStart&&entry.date<rangeStart)?rangeStart:entry.date);
            const last=dateFilter||((rangeEnd&&entry.lastDate>=rangeEnd)?CalendarState.Navigation.key(CalendarState.Navigation.dateAt(Number(rangeEnd.slice(0,4)),Number(rangeEnd.slice(5,7))-1,Number(rangeEnd.slice(8,10))-1)):entry.lastDate);
            let day=first;
            for(let count=0;day<=last&&count<93;count++) {
                if(!grouped[day])grouped[day]=[];
                grouped[day].push(entry);
                const next=CalendarState.Navigation.dateAt(Number(day.slice(0,4)),Number(day.slice(5,7))-1,Number(day.slice(8,10))+1);
                day=CalendarState.Navigation.key(next);
            }
        }
        let count=0,limited=false;
        const result=[];
        for(const date of Object.keys(grouped).sort()) {
            const all=grouped[date].sort((a,b)=>Number(b.allDay)-Number(a.allDay)||a.startEpoch-b.startEpoch||a.title.localeCompare(b.title));
            const events=all.slice(0,Math.max(0,1000-count));
            if(events.length<all.length)limited=true;
            count+=events.length;if(events.length)result.push({date:date,events:events});
        }
        return {groups:result,limited:limited};
    }
    readonly property var groups: grouping.groups
    signal eventRequested(var entry)
    contentHeight:body.implicitHeight
    ScrollBar.vertical:ShellScrollBar {policy:root.embedded?ScrollBar.AlwaysOff:ScrollBar.AsNeeded}
    function dateHeading(key) {
        const date=CalendarState.Navigation.dateAt(Number(key.slice(0,4)),Number(key.slice(5,7))-1,Number(key.slice(8,10)));
        return (key===CalendarState.Navigation.todayKey?"TODAY // ":"")+Qt.formatDate(date,CalendarState.Navigation.dateFormat==="us"?"dddd, MMMM d, yyyy":"dddd, d MMMM yyyy").toUpperCase();
    }
    Column {
        id:body;width:Math.max(0,parent.width-10);spacing:12
        Text {visible:root.showHeading;width:parent.width;text:root.heading;textFormat:Text.PlainText;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:14;color:Config.DirectoryStyle.ink}
        Text {visible:!root.groups.length;width:parent.width;text:"NO EVENTS IN THIS RANGE\nUse Add event or import an ICS calendar.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted;topPadding:24}
        Text {visible:root.grouping.limited;width:parent.width;text:"DISPLAY LIMIT // reduce the range or filter to see the remaining dates.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.Theme.warning}
        Repeater {
            model:root.groups
            delegate:Column {
                id:group
                required property var modelData
                width:body.width;spacing:6
                Text {width:parent.width;text:root.dateHeading(group.modelData.date)+" // "+group.modelData.events.length;wrapMode:Text.WordWrap;textFormat:Text.PlainText;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;color:Config.DirectoryStyle.muted;topPadding:8}
                Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
                Repeater {
                    model:group.modelData.events
                    delegate:DirectoryButton {
                        required property var modelData
                        width:group.width;text:modelData.title
                        detail:(modelData.kind==="note"?"NOTE":modelData.allDay?"ALL DAY":modelData.date<group.modelData.date?"CONTINUES":modelData.time+"–"+modelData.endTime)+(modelData.lastDate>group.modelData.date?" // THROUGH "+Format.display(modelData.lastDate,CalendarState.Navigation.dateFormat):"")+"\n"+modelData.calendar+(modelData.location?" · "+modelData.location:"")+(modelData.hasNotes?" // NOTES":"")+(modelData.hasLink?" // LINK":"")+(modelData.pending?" // QUEUED OFFLINE":"")+(modelData.conflict?" // SYNC CONFLICT":"")
                        wrapDetail:true;accentColor:modelData.color||Config.DirectoryStyle.ink
                        Accessible.name:"Open event "+modelData.title+". "+group.modelData.date+". "+detail
                        onClicked:root.eventRequested(modelData)
                    }
                }
            }
        }
    }
}
