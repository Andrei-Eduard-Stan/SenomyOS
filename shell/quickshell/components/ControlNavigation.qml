import QtQuick
import QtQuick.Controls
import "../config" as Config
import "ControlDirectory.js" as Directory
FocusScope {
 id:root
 property var nodes:[]
 property bool hierarchical:true
 property string activeNode:"overview"
 property bool restoreFocus:false
 property var expanded:({})
 property var manualExpanded:({})
 property alias query:search.text
 property string sharedQuery:""
 onSharedQueryChanged:if(search.text!==sharedQuery)search.text=sharedQuery
 readonly property var rows:visibleNodes
 property alias currentIndex:tree.currentIndex
 readonly property bool searching:query.trim().length>0
 readonly property string selectedNode:!hierarchical&&!searching?activeNode.split("/")[0]:activeNode
 readonly property var visibleNodes:Directory.rows(nodes,expanded,query).filter(n=>searching || hierarchical || n.depth===0)
 readonly property bool touchMode:Config.DirectoryStyle.touchMode
 signal activated(var node)
 function displayLabel(value){const acronyms={"wi-fi":"Wi-Fi",vpn:"VPN",usb:"USB",cpu:"CPU",gpu:"GPU",dns:"DNS",dhcp:"DHCP",bios:"BIOS",uefi:"UEFI",hdmi:"HDMI",bluetooth:"Bluetooth"};const text=String(value).toLowerCase().replace(/\b(wi-fi|vpn|usb|cpu|gpu|dns|dhcp|bios|uefi|hdmi|bluetooth)\b/g,w=>acronyms[w]);return text.charAt(0).toUpperCase()+text.slice(1);}
 function itemAtIndex(index){return tree.itemAtIndex(index);}
 function focusSearch(){search.forceActiveFocus(Qt.TabFocusReason);search.selectAll();}
 function focusRow(index){if(index<0 || index>=visibleNodes.length)return;tree.currentIndex=index;tree.positionViewAtIndex(index,ListView.Contain);tree.forceLayout();Qt.callLater(()=>{const row=tree.itemAtIndex(index);if(row)row.focusForReason(Qt.TabFocusReason);});}
 function focusSection(){const next=Object.assign({},manualExpanded);Directory.parentIds(nodes,activeNode).forEach(id=>next[id]=true);const current=Directory.resolve(nodes,activeNode);if(current&&current.children)next[activeNode]=true;expanded=next;Qt.callLater(()=>{const index=visibleNodes.findIndex(n=>n.id===selectedNode);if(index>=0){tree.currentIndex=index;tree.positionViewAtIndex(index,ListView.Contain);}});}
 function toggle(node,keepFocus){const next=Object.assign({},expanded);next[node.id]=!next[node.id];expanded=next;manualExpanded=Object.assign({},manualExpanded,{[node.id]:next[node.id]});if(keepFocus)Qt.callLater(()=>focusRow(visibleNodes.findIndex(n=>n.id===node.id)));}
 function activate(node,keepFocus){if(hierarchical&&!searching&&node.branch&&!node.open)toggle(node,keepFocus);activated(node);}
 onActiveNodeChanged:focusSection()
 onHierarchicalChanged:focusSection()
 onRestoreFocusChanged:if(restoreFocus)focusSection()
 Component.onCompleted:{search.text=sharedQuery;focusSection();}
 Row {id:searchRow;width:parent.width;spacing:4
  ControlWorkspaceSearch {id:search;objectName:"control-search";width:parent.width-(clear.visible?clear.width+parent.spacing:0);placeholderText:"Search settings…";Accessible.name:"Search all settings and devices";onTextEdited:tree.currentIndex=-1;Keys.onDownPressed:root.focusRow(0);Keys.onEscapePressed:event=>{if(text.length){search.clear();event.accepted=true;}else event.accepted=false;};Keys.onReturnPressed:if(root.visibleNodes.length)root.activate(root.visibleNodes[0])}
  QuietButton {id:clear;objectName:"control-search-clear";visible:search.text.length>0;width:Config.DirectoryStyle.controlTarget;height:search.height;iconOnly:true;glyph:"\uf00d";accessibleLabel:"Clear settings search";onClicked:{search.clear();search.forceActiveFocus(Qt.TabFocusReason);}}
 }
 Text {id:count;anchors.top:searchRow.bottom;anchors.topMargin:8;visible:root.searching;width:parent.width;text:root.visibleNodes.length+" matching destinations";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.muted}
 StableRows {id:stableRows;rows:root.visibleNodes}
 ListView {
  id:tree;objectName:"control-directory";anchors.top:root.searching?count.bottom:searchRow.bottom;anchors.topMargin:12;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
  model:stableRows;clip:true;spacing:2;boundsBehavior:Flickable.StopAtBounds
  ScrollBar.vertical:ShellScrollBar {}
  add:DirectoryAddTransition {enabled:!root.query.length && !Config.Motion.reduced}
  displaced:DirectoryMoveTransition {enabled:!root.query.length && !Config.Motion.reduced}
  delegate:QuietButton {
   id:row;required property var modelData;required property int index
   function focusForReason(reason){focusReason=reason;forceActiveFocus(reason);}
   objectName:"control-node-"+modelData.id
   width:tree.width-12;height:Math.max(Config.DirectoryStyle.controlTarget,labels.implicitHeight+16)
   text:root.displayLabel(modelData.label);active:root.selectedNode===modelData.id
   accessibleLabel:root.displayLabel(modelData.path || modelData.label)+(active?", current destination":"")+(modelData.availability?", "+modelData.availability:"")+(modelData.branch?modelData.open?", expanded":", collapsed":"")
   Accessible.selected:active;background.visible:visualFocus || down
   onClicked:root.activate(modelData,row.visualFocus)
   Keys.onDownPressed:root.focusRow(index+1)
   Keys.onUpPressed:if(index===0)root.focusSearch();else root.focusRow(index-1)
   Keys.onRightPressed:if(modelData.branch&&!modelData.open)root.toggle(modelData,true);else root.focusRow(index+1)
   Keys.onLeftPressed:{if(modelData.branch&&modelData.open)root.toggle(modelData,true);else{const parents=Directory.parentIds(root.nodes,modelData.id);if(parents.length)root.focusRow(root.visibleNodes.findIndex(n=>n.id===parents[parents.length-1]));}}
   Keys.onPressed:event=>{if(event.key===Qt.Key_Home){root.focusRow(0);event.accepted=true;}else if(event.key===Qt.Key_End){root.focusRow(root.visibleNodes.length-1);event.accepted=true;}}
   contentItem:Item {
    Rectangle {x:1;width:1;height:18;anchors.verticalCenter:parent.verticalCenter;visible:row.active;color:Config.DirectoryStyle.ink}
    Repeater {model:root.searching?0:row.modelData.depth;Rectangle {required property int index;x:18+index*12;width:1;height:parent.height;color:Config.DirectoryStyle.rule}}
    QuietButton {x:4+row.modelData.depth*12;width:40;height:parent.height;visible:row.modelData.branch&&!root.searching;activeFocusOnTab:false;iconOnly:true;glyph:row.modelData.open?"\uf078":"\uf054";accessibleLabel:(row.modelData.open?"Collapse ":"Expand ")+row.text;background.visible:down || visualFocus;onClicked:root.toggle(row.modelData)}
    Text {visible:!row.modelData.branch&&!root.searching;x:18+row.modelData.depth*12;anchors.verticalCenter:parent.verticalCenter;text:row.modelData.depth?"\uf15b":"\uf1de";font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:12;color:row.active?Config.DirectoryStyle.ink:Config.DirectoryStyle.dim;Accessible.ignored:true}
    Column {id:labels;x:root.searching?20:48+row.modelData.depth*12;width:Math.max(1,parent.width-x-8);anchors.verticalCenter:parent.verticalCenter;spacing:4
     Text {width:parent.width;text:row.text;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:row.active?Font.DemiBold:Font.Normal;color:row.active?Config.DirectoryStyle.ink:Config.DirectoryStyle.muted;Accessible.ignored:true}
     Text {visible:root.searching;width:parent.width;text:root.displayLabel(row.modelData.path || "")+(row.modelData.availability?" · "+row.modelData.availability:"");textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:Config.DirectoryStyle.dim;Accessible.ignored:true}
    }
   }
  }
  Text {visible:tree.count===0;anchors.centerIn:parent;width:parent.width-20;text:"No matching controls.\nTry a setting or device name.";horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
 }
}
