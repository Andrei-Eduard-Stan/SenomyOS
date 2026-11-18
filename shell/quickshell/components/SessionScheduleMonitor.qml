import QtQuick
import "../config" as Config

// Session-only arrangement over the existing authoritative model and timeline.
// Notification and Rail presentation deliberately remain independent of this layout.
Column {
    id: root
    required property var service
    readonly property var current: service.schedule || {}
    readonly property bool pending: current.state==="scheduled"
    readonly property bool manageable: ["scheduled","missed","failed"].includes(current.state)
    signal editRequested()
    function focusCancel(){cancelControl.forceActiveFocus();}
    spacing: 9
    Text {
        width:parent.width
        text:String(root.current.label||"Session").toUpperCase()+" "+(root.pending?"PENDING":String(root.current.state||"").toUpperCase())
        wrapMode:Text.WordWrap;color:Config.QuickPanelStyle.ink
        font.family:Config.QuickPanelStyle.headingFont;font.pixelSize:Config.QuickPanelStyle.deviceSize
    }
    Text {
        width:parent.width;text:root.current.mode==="at"?"DATE & TIME / PERSISTENT":"COUNTDOWN / TEMPORARY"
        wrapMode:Text.WordWrap;color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize
    }
    Text {
        width:parent.width;text:root.current.dueLabel||"";wrapMode:Text.WordWrap
        color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize
    }
    Column {
        visible:root.pending;width:parent.width;spacing:3
        Text {objectName:"session-countdown";width:parent.width;text:"T−"+root.service.remainingText;color:Config.QuickPanelStyle.ink;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Math.round(24*Config.DirectoryStyle.textScale);wrapMode:Text.WordWrap;Accessible.name:root.current.label+" in "+root.service.remainingText}
        Text {text:"REMAINING";color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize}
    }
    Column {
        visible:root.pending;width:parent.width;spacing:3
        ScheduleRail {width:parent.width;progress:root.service.progress;critical:root.service.remainingSeconds<=60}
        Row {
            width:parent.width
            Text {width:parent.width/2;text:root.current.createdEpoch?"START / "+Qt.formatDateTime(new Date(root.current.createdEpoch*1000),"HH:mm"):"START";color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize;elide:Text.ElideRight}
            Text {width:parent.width/2;text:root.current.dueEpoch?"EXEC / "+Qt.formatDateTime(new Date(root.current.dueEpoch*1000),"HH:mm"):"EXECUTION";horizontalAlignment:Text.AlignRight;color:Config.QuickPanelStyle.secondary;font.family:Config.QuickPanelStyle.dataFont;font.pixelSize:Config.QuickPanelStyle.metadataSize;elide:Text.ElideRight}
        }
    }
    Text {
        visible:!root.pending||root.service.remainingSeconds<=300
        width:parent.width
        text:!root.pending?root.current.message||"Dispatch result unavailable.":["reboot","poweroff","logout"].includes(root.current.action)?"Save your work. Unsaved changes may be lost.":"The authorised action will run at the deadline."
        color:Config.QuickPanelStyle.ink;wrapMode:Text.WordWrap;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize
    }
    Text {visible:!!root.current.statusDetail;width:parent.width;text:root.current.statusDetail||"";color:Config.QuickPanelStyle.secondary;wrapMode:Text.WordWrap;font.family:Config.QuickPanelStyle.bodyFont;font.pixelSize:Config.QuickPanelStyle.bodySize}
    Row {
        visible:root.manageable;width:parent.width;spacing:4
        DashboardButton {objectName:"session-change";width:(parent.width-4)/2;text:"EDIT";headerControl:true;enabled:!root.service.busy;onClicked:root.editRequested()}
        DashboardButton {id:cancelControl;objectName:"session-cancel-timer";width:(parent.width-4)/2;text:"CANCEL";headerControl:true;enabled:!root.service.busy;onClicked:root.service.cancelSchedule()}
    }
    Flow {
        visible:root.manageable;width:parent.width;spacing:4
        DashboardButton {objectName:"session-execute-now";width:Math.min(parent.width,130);text:"EXECUTE NOW";labelSize:Config.QuickPanelStyle.metadataSize;headerControl:true;enabled:!root.service.busy;onClicked:root.service.executeSchedule()}
        DashboardButton {objectName:"session-postpone-600";visible:root.pending;width:Math.min(parent.width,86);text:"+10 MIN";labelSize:Config.QuickPanelStyle.metadataSize;headerControl:true;enabled:!root.service.busy;onClicked:root.service.postpone(600)}
        DashboardButton {objectName:"session-postpone-1800";visible:root.pending;width:Math.min(parent.width,86);text:"+30 MIN";labelSize:Config.QuickPanelStyle.metadataSize;headerControl:true;enabled:!root.service.busy;onClicked:root.service.postpone(1800)}
    }
}
