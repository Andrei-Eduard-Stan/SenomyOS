import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../config" as Config
Item {
    id:root
    required property var tools
    readonly property var groups:["All groups"].concat([...new Set(tools.shortcutRows.map(e=>e.group))].sort())
    readonly property var filtered:tools.shortcutRows.filter(e=>(group.currentText==="All groups" || e.group===group.currentText) && (!search.text.trim() || [e.chord,e.action,e.group,e.submap,e.dispatcher,(e.flags || []).join(" ")].join(" ").toLocaleLowerCase().includes(search.text.trim().toLocaleLowerCase())))
    function back(){return false;}
    Column {
        id:header;width:parent.width;spacing:10
        Text {width:parent.width;text:root.tools.shortcuts.available?root.tools.shortcutRows.length+" active bindings · synced "+Qt.formatDateTime(new Date(root.tools.shortcuts.observedAt*1000),"HH:mm:ss"):root.tools.shortcuts.message || "Hyprland is unavailable.";textFormat:Text.PlainText;wrapMode:Text.Wrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:root.tools.shortcuts.available?Config.DirectoryStyle.ink:Config.Theme.warning}
        Text {width:parent.width;text:"Updates while open. Lua action names follow the current config.";wrapMode:Text.Wrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
        InsightsWorkspaceSearch {id:search;objectName:"wiki-shortcut-search";width:parent.width;placeholderText:"Find a key, action or group"}
        Flow {width:parent.width;spacing:8
            ShellComboBox {id:group;objectName:"wiki-shortcut-group";width:Math.min(240,parent.width);model:root.groups;Accessible.name:"Filter shortcut group"}
            QuietButton {objectName:"wiki-copy-shortcuts";text:root.tools.message==="Copied to clipboard"?"Copied":"Copy list";enabled:root.filtered.length>0 && root.tools.clipboardAvailable && !root.tools.busy;onClicked:root.tools.copy(root.filtered.map(e=>e.chord+" — "+e.action+(e.submap!=="Default"?" ["+e.submap+"]":"")).join("\n"))}
        }
    }
    FocusDeviceList {
        id:list;objectName:"wiki-shortcut-list";y:header.height+14;width:parent.width;height:Math.max(1,parent.height-y)
        model:root.filtered;spacing:0;clip:true;activeFocusOnTab:true
        Accessible.role:Accessible.Pane;Accessible.name:"Hyprland shortcuts. Use Page Up and Page Down to scroll."
        Keys.onPressed:event=>{const limit=Math.max(0,contentHeight-height);if(![Qt.Key_PageDown,Qt.Key_PageUp,Qt.Key_Home,Qt.Key_End].includes(event.key))return;contentY=event.key===Qt.Key_Home?0:event.key===Qt.Key_End?limit:Math.max(0,Math.min(limit,contentY+(event.key===Qt.Key_PageDown?1:-1)*height*.8));event.accepted=true;}
        ScrollBar.vertical:ShellScrollBar {}
        delegate:Column {
            id:row;required property var modelData;required property int index
            width:list.width-12;spacing:10
            Text {visible:row.index===0 || root.filtered[row.index-1].group!==row.modelData.group;topPadding:row.index===0?8:22;bottomPadding:6;text:row.modelData.group;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:16*Config.DirectoryStyle.textScale;color:Config.DirectoryStyle.ink}
            GridLayout {width:parent.width;columns:width<540*Config.DirectoryStyle.textScale?1:2;columnSpacing:24;rowSpacing:8
                TextEdit {Layout.preferredWidth:parent.columns===1?parent.width:Math.min(270,parent.width*.42);Layout.maximumWidth:parent.width;readOnly:true;selectByMouse:true;activeFocusOnTab:false;wrapMode:TextEdit.Wrap;text:row.modelData.chord;textFormat:TextEdit.PlainText;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.bodySize;Accessible.name:"Keys: "+text}
                Column {Layout.fillWidth:true;Layout.minimumWidth:0;spacing:5
                    Text {width:parent.width;text:row.modelData.action;textFormat:Text.PlainText;wrapMode:Text.Wrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
                    Text {width:parent.width;visible:!!text;text:(row.modelData.submap!=="Default"?"Submap: "+row.modelData.submap+" · ":"")+(row.modelData.flags || []).join(" · ");textFormat:Text.PlainText;wrapMode:Text.Wrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                }
            }
            Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
            Item {width:1;height:3}
        }
        Text {anchors.centerIn:parent;width:Math.max(1,parent.width-24);visible:root.filtered.length===0;text:root.tools.shortcuts.available?"No shortcuts match your search.":"Refresh to read active bindings from this session.";wrapMode:Text.Wrap;horizontalAlignment:Text.AlignHCenter;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
    }
}
