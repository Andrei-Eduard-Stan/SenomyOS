import QtQuick
import QtQuick.Controls
import "../config" as Config
import "DirectoryModel.js" as Directory
FocusScope {
 id:root
 property var nodes:[]
 property string activeNode:""
 property string query:""
 property var expanded:({})
 readonly property var visibleNodes:Directory.flatten(nodes,expanded,query)
 readonly property var rows:visibleNodes
 readonly property int displacementMs:Math.round(Config.Motion.disclosureMs*2/3)
 StableRows {id:stableRows;rows:root.visibleNodes}
 signal activated(var node)
 signal queryEdited(string text)
 signal expansionRequested(var value)
 function toggle(node,keepFocus){const next=Object.assign({},expanded);next[node.id]=!next[node.id];expansionRequested(next);if(keepFocus)Qt.callLater(()=>focusRow(visibleNodes.findIndex(n=>n.id===node.id)));}
 function revealPath(){const next=Object.assign({},expanded);Directory.pathTo(nodes,activeNode).slice(0,-1).forEach(id=>next[id]=true);expansionRequested(next);}
 function focusSection(){revealPath();Qt.callLater(()=>{const index=visibleNodes.findIndex(n=>n.id===activeNode);focusRow(Math.max(0,index));});}
 function focusRow(index){if(index<0 || index>=visibleNodes.length)return;tree.currentIndex=index;tree.positionViewAtIndex(index,ListView.Contain);tree.forceLayout();const row=tree.itemAtIndex(index);if(row){row.focusReason=Qt.TabFocusReason;row.forceActiveFocus(Qt.TabFocusReason);}}
 function activate(node,keepFocus){if(node.route){if(node.branch&&!node.open)toggle(node);activated(node);}else if(node.branch)toggle(node,keepFocus);}
 function caption(node){const known={cpu:"CPU",gpu:"GPU",dns:"DNS",io:"Disk activity"};return known[node.view || node.id] || node.label.charAt(0)+node.label.slice(1).toLowerCase();}
 onActiveNodeChanged:revealPath()
 Component.onCompleted:revealPath()
 Row {id:searchRow;width:parent.width;spacing:4
  InsightsWorkspaceSearch {id:search;objectName:"performance-directory-search";width:parent.width-(clear.visible?clear.width+parent.spacing:0);placeholderText:"Search systems…";text:root.query;onTextEdited:root.queryEdited(text);Accessible.name:"Search Performance directory";
   background:Canvas {
    property color fillColor:Config.Theme.glassRaised
    property color lineColor:search.activeFocus?Config.DirectoryStyle.ink:Config.DirectoryStyle.rule
    onFillColorChanged:requestPaint();onLineColorChanged:requestPaint();onWidthChanged:requestPaint();onHeightChanged:requestPaint()
    onPaint:{const c=getContext("2d");c.reset();const i=Config.DirectoryStyle.controlFrameInset,k=Config.DirectoryStyle.controlFrameCorner,r=width-i,b=height-i;c.beginPath();c.moveTo(i+k,i);c.lineTo(r-k,i);c.lineTo(r,i+k);c.lineTo(r,b-k);c.lineTo(r-k,b);c.lineTo(i+k,b);c.lineTo(i,b-k);c.lineTo(i,i+k);c.closePath();c.fillStyle=fillColor;c.fill();c.strokeStyle=lineColor;c.lineWidth=search.activeFocus?1.5:1;c.stroke();}
   }
   Keys.onDownPressed:root.focusRow(0);Keys.onEscapePressed:event=>{if(root.query.length){root.queryEdited("");event.accepted=true;}else event.accepted=false;}}
  QuietButton {id:clear;objectName:"performance-directory-clear";visible:root.query.length>0;width:Config.DirectoryStyle.controlTarget;height:search.height;iconOnly:true;glyph:"\uf00d";accessibleLabel:"Clear directory search";onClicked:{root.queryEdited("");search.forceActiveFocus(Qt.TabFocusReason);}}
 }
 ListView {
  id:tree;objectName:"performance-directory-tree";anchors.top:searchRow.bottom;anchors.topMargin:12;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
  model:stableRows;clip:true;spacing:2;boundsBehavior:Flickable.StopAtBounds
  add:DirectoryAddTransition {enabled:!root.query.length && !Config.Motion.reduced}
  displaced:DirectoryMoveTransition {enabled:!root.query.length && !Config.Motion.reduced}
  ScrollBar.vertical:ShellScrollBar {}
  delegate:QuietButton {
   id:row;required property var modelData;required property int index
   objectName:"performance-directory-node-"+modelData.id
   width:tree.width-12;height:Math.max(Config.DirectoryStyle.controlTarget,caption.implicitHeight+16)
   text:root.caption(modelData);active:root.activeNode===modelData.id
   accessibleLabel:text+(active?", current destination":"")+(modelData.branch?modelData.open?", expanded":", collapsed":"")+(modelData.availability?", unavailable":"")
   Accessible.selected:active
   background.visible:visualFocus || down
   onClicked:root.activate(modelData,row.visualFocus)
   Keys.onDownPressed:root.focusRow(index+1)
   Keys.onUpPressed:root.focusRow(index-1)
   Keys.onRightPressed:{if(modelData.branch&&!modelData.open)root.toggle(modelData,true);else root.focusRow(index+1);}
   Keys.onLeftPressed:{if(modelData.branch&&modelData.open)root.toggle(modelData,true);else{for(let i=index-1;i>=0;i--)if(root.visibleNodes[i].depth<modelData.depth){root.focusRow(i);break;}}}
   Keys.onPressed:event=>{if(event.key===Qt.Key_Home){root.focusRow(0);event.accepted=true;}else if(event.key===Qt.Key_End){root.focusRow(root.visibleNodes.length-1);event.accepted=true;}}
   contentItem:Item {
    Rectangle {x:1;width:1;height:18;anchors.verticalCenter:parent.verticalCenter;visible:row.active;color:Config.DirectoryStyle.ink}
    Repeater {model:row.modelData.depth;Rectangle {required property int index;x:18+index*12;width:1;height:parent.height;color:Config.DirectoryStyle.rule}}
    QuietButton {id:disclosure;x:4+row.modelData.depth*12;width:40;height:parent.height;visible:row.modelData.branch;activeFocusOnTab:false;iconOnly:true;glyph:row.modelData.open?"\uf078":"\uf054";accessibleLabel:(row.modelData.open?"Collapse ":"Expand ")+row.text;background.visible:down || visualFocus;onClicked:root.toggle(row.modelData)}
    Text {x:row.modelData.depth*12+18;anchors.verticalCenter:parent.verticalCenter;visible:!row.modelData.branch;text:row.modelData.depth?"\uf15b":row.modelData.id==="overview"?"\uf201":row.modelData.id==="processes"?"\uf03a":"\uf3fd";font.family:"Font Awesome 7 Free Solid";font.weight:Font.Black;font.pixelSize:12;color:row.active?Config.DirectoryStyle.ink:Config.DirectoryStyle.dim;Accessible.ignored:true}
    Text {id:caption;x:row.modelData.depth*12+48;width:Math.max(1,parent.width-x-8);anchors.verticalCenter:parent.verticalCenter;text:row.text;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:row.active?Font.DemiBold:Font.Normal;color:row.active?Config.DirectoryStyle.ink:row.modelData.availability?Config.DirectoryStyle.dim:Config.DirectoryStyle.muted;Accessible.ignored:true}
   }
  }
  Text {anchors.centerIn:parent;width:parent.width-20;visible:tree.count===0;text:"No matching systems";wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}
 }
}
