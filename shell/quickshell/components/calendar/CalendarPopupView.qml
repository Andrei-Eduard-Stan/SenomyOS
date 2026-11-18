import QtQuick
import "../interaction" as Interaction
import QtQuick.Controls
import ".." as UI
import "../../config" as Config
import "../../services/calendar" as CalendarState

Item {
    id:root
    Interaction.ContentMotion {targetItem:composition;context:String(root.monthOpen);active:root.active}
    property var service:null
    property bool active:false
    property real agendaReserve:0
    property bool monthOpen:false
    readonly property var model:calendar
    readonly property bool wide:width>=660
    readonly property bool interactive:viewport.interactive
    property alias contentY:viewport.contentY
    implicitHeight:header.height+12+body.implicitHeight+12+footer.implicitHeight
    signal dismissRequested()
    signal openCalendarRequested(string route)
    signal eventRequested(var entry)
    signal addEventRequested(string date)
    function focusSelected(){calendar.showSelected();if(wide || monthOpen)grid.requestFocus();else monthToggle.forceActiveFocus(Qt.PopupFocusReason);}
    function dismissPreview(){if(!agenda.selectedEntry)return false;agenda.closePreview();return true;}
    onActiveChanged:if(active){agendaReserve=agenda.desiredHeight;viewport.contentY=0;if(!wide)monthOpen=false;}
    onWideChanged:{if(!wide)monthOpen=false;viewport.contentY=0;if(active)Qt.callLater(focusSelected);}
    CalendarState.CalendarQuickModel {id:calendar;service:root.service;active:root.active}
    Row {
        id:header;width:parent.width;height:Math.max(Config.DirectoryStyle.controlTarget,headerIdentity.implicitHeight);spacing:8
        Column {
            id:headerIdentity;width:parent.width-close.width-briefing.width-16;anchors.verticalCenter:parent.verticalCenter;spacing:4
            Text {text:"// Calendar";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Math.round(16*Config.DirectoryStyle.textScale)}
            Text {objectName:"quick-calendar-current-date";width:parent.width;text:"Local · "+Qt.formatDate(calendar.navigation.today,"ddd, d MMMM yyyy");textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
        }
        UI.QuietButton {id:briefing;objectName:"open-calendar-briefing";width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf03a";accessibleLabel:"Open upcoming event briefing";onClicked:root.openCalendarRequested("calendar/briefing")}
        UI.QuietButton {id:close;objectName:"quick-calendar-close";width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf00d";accessibleLabel:"Close calendar";onClicked:root.dismissRequested()}
    }
    Column {
        id:footer;width:parent.width;anchors.bottom:parent.bottom;spacing:12
        UI.IslandRule {width:parent.width;leadingPoint:false}
        Flow {
            id:exits;width:parent.width;spacing:8
            TextMetrics {id:footerMeasure;text:"New event";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
            readonly property int columns:width>=2*(footerMeasure.advanceWidth+24+2*Config.DirectoryStyle.controlInset)+8?2:1
            readonly property real cellWidth:(width-(columns-1)*8)/columns
            UI.QuietButton {objectName:"open-calendar-workspace";width:exits.cellWidth;text:"Calendar";glyph:"\uf073";accessibleLabel:"Open full calendar workspace";onClicked:root.openCalendarRequested("calendar")}
            UI.QuietButton {objectName:"quick-calendar-add";width:exits.cellWidth;text:"New event";glyph:"\uf067";enabled:calendar.canCreate;accessibleLabel:"Add event on "+calendar.selectedKey;onClicked:root.addEventRequested(calendar.selectedKey)}
        }
    }
    UI.FocusScrollArea {
        id:viewport;objectName:"calendar-popup-viewport";anchors.fill:parent;anchors.topMargin:header.height+12;anchors.bottomMargin:footer.implicitHeight+12
        contentHeight:body.implicitHeight;interactive:contentHeight>height
        ScrollBar.vertical:UI.ShellScrollBar {}
        Column {
            id:body;width:viewport.width-(root.wide?0:10);spacing:12
            UI.QuietButton {
                id:monthToggle;objectName:"calendar-month-toggle";width:parent.width;visible:!root.wide;text:root.monthOpen?"Hide month":"Choose date";glyph:root.monthOpen?"\uf077":"\uf073";Accessible.expandable:true;Accessible.expanded:root.monthOpen
                onClicked:{root.monthOpen=!root.monthOpen;if(root.monthOpen)grid.requestFocus();}
            }
        Grid {
            id:composition;width:parent.width;columns:root.wide?2:1;columnSpacing:24;rowSpacing:24
            Column {
                id:monthPane;visible:root.wide || root.monthOpen;width:root.wide?(Config.DirectoryStyle.touchMode?348:320):composition.width;spacing:12
                Text {objectName:"quick-calendar-month";width:parent.width;text:Qt.formatDate(calendar.viewedMonth,"MMMM yyyy");textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.valueFont;font.pixelSize:Math.round(20*Config.DirectoryStyle.textScale)}
                Row {
                    width:parent.width;height:Config.DirectoryStyle.controlTarget;spacing:8
                    UI.QuietButton {objectName:"quick-calendar-previous";width:(parent.width-16)/3;iconOnly:true;glyph:"\uf104";accessibleLabel:"Previous month. Page Up";enabled:calendar.canBrowse(-1);onClicked:calendar.browse(-1)}
                    UI.QuietButton {objectName:"quick-calendar-today";width:(parent.width-16)/3;text:"Today";accessibleLabel:"Select today. Control Home";onClicked:{calendar.today();grid.requestFocus();}}
                    UI.QuietButton {objectName:"quick-calendar-next";width:(parent.width-16)/3;iconOnly:true;glyph:"\uf105";accessibleLabel:"Next month. Page Down";enabled:calendar.canBrowse(1);onClicked:calendar.browse(1)}
                }
                CalendarPopupGrid {id:grid;objectName:"quick-calendar-grid";width:parent.width;height:implicitHeight;model:calendar}
            }
            CalendarPopupAgenda {
                id:agenda;objectName:"calendar-popup-agenda";width:root.wide?composition.width-monthPane.width-24:composition.width;height:root.wide?monthPane.implicitHeight:Math.max(root.agendaReserve,desiredHeight)
                model:calendar
                onDesiredHeightChanged:if(root.active)root.agendaReserve=Math.max(root.agendaReserve,desiredHeight)
                onEventRequested:entry=>root.eventRequested(entry)
            }
        }
        }
    }
}
