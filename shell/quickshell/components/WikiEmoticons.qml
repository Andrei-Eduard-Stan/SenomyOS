import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../config" as Config
Item {
    id:root
    required property var tools
    property bool editing:false
    property string editId:""
    property string revealName:""
    property bool removeReview:false
    readonly property var categories:["All categories"].concat([...new Set(tools.entries.map(e=>e.category))].sort())
    readonly property var filtered:tools.entries.filter(e=>(category.currentText==="All categories" || e.category===category.currentText) && (!favorites.active || e.favorite) && (!search.text.trim() || [e.name,e.category,e.text].join(" ").toLocaleLowerCase().includes(search.text.trim().toLocaleLowerCase())))
    readonly property int missingCount:tools.entries.filter(e=>(e.missing || []).length>0).length
    function edit(entry){editId=entry?entry.id:"";name.text=entry?entry.name:"";group.text=entry?entry.category:"Personal";value.text=entry?entry.text:"";removeReview=false;editing=true;Qt.callLater(()=>name.forceActiveFocus(Qt.TabFocusReason));}
    function back(){if(editing){editing=false;return true;}return false;}
    Connections {target:root.tools;function onCompletionChanged(){if(root.tools.lastSucceeded==="save"){search.text=root.revealName;category.currentIndex=0;favorites.active=false;}if(["save","remove"].includes(root.tools.lastSucceeded))root.editing=false;}}
    Column {
        id:filters;width:parent.width;spacing:10;visible:!root.editing
        Flow {
            width:parent.width;spacing:8
            QuietButton {objectName:"wiki-add-emoticon";text:"Add emoticon";glyph:"\uf067";enabled:!root.tools.busy;onClicked:root.edit(null)}
            QuietButton {id:favorites;objectName:"wiki-favorites";text:"Favorites";glyph:"\uf005";onClicked:active=!active}
        }
        InsightsWorkspaceSearch {id:search;objectName:"wiki-emoticon-search";width:parent.width;placeholderText:"Search names, categories or characters"}
        Row {width:parent.width;spacing:12
            ShellComboBox {id:category;objectName:"wiki-emoticon-category";width:Math.min(260,Math.max(120,parent.width-tally.implicitWidth-12));model:root.categories;Accessible.name:"Filter emoticon category"}
            Text {id:tally;height:category.height;verticalAlignment:Text.AlignVCenter;text:root.filtered.length+(root.filtered.length===1?" expression":" expressions");font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
        }
        Text {width:parent.width;text:root.missingCount?root.missingCount+" expressions use characters missing from your installed fonts. Copy still preserves the original text.":"Select text or use Copy. Saved entries stay on this device.";wrapMode:Text.Wrap;color:root.missingCount?Config.Theme.warning:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
    }
    GridView {
        id:grid;objectName:"wiki-emoticon-grid";visible:!root.editing;clip:true
        y:filters.height+14;width:parent.width;height:Math.max(1,parent.height-y)
        function revealFocus(){
            if(!visible || !root.Window.window)return;
            const item=root.Window.window.activeFocusItem;if(!item)return;
            let ancestor=item;while(ancestor && ancestor!==contentItem)ancestor=ancestor.parent;
            if(ancestor!==contentItem)return;
            const p=item.mapToItem(contentItem,0,0);
            if(p.y<contentY+8)contentY=Math.max(0,p.y-8);
            else if(p.y+item.height>contentY+height-8)contentY=Math.min(Math.max(0,contentHeight-height),p.y+item.height-height+8);
        }
        Connections {target:root.Window.window;function onActiveFocusItemChanged(){Qt.callLater(grid.revealFocus);}}
        onHeightChanged:Qt.callLater(revealFocus)
        cellWidth:Math.floor(width/Math.max(1,Math.floor(width/(260*Config.DirectoryStyle.textScale))))
        cellHeight:Math.round(196*Config.DirectoryStyle.textScale)
        model:root.filtered;keyNavigationEnabled:true;activeFocusOnTab:true
        Accessible.role:Accessible.List;Accessible.name:"Emoticon library. Arrow keys browse; Enter copies."
        highlight:Rectangle {color:"transparent";border.width:grid.activeFocus?1:0;border.color:Config.DirectoryStyle.ink}
        highlightMoveDuration:Config.Motion.duration(80)
        Keys.onReturnPressed:if(root.tools.clipboardAvailable && !root.tools.busy && currentIndex>=0 && currentIndex<root.filtered.length)root.tools.copy(root.filtered[currentIndex].text)
        Keys.onEnterPressed:if(root.tools.clipboardAvailable && !root.tools.busy && currentIndex>=0 && currentIndex<root.filtered.length)root.tools.copy(root.filtered[currentIndex].text)
        ScrollBar.vertical:ShellScrollBar {}
        delegate:Item {
            id:card;required property var modelData;required property int index
            width:grid.cellWidth-12;height:grid.cellHeight-12
            Rectangle {anchors.fill:parent;color:Qt.rgba(Config.DirectoryStyle.ink.r,Config.DirectoryStyle.ink.g,Config.DirectoryStyle.ink.b,.035);border.width:1;border.color:Config.DirectoryStyle.rule}
            Text {x:12;y:12;width:parent.width-68;text:card.modelData.name;textFormat:Text.PlainText;elide:Text.ElideRight;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;Accessible.name:text}
            QuietButton {x:parent.width-width-6;y:4;width:44;iconOnly:true;glyph:"\uf005";active:!!card.modelData.favorite;accessibleLabel:(active?"Unfavorite ":"Favorite ")+card.modelData.name;enabled:!root.tools.busy;onClicked:root.tools.favorite(card.modelData.id)}
            TextEdit {
                objectName:"emoticon-preview-"+card.modelData.id
                x:12;y:50;width:parent.width-24;height:Math.max(40,parent.height-108)
                text:card.modelData.text;textFormat:TextEdit.PlainText;readOnly:true;selectByMouse:true;activeFocusOnTab:false;clip:true;wrapMode:TextEdit.Wrap
                horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
                font.family:Config.DirectoryStyle.bodyFont
                font.pixelSize:Math.round(21*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink;selectionColor:Config.DirectoryStyle.selection;selectedTextColor:Config.DirectoryStyle.ink
                Accessible.name:card.modelData.name+". "+text
            }
            Row {x:8;anchors.bottom:parent.bottom;anchors.bottomMargin:6;spacing:6
                QuietButton {objectName:"emoticon-copy-"+card.modelData.id;width:Math.min(card.width-16,Math.max(100,implicitWidth));text:root.tools.copied===card.modelData.text && root.tools.message==="Copied to clipboard"?"Copied":"Copy";glyph:"\uf0c5";enabled:root.tools.clipboardAvailable && !root.tools.busy;accessibleLabel:"Copy "+card.modelData.name;onClicked:root.tools.copy(card.modelData.text)}
                QuietButton {objectName:"emoticon-edit-"+card.modelData.id;visible:card.modelData.custom;text:"Edit";enabled:!root.tools.busy;onClicked:root.edit(card.modelData)}
            }
        }
        Text {anchors.centerIn:parent;width:Math.max(1,parent.width-24);visible:grid.count===0;text:!root.tools.loaded?"Loading your library…":search.text || favorites.active || category.currentIndex>0?"No matches. Try another search or category.":"Your library is empty. Add an emoticon to start.";wrapMode:Text.Wrap;horizontalAlignment:Text.AlignHCenter;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
    }
    FocusScrollArea {
        visible:root.editing;anchors.fill:parent;contentHeight:editor.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
        Column {
            id:editor;width:Math.min(parent.width-12,700);spacing:12
            Text {text:root.editId?"Edit expression":"Add to your library";font.family:Config.DirectoryStyle.headingFont;font.pixelSize:20*Config.DirectoryStyle.textScale;color:Config.DirectoryStyle.ink}
            Text {text:"Name";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
            InsightsWorkspaceSearch {id:name;objectName:"emoticon-name";width:parent.width;maximumLength:80;placeholderText:"A name you can search"}
            Text {text:"Category";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
            InsightsWorkspaceSearch {id:group;objectName:"emoticon-group";width:parent.width;maximumLength:40;placeholderText:"Personal"}
            Text {text:"Expression";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.ink}
            TextArea {
                id:value;objectName:"emoticon-value";width:parent.width;height:Math.max(160,contentHeight+24)
                placeholderText:"Paste your emoticon, symbols or multiline text art";textFormat:TextEdit.PlainText;wrapMode:TextEdit.Wrap;selectByMouse:true
                font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:18*Config.DirectoryStyle.textScale
                color:Config.DirectoryStyle.ink;placeholderTextColor:Config.DirectoryStyle.dim;selectionColor:Config.DirectoryStyle.selection;selectedTextColor:Config.DirectoryStyle.ink
                background:Rectangle {color:Config.Theme.glassRaised;border.width:1;border.color:value.activeFocus?Config.DirectoryStyle.ink:Config.DirectoryStyle.rule}
                Accessible.name:"Emoticon text, up to 2000 characters"
            }
            Text {width:parent.width;text:value.length+" / 2000 characters · copied exactly as entered";wrapMode:Text.Wrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:value.length>2000?Config.Theme.danger:Config.DirectoryStyle.muted}
            Flow {width:parent.width;spacing:8
                QuietButton {objectName:"emoticon-save";text:"Save expression";enabled:!root.tools.busy && name.text.trim().length>0 && value.text.trim().length>0 && value.length<=2000;onClicked:{root.revealName=name.text;root.tools.save({id:root.editId,name:name.text,category:group.text || "Personal",text:value.text});}}
                QuietButton {text:"Cancel";enabled:!root.tools.busy;onClicked:root.editing=false}
                QuietButton {visible:!!root.editId;text:root.removeReview?"Keep expression":"Remove";enabled:!root.tools.busy;onClicked:root.removeReview=!root.removeReview}
                QuietButton {visible:root.removeReview;text:"Confirm remove";warning:true;enabled:!root.tools.busy;onClicked:root.tools.remove(root.editId)}
            }
        }
    }
}
