import QtQuick
import QtQuick.Controls
import ".." as UI
import "../../config" as Config

Column {
    id:root
    required property var notifications
    property string search:""
    property string filterMode:"all"
    property string expandedKey:""
    readonly property real preferredHeight:implicitHeight
    readonly property bool locked:notifications.clearActions.locked
    readonly property var filteredHistory:notifications.history.filter(record=>{
        const query=search.trim().toLocaleLowerCase();
        const matches=!query || [record.appName,record.desktopEntry,record.summary,record.body].some(v=>String(v || "").toLocaleLowerCase().includes(query));
        return matches && (filterMode!=="unread" || record.unread || key(record)===expandedKey);
    })
    signal focusSearchRequested()
    spacing:12
    onFilteredHistoryChanged:if(expandedKey && !filteredHistory.some(record=>key(record)===expandedKey)){expandedKey="";focusSearchRequested();}
    function key(record){return typeof notifications.recordKey==="function"?notifications.recordKey(record):String(record.id)+"@"+String(record.receivedAt || 0);}
    function isLive(record){return typeof notifications.isLive==="function"?notifications.isLive(record):false;}
    function timestamp(record){return record.receivedAt?Qt.formatDateTime(new Date(record.receivedAt),"ddd d MMM · HH:mm"):"Time unavailable";}
    function focusRecord(recordKey,reason){for(let i=0;i<records.count;i++){const row=records.itemAt(i);if(row && row.recordKey===recordKey){row.openControl.focusReason=reason===undefined?Qt.TabFocusReason:reason;row.openControl.forceActiveFocus(row.openControl.focusReason);return;}}}
    function focusSoon(recordKey,reason){Qt.callLater(function(){if(root.visible)root.focusRecord(recordKey,reason);});}
    function back(){if(!expandedKey)return false;const index=filteredHistory.findIndex(r=>key(r)===expandedKey);const next=filteredHistory[index+1] || filteredHistory[index-1];const old=expandedKey;expandedKey="";if(filteredHistory.some(r=>key(r)===old))focusSoon(old);else if(next)focusSoon(key(next));else focusSearchRequested();return true;}
    function open(record,reason){if(locked)return;if(expandedKey===key(record)){back();return;}expandedKey=key(record);notifications.markRead(record);focusSoon(key(record),reason);}
    function dismissRecord(record){if(locked)return;const index=filteredHistory.findIndex(r=>key(r)===key(record));const next=filteredHistory[index+1] || filteredHistory[index-1];notifications.dismiss(record);expandedKey="";if(next)focusSoon(key(next));else focusSearchRequested();}
    UI.StableRows {id:stableRecords;rows:root.filteredHistory;identity:record=>root.key(record)}
    move:UI.DirectoryMoveTransition {enabled:!Config.Motion.reduced}
    add:UI.DirectoryAddTransition {enabled:!Config.Motion.reduced}
    Repeater {
        id:records;model:stableRecords
        delegate:Column {
            id:recordView;required property var modelData;required property int index
            readonly property string recordKey:root.key(modelData)
            readonly property bool expanded:root.expandedKey===recordKey
            property alias openControl:openButton
            width:root.width;spacing:10
            UI.QuietButton {
                id:openButton;objectName:"notification-open-"+recordView.index;width:parent.width;height:summaryColumn.implicitHeight+2*Config.DirectoryStyle.controlVerticalInset
                leftPadding:Config.DirectoryStyle.controlInset;rightPadding:Config.DirectoryStyle.controlInset;topPadding:Config.DirectoryStyle.controlVerticalInset;bottomPadding:Config.DirectoryStyle.controlVerticalInset
                active:recordView.expanded;enabled:!root.locked
                accessibleLabel:(recordView.expanded?"Collapse ":"Open ")+recordView.modelData.summary+". "+recordView.modelData.appName+". "+root.timestamp(recordView.modelData)+(recordView.modelData.unread?". Unread":". Read")
                Accessible.description:"Open details and mark only this message read. Dismiss and application actions are separate."
                Accessible.expandable:true;Accessible.expanded:recordView.expanded
                ToolTip.visible:false
                Keys.onDownPressed:root.focusRecord(root.key(root.filteredHistory[Math.min(records.count-1,recordView.index+1)]))
                Keys.onUpPressed:root.focusRecord(root.key(root.filteredHistory[Math.max(0,recordView.index-1)]))
                onClicked:root.open(recordView.modelData,focusReason)
                contentItem:Column {
                    id:summaryColumn;spacing:5
                    Row {
                        width:parent.width;spacing:8
                        Text {width:Math.max(1,parent.width-state.width-8);text:recordView.modelData.appName || "Application";textFormat:Text.PlainText;elide:Text.ElideRight;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
                        Text {id:state;text:(recordView.modelData.unread?"Unread":"Read")+(recordView.modelData.urgency==="Critical"?" · Critical":"");font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:recordView.modelData.urgency==="Critical"?Config.Theme.danger:Config.DirectoryStyle.muted}
                    }
                    Text {width:parent.width;text:recordView.modelData.summary || "Notification";textFormat:Text.PlainText;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(16*Config.DirectoryStyle.textScale);font.weight:recordView.modelData.unread || recordView.expanded?Font.DemiBold:Font.Normal;color:Config.DirectoryStyle.ink}
                    Text {width:parent.width;visible:!recordView.expanded && !!recordView.modelData.body;text:recordView.modelData.body || "";textFormat:Text.PlainText;maximumLineCount:1;elide:Text.ElideRight;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
                    Text {text:root.timestamp(recordView.modelData);textFormat:Text.PlainText;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Math.round(12*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.muted}
                }
            }
            Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;visible:recordView.expanded && !!recordView.modelData.body;text:recordView.modelData.body || "";textFormat:Text.PlainText;wrapMode:Text.Wrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
            Text {x:Config.DirectoryStyle.controlInset;width:parent.width-2*x;visible:recordView.expanded;text:root.isLive(recordView.modelData)?"Application notification active":"Saved history · app actions unavailable";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
            Flow {
                id:actions;visible:recordView.expanded;width:parent.width;spacing:8
                readonly property bool stacked:width<340*Config.DirectoryStyle.textScale
                readonly property real cellWidth:stacked?width:(width-8)/2
                Repeater {
                    model:root.isLive(recordView.modelData)?recordView.modelData.actions || []:[]
                    delegate:UI.QuietButton {
                        id:actionChoice
                        required property var modelData
                        objectName:"notification-action-"+String(modelData.identifier || "");width:actions.cellWidth;height:Math.max(Config.DirectoryStyle.controlTarget,actionText.implicitHeight+2*Config.DirectoryStyle.controlVerticalInset)
                        text:modelData.text || modelData.identifier || "Action";wrapLabel:true;enabled:!root.locked && root.isLive(recordView.modelData);ToolTip.visible:false
                        leftPadding:Config.DirectoryStyle.controlInset;rightPadding:Config.DirectoryStyle.controlInset;topPadding:Config.DirectoryStyle.controlVerticalInset;bottomPadding:Config.DirectoryStyle.controlVerticalInset
                        contentItem:Text {id:actionText;text:actionChoice.text;textFormat:Text.PlainText;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.ink}
                        onClicked:root.notifications.invoke(recordView.modelData,modelData)
                    }
                }
                UI.QuietButton {objectName:"notification-dismiss-"+recordView.index;width:actions.cellWidth;text:"Dismiss";glyph:"\uf00d";enabled:!root.locked;accessibleLabel:"Dismiss "+recordView.modelData.summary+" and remove its saved history entry";ToolTip.visible:false;onClicked:root.dismissRecord(recordView.modelData)}
            }
        }
    }
    Text {
        objectName:"notification-inbox-empty";width:parent.width;visible:!root.filteredHistory.length;topPadding:16
        text:root.notifications.history.length?(root.search.trim()?"No matching saved notifications.":"No unread notifications."):root.notifications.serverEnabled?"No saved notifications.\nTransient alerts are not retained.":"Notification server unavailable.\nSaved history will appear here when available."
        textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted
    }
}
