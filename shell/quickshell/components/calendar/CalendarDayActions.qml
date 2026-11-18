import QtQuick
import QtQuick.Controls
import ".."
import "../../config" as Config
import "../../services/calendar" as CalendarState

Popup {
    id:root
    parent:Overlay.overlay
    property var service:null
    property var anchorItem:null
    property string dateKey:""
    readonly property var entries:service?service.entries.filter(e=>e.date<=dateKey&&e.lastDate>=dateKey):[]
    signal addEventRequested(string date)
    signal addNoteRequested(string date)
    signal viewDayRequested(string date)
    signal importRequested()
    signal eventRequested(var entry)
    width:Math.max(1,Math.min(320,parent?parent.width-24:320))
    height:Math.min(body.implicitHeight+24,parent?Math.max(1,parent.height-24):560)
    padding:12;focus:true;closePolicy:Popup.CloseOnEscape|Popup.CloseOnPressOutside
    function openFor(item,key) {
        anchorItem=item;dateKey=key;
        const point=item.mapToItem(parent,0,0);
        x=Math.max(12,Math.min(point.x,parent.width-width-12));
        y=Math.max(12,point.y+item.height+6+height<parent.height-12?point.y+item.height+6:Math.min(point.y-height-6,parent.height-height-12));
        open();Qt.callLater(()=>addEvent.forceActiveFocus());
    }
    onClosed:if(anchorItem&&anchorItem.visible)anchorItem.forceActiveFocus()
    background:ShellSurfaceFrame {contentInset:0;perimeterCorner:16;backdropColor:Config.Theme.surfaceRaised;stateColor:"transparent";animate:root.visible&&!((Config.Skin.registry.persona||{}).reducedMotion)}
    contentItem:FocusScrollArea {
        contentHeight:body.implicitHeight
        ScrollBar.vertical:ShellScrollBar {}
        Column {
            id:body;width:Math.max(1,parent.width-8);spacing:6
            Row {
                width:parent.width;spacing:4
                Text {width:parent.width-48;anchors.verticalCenter:parent.verticalCenter;text:root.dateKey?Qt.formatDate(CalendarState.Navigation.dateAt(Number(root.dateKey.slice(0,4)),Number(root.dateKey.slice(5,7))-1,Number(root.dateKey.slice(8,10))),CalendarState.Navigation.dateFormat==="us"?"ddd, MMM d, yyyy":"ddd, d MMM yyyy"):"";wrapMode:Text.WordWrap;textFormat:Text.PlainText;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:14;color:Config.DirectoryStyle.ink}
                DashboardButton {width:44;height:44;text:"×";headerControl:true;accessibleLabel:"Close date actions";onClicked:root.close()}
            }
            Text {width:parent.width;text:root.entries.length?root.entries.length+" saved item"+(root.entries.length===1?"":"s"):"Nothing saved for this day yet";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:11;color:Config.DirectoryStyle.muted}
            DashboardButton {id:addEvent;objectName:"date-add-event";width:parent.width;text:"ADD EVENT";enabled:!!(root.service&&root.service.available&&!root.service.busy);onClicked:{root.close();root.addEventRequested(root.dateKey);}}
            DashboardButton {objectName:"date-add-note";width:parent.width;text:"ADD NOTE";enabled:addEvent.enabled;onClicked:{root.close();root.addNoteRequested(root.dateKey);}}
            DashboardButton {objectName:"date-view-day";width:parent.width;text:"VIEW THIS DAY";onClicked:{root.close();root.viewDayRequested(root.dateKey);}}
            DashboardButton {objectName:"date-import-list";width:parent.width;text:"IMPORT A LIST";enabled:addEvent.enabled;onClicked:{root.close();root.importRequested();}}
            Repeater {
                model:root.entries.slice(0,3)
                delegate:DirectoryButton {
                    required property var modelData
                    width:body.width;text:modelData.title;detail:modelData.kind==="note"?"DATED NOTE":modelData.allDay?"ALL DAY":modelData.time+"–"+modelData.endTime
                    onClicked:{root.close();root.eventRequested(modelData);}
                }
            }
        }
    }
}
