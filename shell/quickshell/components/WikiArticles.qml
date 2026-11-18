import QtQuick
import QtQuick.Controls
import "../config" as Config
Item {
 id:root;required property var workspace
 property bool articleOpen:false
 readonly property bool split:width>=740*Config.DirectoryStyle.textScale
 readonly property var articles:workspace.data("wiki").articles || []
 readonly property var selected:articles.find(a=>a.id===workspace.selectedWikiId) || (split?articles[0] || null:null)
 readonly property var filtered:articles.filter(a=>!search.text.trim() || [a.title,a.category_title,a.summary].some(v=>String(v || "").toLocaleLowerCase().includes(search.text.trim().toLocaleLowerCase())))
 function back(){if(!split && articleOpen){articleOpen=false;return true;}return false;}
 Item {anchors.fill:parent
  Column {id:catalog;visible:root.split || !root.articleOpen;width:root.split?Math.floor((parent.width-24)*.32):parent.width;height:parent.height;spacing:10
   InsightsWorkspaceSearch {id:search;objectName:"insights-wiki-search";width:parent.width;placeholderText:"Find an article";text:root.workspace.readState("wiki","search","");onTextEdited:root.workspace.remember("wiki","search",text);Accessible.name:"Search local Wiki articles"}
   FocusDeviceList {id:list;width:parent.width;height:Math.max(1,parent.height-search.height-10);model:root.filtered;spacing:4;ScrollBar.vertical:ShellScrollBar {}
    delegate:InsightsWorkspaceChoice {required property var modelData;objectName:"insights-article-"+modelData.id;width:list.width-12;text:modelData.title;detail:modelData.category_title || "";active:!!root.selected && root.selected.id===modelData.id;onClicked:{root.workspace.selectedWikiId=modelData.id;root.articleOpen=true;article.contentY=0;if(!root.split)Qt.callLater(()=>backButton.forceActiveFocus());}}
    Text {width:parent.width;visible:root.filtered.length===0;text:root.articles.length?"No article matches your search.":"No local article catalog was returned. Refresh to retry.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
   }
  }
  FocusScrollArea {id:article;objectName:"insights-wiki-article";visible:root.split || root.articleOpen;x:root.split?catalog.width+24:0;width:parent.width-x;height:parent.height;contentHeight:document.implicitHeight;activeFocusOnTab:true;Accessible.role:Accessible.Pane;Accessible.name:"Local article. Use Page Up and Page Down to scroll.";ScrollBar.vertical:ShellScrollBar {}
   Keys.onPressed:event=>{const limit=Math.max(0,contentHeight-height);if(![Qt.Key_PageDown,Qt.Key_PageUp,Qt.Key_Home,Qt.Key_End].includes(event.key))return;contentY=event.key===Qt.Key_Home?0:event.key===Qt.Key_End?limit:Math.max(0,Math.min(limit,contentY+(event.key===Qt.Key_PageDown?1:-1)*height*.8));event.accepted=true;}
   Column {id:document;width:Math.min(article.width-16,72*Config.DirectoryStyle.bodySize*.55);spacing:16
    QuietButton {id:backButton;visible:!root.split;text:"Back to articles";glyph:"\uf104";onClicked:root.articleOpen=false}
    Text {visible:!root.selected;width:parent.width;text:"Choose an article to read it here.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
    Text {width:parent.width;text:root.selected?root.selected.title:"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Math.round(22*Config.DirectoryStyle.textScale);color:Config.DirectoryStyle.ink}
    Text {width:parent.width;text:root.selected?root.selected.summary || "":"";textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted;lineHeight:1.4}
    Repeater {model:root.selected?root.selected.blocks || []:[]
     TextEdit {required property var modelData;width:document.width;text:modelData.text || (modelData.items?modelData.items.map(i=>"• "+(i.text || i)).join("\n"):"");visible:text.length>0;readOnly:true;selectByMouse:true;activeFocusOnTab:false;textFormat:TextEdit.PlainText;wrapMode:TextEdit.Wrap;font.family:modelData.type==="heading"?Config.DirectoryStyle.headingFont:Config.DirectoryStyle.bodyFont;font.pixelSize:modelData.type==="heading"?Math.round(17*Config.DirectoryStyle.textScale):Config.DirectoryStyle.bodySize;color:modelData.type==="heading"?Config.DirectoryStyle.ink:Config.DirectoryStyle.muted;selectionColor:Config.DirectoryStyle.selection;selectedTextColor:Config.DirectoryStyle.ink;Accessible.name:text}
    }
   }
  }
 }
}
