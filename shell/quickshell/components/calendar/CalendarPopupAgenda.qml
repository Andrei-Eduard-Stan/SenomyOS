import QtQuick
import "../interaction" as Interaction
import QtQuick.Controls
import ".." as UI
import "../../config" as Config

Item {
    id:root
    Interaction.ContentMotion {targetItem:root;context:root.model.selectedKey+":"+String(root.selectedEntry?root.selectedEntry.id:"");active:root.visible}
    required property var model
    property var selectedEntry:null
    property int previewIndex:0
    readonly property int rowHeight:Math.max(72,72*Config.DirectoryStyle.textScale)
    readonly property string stateMessage:!model.available?"Calendar service unavailable. Saved data is retained.":model.loading?"Loading events…":model.dayError?model.dayError:!model.hasSources?(model.service && (model.service.sources || []).length?"No visible calendar sources.":"No calendar source available."):!model.entries.length?"No events for this day.":""
    readonly property real desiredHeight:heading.height+12+Math.max(80,Math.min(3,model.entries.length)*rowHeight)+ (limit.visible?limit.implicitHeight+8:0)
    signal eventRequested(var entry)
    function timeLabel(entry){return entry.kind==="note"?"Note":entry.allDay?"All day":entry.date<model.selectedKey?"Continues":entry.time || "Time unavailable";}
    function sameEntry(a,b){return a && b && a.source===b.source && a.uid===b.uid && a.rid===b.rid && a.date===b.date;}
    function closePreview(){selectedEntry=null;Qt.callLater(function(){const row=entries.itemAt(root.previewIndex);if(row)row.forceActiveFocus();});}
    Connections {
        target:root.model
        function onSelectedKeyChanged(){root.selectedEntry=null;}
        function onEntriesChanged(){if(root.selectedEntry)root.selectedEntry=root.model.entries.find(e=>root.sameEntry(e,root.selectedEntry)) || null;}
    }
    Row {
        id:heading;width:parent.width;height:Math.max(day.implicitHeight,identity.implicitHeight);spacing:12
        Text {id:day;text:Qt.formatDate(root.model.navigation.selectedDate,"d");font.family:Config.DirectoryStyle.valueFont;font.pixelSize:Math.round(44*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink;Accessible.ignored:true}
        Column {
            id:identity;width:Math.max(1,parent.width-day.width-12);anchors.verticalCenter:parent.verticalCenter;spacing:3
            Text {width:parent.width;text:Qt.formatDate(root.model.navigation.selectedDate,"dddd");font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(18*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
            Text {width:parent.width;text:Qt.formatDate(root.model.navigation.selectedDate,"d MMMM yyyy")+(root.model.selectedKey===root.model.navigation.todayKey?" · Today":"");font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
            Text {width:parent.width;text:!root.model.available?"Unavailable":root.model.loading?"Loading…":root.model.dayError?"Could not load events":!root.model.hasSources?"No visible sources":root.model.entries.length+(root.model.entries.length===1?" saved item":" saved items");font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
            Text {objectName:"calendar-agenda-timezone";width:parent.width;text:root.model.service && root.model.service.preferences.timezone && root.model.service.preferences.timezone!=="local"?"Times · "+root.model.service.preferences.timezone:"Local time";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
        }
    }
    UI.FocusScrollArea {
        id:list;objectName:"quick-calendar-agenda-list";anchors.fill:parent;anchors.topMargin:heading.height+12;anchors.bottomMargin:limit.visible?limit.implicitHeight+8:0
        contentHeight:root.selectedEntry?preview.implicitHeight:root.stateMessage?empty.implicitHeight:rows.implicitHeight
        interactive:contentHeight>height
        ScrollBar.vertical:UI.ShellScrollBar {}
        Text {id:empty;objectName:"quick-calendar-empty";visible:!!root.stateMessage && !root.selectedEntry;width:parent.width;text:root.stateMessage;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted;Accessible.role:Accessible.StaticText;Accessible.name:text}
        Column {
            id:rows;visible:!root.stateMessage && !root.selectedEntry;width:list.width-(Config.DirectoryStyle.touchMode?24:10);spacing:8
            Repeater {
                id:entries;model:root.model.entries
                delegate:UI.QuietButton {
                    id:entry;required property var modelData;required property int index
                    objectName:"quick-calendar-event-"+index;width:rows.width;height:Math.max(root.rowHeight,title.implicitHeight+detail.implicitHeight+2*Config.DirectoryStyle.controlVerticalInset+4)
                    accessibleLabel:modelData.title+". "+root.timeLabel(modelData)+". "+(modelData.location || "")+". "+modelData.calendar
                    onClicked:{root.previewIndex=index;root.selectedEntry=modelData;list.contentY=0;Qt.callLater(function(){previewBack.forceActiveFocus();});}
                    contentItem:Item {
                        Text {id:time;x:Config.DirectoryStyle.controlInset;width:Math.min(72*Config.DirectoryStyle.textScale,parent.width*.27);anchors.verticalCenter:parent.verticalCenter;text:root.timeLabel(entry.modelData)+(entry.modelData.endTime && !entry.modelData.allDay && entry.modelData.date>=root.model.selectedKey?"\n"+entry.modelData.endTime:"");font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Math.round(12*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
                        Column {
                            x:time.x+time.width+8;width:Math.max(1,parent.width-x-Config.DirectoryStyle.controlInset);anchors.verticalCenter:parent.verticalCenter;spacing:4
                            Text {id:title;width:parent.width;text:entry.modelData.title;textFormat:Text.PlainText;wrapMode:Text.WordWrap;maximumLineCount:2;elide:Text.ElideRight;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
                            Text {id:detail;width:parent.width;text:entry.modelData.calendar+(entry.modelData.location?" · "+entry.modelData.location:"")+(entry.modelData.pending?" · Queued offline":"")+(entry.modelData.conflict?" · Sync conflict":"");textFormat:Text.PlainText;wrapMode:Text.WordWrap;maximumLineCount:2;elide:Text.ElideRight;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
                        }
                    }
                }
            }
        }
        Column {
            id:preview;objectName:"calendar-event-preview";visible:!!root.selectedEntry;width:list.width-10;spacing:12
            UI.QuietButton {id:previewBack;objectName:"calendar-preview-back";width:parent.width;text:"Back to day";glyph:"\uf104";onClicked:root.closePreview()}
            Text {width:parent.width;text:root.selectedEntry?root.selectedEntry.title:"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(20*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink}
            Text {width:parent.width;text:root.selectedEntry?(root.selectedEntry.lastDate && root.selectedEntry.lastDate!==root.selectedEntry.date?root.selectedEntry.date+" – "+root.selectedEntry.lastDate:Qt.formatDate(root.model.navigation.selectedDate,"dddd, d MMMM yyyy"))+"\n"+root.timeLabel(root.selectedEntry)+(root.selectedEntry.endTime && !root.selectedEntry.allDay?" – "+root.selectedEntry.endTime:""):"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
            Text {width:parent.width;visible:!!(root.selectedEntry && root.selectedEntry.location);text:root.selectedEntry?root.selectedEntry.location || "":"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
            Text {width:parent.width;text:root.selectedEntry?root.selectedEntry.calendar+(root.selectedEntry.pending?" · Queued offline":"")+(root.selectedEntry.conflict?" · Sync conflict":""):"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
            UI.QuietButton {objectName:"calendar-event-open";width:parent.width;text:"Open event";glyph:"\uf35d";enabled:!!root.selectedEntry && root.model.available;onClicked:if(root.selectedEntry)root.eventRequested(root.selectedEntry)}
        }
    }
    Text {id:limit;anchors.bottom:parent.bottom;width:parent.width;visible:root.model.dayTruncated || root.model.monthTruncated || !!root.model.monthError;text:root.model.monthError?"Event indicators unavailable. Open Calendar to review.":"Event limit reached. Open Calendar for more.";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
}
