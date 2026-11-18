import QtQuick
import "interaction" as Interaction
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import "../config" as Config
import "notifications" as Notifications

Interaction.QuickPopoverWindow {
    id: root

    required property var notifications
    required property string clearContext
    signal openHistoryRequested

    readonly property real availableWidth: (targetScreen || (anchorItem && anchorItem.Window.window)) ? (targetScreen ? targetScreen.width : anchorItem.Screen.width) - 2 * Config.Theme.screenInset : 470
    readonly property real availableHeight: (targetScreen || (anchorItem && anchorItem.Window.window)) ? (targetScreen ? targetScreen.height : anchorItem.Screen.height) - Config.Theme.railHeight - 2 * Config.Theme.screenInset : 800
    implicitWidth: Math.min(520, Math.max(1, availableWidth))
    implicitHeight: Math.min(Math.max(1,availableHeight), Math.max(300,2*popupFrame.contentInset+heading.height+footer.implicitHeight+24+Math.min(420,body.implicitHeight)))
    color: "transparent"

    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.rect.x: anchorItem ? anchorItem.width / 2 : 0
    anchor.rect.y: -12
    anchor.rect.width: 0
    anchor.rect.height: 0

    keyboardPriority:true
    focusTarget: card

    FocusScope {
        id: card
        anchors.fill: parent
        focus: root.cardShown
        opacity: root.presentationProgress
        scale: 1
        transform: Translate {
            y: root.cardShown ? 0 : 12

        }


        Keys.onEscapePressed: if (root.notifications.clearActions.locked || !inbox.back()) root.handleEscape()

        IslandPopupFrame {
            id:popupFrame;frameKey:"notifications";anchors.fill:parent;contentInset:24
            readonly property bool reviewing:root.notifications.clearActions.locked && root.notifications.clearActions.requestedContext===root.clearContext
            Row {
                id:heading;width:parent.width;height:Math.max(Config.DirectoryStyle.controlTarget,title.implicitHeight);spacing:8
                Column {
                    id:title;width:parent.width-close.width-8;anchors.verticalCenter:parent.verticalCenter;spacing:4
                    Text {width:parent.width;text:"// Notifications";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Math.round(16*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink}
                    Text {width:parent.width;text:root.notifications.unreadCount+" unread · "+root.notifications.history.length+" saved";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
                }
                QuietButton {id:close;objectName:"notifications-close";width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf00d";accessibleLabel:"Close notifications";onClicked:root.dismiss()}
            }
            Column {
                id:footer;width:parent.width;anchors.bottom:parent.bottom;spacing:8
                IslandRule {width:parent.width;leadingPoint:false}
                Flow {
                    id:bulk;visible:!popupFrame.reviewing;width:parent.width;spacing:8
                    TextMetrics {id:bulkMeasure;text:"Mark all read";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                    readonly property int columns:width>=2*(bulkMeasure.advanceWidth+2*Config.DirectoryStyle.controlInset)+8?2:1
                    readonly property real cellWidth:(width-(columns-1)*8)/columns
                    QuietButton {objectName:"notifications-read-all";width:bulk.cellWidth;text:"Mark all read";accessibleLabel:"Mark all saved notifications read";enabled:root.notifications.unreadCount>0 && !root.notifications.clearActions.locked;onClicked:root.notifications.markRead()}
                    QuietButton {objectName:"notifications-clear-all";width:bulk.cellWidth;text:"Clear all";enabled:root.notifications.clearAvailable && !root.notifications.clearActions.locked && (root.notifications.history.length>0 || root.notifications.activeCount>0);onClicked:root.notifications.clearAll(root.clearContext)}
                }
                QuietButton {objectName:"open-notification-history";width:parent.width;text:"Notification history";glyph:"\uf03a";enabled:!root.notifications.clearActions.locked;accessibleLabel:"Open full notification history in Senomy Insights";onClicked:root.openHistoryRequested()}
            }
            FocusScrollArea {
                id:viewport;objectName:"notifications-viewport";anchors.fill:parent;anchors.topMargin:heading.height+12;anchors.bottomMargin:footer.implicitHeight+12
                contentHeight:body.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
                Column {
                    id:body;width:viewport.width-(Config.DirectoryStyle.touchMode?24:10);spacing:12
                    Column {
                        visible:!popupFrame.reviewing;width:parent.width;spacing:12
                        Flow {
                            id:filters;width:parent.width;spacing:8
                            TextMetrics {id:filterMeasure;text:"Quiet off";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                            readonly property bool singleRow:width>=3*(filterMeasure.advanceWidth+24+2*Config.DirectoryStyle.controlInset)+16
                            readonly property real cellWidth:singleRow?(width-16)/3:(width-8)/2
                            QuietButton {objectName:"notifications-filter-all";width:filters.cellWidth;text:"All";active:inbox.filterMode==="all";Accessible.checkable:true;Accessible.checked:active;onClicked:inbox.filterMode="all"}
                            QuietButton {objectName:"notifications-filter-unread";width:filters.cellWidth;text:"Unread";active:inbox.filterMode==="unread";Accessible.checkable:true;Accessible.checked:active;onClicked:inbox.filterMode="unread"}
                            QuietButton {objectName:"notifications-quiet";width:filters.singleRow?filters.cellWidth:filters.width;text:root.notifications.dnd?"Quiet on":"Quiet off";glyph:"\uf1f6";active:root.notifications.dnd;Accessible.checkable:true;Accessible.checked:active;enabled:root.notifications.serverEnabled && !root.notifications.clearActions.locked;accessibleLabel:root.notifications.dnd?"Turn off quiet mode":"Turn on quiet mode";onClicked:root.notifications.setDnd(!root.notifications.dnd)}
                        }
                        ShellTextField {id:search;objectName:"notification-history-search";width:parent.width;placeholderText:"Search saved notifications…";Accessible.name:"Search saved notifications"}
                        Text {visible:root.notifications.dnd;width:parent.width;text:"Quiet mode suppresses popups, including critical alerts. Non-transient notifications stay in history; transient alerts are not saved or replayed. Session-action warnings use their own policy.";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
                    }
                    Text {visible:!root.notifications.serverEnabled;width:parent.width;text:"Native notification server unavailable. Saved messages remain readable.";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
                    Text {visible:!!root.notifications.error;width:parent.width;text:root.notifications.error || "";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.Theme.danger}
                    NotificationQuickCommitment {objectName:"system-commitment";width:parent.width;visible:!!root.notifications.commitment;notification:true;service:root.notifications.sessionService || null;onOpenSessionRequested:root.notifications.openSessionRequested()}
                    NotificationQuickClearReview {id:review;width:parent.width;actions:root.notifications.clearActions;ownerContext:root.clearContext}
                    Notifications.NotificationQuickList {id:inbox;objectName:"archive-list";width:parent.width;visible:!popupFrame.reviewing;notifications:root.notifications;search:search.text;onFocusSearchRequested:search.forceActiveFocus()}
                }
            }
        }
    }
}
