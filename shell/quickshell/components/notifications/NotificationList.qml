import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../../config" as Config

// One bounded history renderer for the popup and Insights. Opening a record
// reads only that record; dismissal and native client actions are separate.
FocusScrollArea {
    id: root
    required property var notifications
    property string expandedKey: ""
    property alias search:historySearch.text
    readonly property var filteredHistory:{
        const query=search.trim().toLowerCase();
        return query?notifications.history.filter(record=>[record.appName,record.desktopEntry,record.summary,record.body].some(value=>String(value||"").toLowerCase().includes(query))):notifications.history;
    }
    onFilteredHistoryChanged:if(expandedKey&&!filteredHistory.some(record=>key(record)===expandedKey))expandedKey=""
    contentHeight: content.implicitHeight
    ScrollBar.vertical: ShellScrollBar {}
    Keys.onEscapePressed: event => {
        if (!expandedKey) { event.accepted = false; return; }
        const key = expandedKey;
        expandedKey = "";
        focusSoon(key);
    }
    function key(record) {
        return typeof notifications.recordKey === "function" ? notifications.recordKey(record)
            : String(record.id === undefined ? record.appName : record.id) + "@" + String(record.receivedAt || 0);
    }
    function isLive(record) {
        return typeof notifications.isLive === "function" ? notifications.isLive(record) : Boolean(record.actions && record.actions.length);
    }
    function timestamp(record) {
        return record.receivedAt ? Qt.formatDateTime(new Date(record.receivedAt), "ddd d MMM, HH:mm") : "Time unavailable";
    }
    function focusRecord(recordKey,reason) {
        for (let i = 0; i < records.count; ++i) {
            const row = records.itemAt(i);
            if (row && row.recordKey === recordKey) { row.openControl.focusReason=reason===undefined?Qt.TabFocusReason:reason;row.openControl.forceActiveFocus(row.openControl.focusReason); return; }
        }
    }
    property string pendingFocusKey: ""
    property int pendingFocusReason:Qt.OtherFocusReason
    Timer { id: focusTimer; interval: 1; onTriggered: root.focusRecord(root.pendingFocusKey,root.pendingFocusReason) }
    function focusSoon(recordKey,reason) { pendingFocusKey = recordKey;pendingFocusReason=reason===undefined?Qt.OtherFocusReason:reason;focusTimer.restart(); }
    function dismissRecord(record) {
        const index = filteredHistory.findIndex(item => key(item) === key(record));
        const next = filteredHistory[index + 1] || filteredHistory[index - 1];
        const nextKey = next ? key(next) : "";
        notifications.dismiss(record);
        expandedKey = "";
        if (nextKey) focusSoon(nextKey);else historySearch.forceActiveFocus();
    }
    function open(record,reason) {
        const recordKey = key(record);
        expandedKey = expandedKey === recordKey ? "" : recordKey;
        if (expandedKey && typeof notifications.markRead === "function") notifications.markRead(record);
        focusSoon(recordKey,reason);
    }
    Column {
        id: content
        width: parent.width
        spacing: 10
        ShellTextField {
            id:historySearch;objectName:"notification-history-search";width:parent.width
            placeholderText:"Search retained notifications…";Accessible.name:"Search retained notification history"
        }
        Text {
            width:parent.width;visible:root.notifications.dnd;text:"DND suppresses new notification popups, including critical alerts. Non-transient messages stay in history; transient alerts are not saved. Turning DND off does not replay them. Session-action countdown warnings follow their separate policy."
            textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize
        }
        Text {
            width: parent.width
            visible: Boolean(root.notifications.error)
            text: root.notifications.error || ""
            textFormat: Text.PlainText; wrapMode: Text.WordWrap
            color: Config.Theme.danger
            font.family: Config.DirectoryStyle.dataFont; font.pixelSize: 12
        }
        ScheduleCommitment {
            objectName: "system-commitment"
            width: parent.width
            visible: !!root.notifications.commitment
            notification: true
            service: root.notifications.sessionService || null
            onOpenSessionRequested: root.notifications.openSessionRequested()
        }
        Repeater {
            id: records
            model: root.filteredHistory
            delegate: Column {
                id: card
                required property var modelData
                required property int index
                readonly property string recordKey: root.key(modelData)
                readonly property bool expanded: root.expandedKey === recordKey
                property alias openControl: openButton
                width: content.width
                spacing: 8
                AbstractButton {
                    id:openButton
                    objectName:"notification-open-"+card.index
                    width:parent.width;implicitHeight:header.implicitHeight+24
                    text:card.modelData.summary;hoverEnabled:true;activeFocusOnTab:true
                    Accessible.name:(card.expanded?"Collapse ":"Open ")+text+". "+card.modelData.appName+". "+root.timestamp(card.modelData)+(card.modelData.unread?". Unread":". Read")
                    Accessible.description:"Open message details without dismissing the notification."
                    Keys.onReturnPressed:{focusReason=Qt.TabFocusReason;clicked();}
                    Keys.onEnterPressed:{focusReason=Qt.TabFocusReason;clicked();}
                    Keys.onDownPressed:root.focusRecord(root.key(root.filteredHistory[Math.min(records.count-1,card.index+1)]))
                    Keys.onUpPressed:root.focusRecord(root.key(root.filteredHistory[Math.max(0,card.index-1)]))
                    onClicked:root.open(card.modelData,openButton.focusReason)
                    background:Item {
                        ButtonHoverFrame {focused:openButton.visualFocus;anchors.fill:parent;engaged:openButton.hovered}
                    }
                    contentItem:Column {
                        id:header;spacing:7
                        GridLayout {
                            width:parent.width;columns:width<500*Config.DirectoryStyle.textScale?1:2;columnSpacing:12;rowSpacing:5
                            Text {Layout.fillWidth:true;Layout.minimumWidth:0;text:card.modelData.appName || "Application";textFormat:Text.PlainText;wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                            Text {text:(card.modelData.unread?"Unread · ":"")+root.timestamp(card.modelData);textFormat:Text.PlainText;color:card.modelData.unread?Config.DirectoryStyle.ink:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                        }
                        Text {width:parent.width;text:openButton.text;textFormat:Text.PlainText;wrapMode:Text.Wrap;color:card.modelData.urgency==="Critical"?Config.Theme.danger:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:card.modelData.unread?Font.DemiBold:Font.Normal}
                    }
                    leftPadding:Config.DirectoryStyle.controlInset;rightPadding:Config.DirectoryStyle.controlInset;topPadding:12;bottomPadding:12
                }
                Text {
                    width: parent.width - 24; x: 12
                    visible: String(card.modelData.body || "").length > 0
                    text: card.modelData.body || ""
                    textFormat: Text.PlainText
                    color: Config.DirectoryStyle.muted
                    font.family: Config.DirectoryStyle.bodyFont
                    font.pixelSize: Config.DirectoryStyle.bodySize
                    wrapMode: Text.WordWrap
                    maximumLineCount: card.expanded ? 10000 : 2
                    elide: card.expanded ? Text.ElideNone : Text.ElideRight
                }
                Text {
                    width: parent.width - 24; x: 12
                    visible: card.expanded
                    text: card.modelData.urgency + " // " + (root.isLive(card.modelData) ? "APPLICATION NOTIFICATION ACTIVE" : "RETAINED HISTORY — APPLICATION ACTIONS UNAVAILABLE")
                    textFormat: Text.PlainText
                    color: Config.DirectoryStyle.muted
                    font.family: Config.DirectoryStyle.dataFont
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
                Flow {
                    width: parent.width
                    spacing: 6
                    visible: card.expanded
                    Repeater {
                        model: root.isLive(card.modelData) ? card.modelData.actions || [] : []
                        delegate: DashboardButton {
                            required property var modelData
                            objectName: "notification-action-" + String(modelData.identifier || "")
                            width: Math.max(1, (parent.width - 6) / 2)
                            height: 44
                            text: modelData.text || modelData.identifier || "ACTION"
                            onClicked: root.notifications.invoke(card.modelData, modelData)
                        }
                    }
                    DashboardButton {
                        objectName: "notification-dismiss-" + card.index
                        width: Math.min(124, parent.width); height: 44
                        text: "DISMISS"
                        accessibleLabel: "Dismiss " + card.modelData.summary + " and remove its history entry"
                        onClicked: root.dismissRecord(card.modelData)
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Config.DirectoryStyle.rule }
            }
        }
        Text {
            visible: root.filteredHistory.length === 0
            width: parent.width
            topPadding: 60
            text: root.notifications.history.length>0 ? "NO MATCHING RETAINED NOTIFICATIONS" : root.notifications.serverEnabled ? "NO RETAINED NOTIFICATIONS\nTransient notifications are not saved." : "NATIVE NOTIFICATION SERVER UNAVAILABLE"
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Config.DirectoryStyle.muted
            font.family: Config.DirectoryStyle.dataFont
            font.pixelSize: 12
        }
    }
}
