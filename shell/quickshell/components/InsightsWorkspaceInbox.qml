import QtQuick
import QtQuick.Controls
import "../config" as Config
import "notifications" as Notifications
import "calendar" as CalendarUi
Item {
 id:root;required property var workspace
 readonly property var notifications:workspace.notifications
 readonly property string context:"insights:"+(workspace.targetScreen?workspace.targetScreen.name:"")
 property string filterMode:workspace.readState("notifications","filter","all")
 function back(){return inbox.back();}
 Column {id:header;width:parent.width;spacing:12
  InsightsWorkspaceTitle {width:parent.width;title:"Notifications";detail:root.notifications.serverEnabled?root.notifications.unreadCount+" unread · "+root.notifications.history.length+" saved locally":"Notification provider unavailable"}
  Flow {width:parent.width;spacing:8
   QuietButton {objectName:"insights-inbox-all";text:"All";Accessible.checkable:true;Accessible.checked:active;active:root.filterMode==="all";onClicked:{root.filterMode="all";root.workspace.remember("notifications","filter",root.filterMode);}}
   QuietButton {objectName:"insights-inbox-unread";text:"Unread";Accessible.checkable:true;Accessible.checked:active;active:root.filterMode==="unread";onClicked:{root.filterMode="unread";root.workspace.remember("notifications","filter",root.filterMode);}}
   QuietButton {objectName:"insights-inbox-dnd";text:root.notifications.dnd?"Quiet on":"Quiet off";glyph:"\uf1f6";active:root.notifications.dnd;Accessible.checkable:true;Accessible.checked:active;enabled:root.notifications.serverEnabled && !root.notifications.clearActions.locked;onClicked:root.notifications.setDnd(!root.notifications.dnd)}
   QuietButton {objectName:"notifications-read-all";text:"Mark all read";enabled:root.notifications.unreadCount>0 && !root.notifications.clearActions.locked;onClicked:root.notifications.markRead()}
   QuietButton {objectName:"insights-inbox-clear";text:"Clear all";enabled:root.notifications.clearAvailable && !root.notifications.clearActions.locked && (root.notifications.history.length>0 || root.notifications.activeCount>0);onClicked:root.notifications.clearAll(root.context)}
  }
  InsightsWorkspaceSearch {id:search;objectName:"insights-inbox-search";width:parent.width;placeholderText:"Search messages or apps";text:root.workspace.readState("notifications","search","");onTextEdited:root.workspace.remember("notifications","search",text);Accessible.name:"Search saved notifications"}
  Text {visible:root.notifications.dnd;width:parent.width;text:"Quiet mode suppresses popups, including critical alerts. Non-transient notifications stay in history; transient alerts are not saved or replayed. Session-action warnings use their own policy.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
  NotificationQuickClearReview {width:parent.width;actions:root.notifications.clearActions;ownerContext:root.context}
 }
 FocusScrollArea {id:scroll;y:header.height+16;width:parent.width;height:Math.max(1,parent.height-y);contentHeight:content.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
  Column {id:content;width:parent.width-12;spacing:16
   NotificationQuickCommitment {objectName:"system-commitment";width:parent.width;visible:!!root.notifications.commitment;notification:true;service:root.notifications.sessionService || null;onOpenSessionRequested:root.notifications.openSessionRequested()}
   Notifications.NotificationQuickList {id:inbox;objectName:"insights-inbox-list";width:parent.width;notifications:root.notifications;search:search.text;filterMode:root.filterMode;onFocusSearchRequested:search.forceActiveFocus()}
  }
 }
}
