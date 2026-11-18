import QtQuick
import "../config" as Config

Column {
    id: root
    required property var service
    property bool notification: false
    property bool finalWarning: false
    property bool managementVisible: true
    readonly property var current: service ? service.schedule || {} : ({})
    readonly property bool pending: current.state === "scheduled"
    readonly property bool manageable: ["scheduled","missed","failed"].includes(current.state)
    function focusCancel(){cancelControl.forceActiveFocus();}
    signal openSessionRequested()
    signal editRequested()
    spacing: 6
    Text {
        width: parent.width
        text: root.finalWarning ? "FINAL COUNTDOWN" : root.notification ? "SYSTEM COMMITMENT / 01" : root.pending ? "ACTIVE SCHEDULE / 01" : "SESSION RECORD / " + String(root.current.state || "").toUpperCase()
        color: Config.QuickPanelStyle.secondary
        font.family: Config.QuickPanelStyle.dataFont; font.pixelSize: Config.QuickPanelStyle.metadataSize
        wrapMode: Text.WordWrap
    }
    Text {
        width: parent.width
        text: String(root.current.label || "Session action").toUpperCase() + (root.pending ? " SCHEDULED" : " / " + String(root.current.state || "").toUpperCase())
        color: Config.QuickPanelStyle.ink; font.family: Config.QuickPanelStyle.headingFont; font.pixelSize: Config.QuickPanelStyle.deviceSize
        wrapMode: Text.WordWrap
    }
    Text {
        width: parent.width; text: root.current.dueLabel || ""
        color: Config.QuickPanelStyle.secondary; font.family: Config.QuickPanelStyle.dataFont; font.pixelSize: Config.QuickPanelStyle.metadataSize
        wrapMode: Text.WordWrap
    }
    Text {
        objectName: "session-countdown"
        width: parent.width
        text: root.pending ? "T−" + root.service.remainingText : root.current.message || ""
        color: Config.QuickPanelStyle.ink; font.family: Config.QuickPanelStyle.dataFont
        font.pixelSize: root.pending ? Math.round((root.service.remainingSeconds <= 60 ? 26 : 21)*Config.DirectoryStyle.textScale) : Config.QuickPanelStyle.bodySize
        wrapMode: Text.WordWrap
        Accessible.name: root.pending ? root.current.label + " in " + root.service.remainingText : text
    }
    ScheduleRail { width: parent.width; visible: root.pending; progress: root.service ? root.service.progress : 0; critical: root.service && root.service.remainingSeconds <= 60 }
    Text {
        visible: root.pending && root.service.remainingSeconds <= 300
        width: parent.width
        text: ["reboot","poweroff","logout"].includes(root.current.action) ? "Save your work. Unsaved changes may be lost." : "The authorised session action will run at the deadline."
        color: Config.QuickPanelStyle.ink; font.family: Config.QuickPanelStyle.bodyFont; font.pixelSize: Config.QuickPanelStyle.bodySize; wrapMode: Text.WordWrap
    }
    Text {
        visible: !!root.current.statusDetail
        width: parent.width; text: root.current.statusDetail || ""
        wrapMode: Text.WordWrap; color: Config.QuickPanelStyle.ink
        font.family: Config.QuickPanelStyle.bodyFont; font.pixelSize: Config.QuickPanelStyle.bodySize
    }
    Text {
        visible: root.notification && !!(root.service && root.service.error)
        width: parent.width; text: root.service ? root.service.error : ""
        wrapMode: Text.WordWrap; color: Config.QuickPanelStyle.ink
        font.family: Config.QuickPanelStyle.bodyFont; font.pixelSize: Config.QuickPanelStyle.bodySize
    }
    Flow {
        visible: root.manageable && root.managementVisible; width: parent.width; spacing: 4
        DashboardButton {id:cancelControl;objectName:"session-cancel-timer";width:Math.min(104,parent.width);text:"CANCEL";headerControl:true;enabled:!root.service.busy;onClicked:root.service.cancelSchedule()}
        DashboardButton {objectName:"session-change";width:Math.min(140,parent.width);text:root.notification?"OPEN SESSION":"EDIT";headerControl:true;enabled:!root.service.busy;onClicked:root.notification?root.openSessionRequested():root.editRequested()}
        DashboardButton {objectName:"session-execute-now";visible:!root.notification;width:Math.min(140,parent.width);text:"EXECUTE NOW";headerControl:true;enabled:!root.service.busy;onClicked:root.service.executeSchedule()}
        DashboardButton {objectName:"session-postpone-600";visible:!root.notification&&root.pending;width:Math.min(104,parent.width);text:"+10 MIN";headerControl:true;enabled:!root.service.busy;onClicked:root.service.postpone(600)}
        DashboardButton {objectName:"session-postpone-1800";visible:!root.notification&&root.pending;width:Math.min(104,parent.width);text:"+30 MIN";headerControl:true;enabled:!root.service.busy;onClicked:root.service.postpone(1800)}
    }
}
