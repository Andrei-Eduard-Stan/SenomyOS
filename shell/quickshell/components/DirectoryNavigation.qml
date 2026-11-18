import QtQuick
import "../config" as Config
import QtQuick.Controls
import "DirectoryModel.js" as Directory
Column {
    id: root
    property var nodes: []
    readonly property bool destinationList:nodes.every(node=>!node.children)
    property string activeNode: ""
    property var expanded: ({})
    property var telemetry: ({})
    property bool touchMode: false
    property bool restoreFocus:false
    property alias query: search.text
    readonly property var rows:visibleNodes
    signal activated(var node)
    readonly property var visibleNodes: Directory.flatten(nodes, expanded, search.text)
    spacing: 12
    function focusSection(){
        const path=Directory.pathTo(nodes,activeNode),next=Object.assign({},expanded);
        path.slice(0,-1).forEach(id=>next[id]=true);expanded=next;
        Qt.callLater(()=>{const i=visibleNodes.findIndex(node=>node.id===activeNode);if(i>=0)focusRow(i,Qt.OtherFocusReason);});
    }
    onActiveNodeChanged:if(restoreFocus && !search.activeFocus)focusSection()
    onRestoreFocusChanged:if(restoreFocus)focusSection()
    Component.onCompleted:if(restoreFocus)focusSection()
    function itemAtIndex(index){return tree.itemAtIndex(index);}
    function toggle(node) { const next=Object.assign({},expanded); next[node.id]=!next[node.id]; expanded=next; }
    function activate(node) { if(node.route) { if(node.branch && !node.open)toggle(node); activated(node); } else if(node.branch) toggle(node); }
    function focusRow(index,reason) {
        if(index<0 || index>=visibleNodes.length) return;
        tree.currentIndex=index; tree.positionViewAtIndex(index,ListView.Contain);
        Qt.callLater(()=>{const item=tree.itemAtIndex(index);if(item)item.focusForReason(reason===undefined?Qt.TabFocusReason:reason);});
    }
    TextField {
        id: search; objectName: "directory-search"
        width: parent.width; height: root.touchMode ? 48 : 34
        placeholderText: "Search systems…"
        color: Config.DirectoryStyle.ink; placeholderTextColor: Config.DirectoryStyle.dim
        font.family: Config.DirectoryStyle.bodyFont; font.pixelSize: Config.DirectoryStyle.bodySize
        selectByMouse: true
        Accessible.name: "Search system directory"
        background: Rectangle { radius: 4; color: "transparent"; border.width: 1; border.color: search.activeFocus ? Config.DirectoryStyle.ink : Config.DirectoryStyle.muted }
        Keys.onDownPressed: root.focusRow(0)
        Keys.onEscapePressed: event=>{ if(text.length){clear();event.accepted=true;}else event.accepted=false; }
    }
 StableRows {id:stableRows;rows:root.visibleNodes}
    ListView {
        id: tree; objectName: "directory-tree"
        width: parent.width; height: Math.max(0,root.height-search.height-root.spacing)
        model: stableRows; clip: true; spacing: 1
        boundsBehavior: Flickable.StopAtBounds
  add:DirectoryAddTransition {enabled:!root.query.length && !Config.Motion.reduced}
  displaced:DirectoryMoveTransition {enabled:!root.query.length && !Config.Motion.reduced}
        delegate: Control {
            id: row
            padding:0
            background:null
            function focusForReason(reason){focusReason=reason;forceActiveFocus(reason);}
            required property var modelData
            required property int index
            objectName: "directory-node-"+modelData.id
            width: tree.width; height: root.touchMode ? 48 : modelData.depth>1 ? 34 : 38
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.description:root.activeNode===modelData.id?"Current destination":"Open destination"
            Accessible.onPressAction:root.activate(modelData)
            Accessible.name: modelData.label + (modelData.availability ? ", " + modelData.availability : "") + (modelData.branch ? modelData.open ? ", expanded" : ", collapsed" : "")
            Keys.onDownPressed: root.focusRow(index+1)
            Keys.onUpPressed: root.focusRow(index-1)
            Keys.onPressed:event=>{if(event.key===Qt.Key_Home){root.focusRow(0);event.accepted=true;}else if(event.key===Qt.Key_End){root.focusRow(root.visibleNodes.length-1);event.accepted=true;}}
            Keys.onReturnPressed: root.activate(modelData)
            Keys.onSpacePressed: root.activate(modelData)
            Keys.onRightPressed: { if(modelData.branch && !modelData.open)root.toggle(modelData);else root.focusRow(index+1); }
            Keys.onLeftPressed: {
                if(modelData.branch && modelData.open)root.toggle(modelData);
                else { for(let i=index-1;i>=0;i--)if(root.visibleNodes[i].depth<modelData.depth){root.focusRow(i);break;} }
            }
            Rectangle {
                anchors.fill: parent; radius: 2
                color: "transparent"
                border.width: 0
                border.color: row.activeFocus ? Config.DirectoryStyle.ink : Config.DirectoryStyle.rule
            }
            HoverHandler { id: rowHover }
            NavigationSelection {focusTarget:row;pointerTarget:hover;current:root.activeNode===row.modelData.id;anchors.fill:parent;hovered:row.enabled && rowHover.hovered}
            MouseArea { id:hover; anchors.fill:parent; hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{row.focusForReason(Qt.MouseFocusReason);root.activate(row.modelData);} }
            Text {
                x: Config.DirectoryStyle.controlInset+row.modelData.depth*14; anchors.verticalCenter: parent.verticalCenter
                visible:!root.destinationList
                text: row.modelData.branch ? row.modelData.open ? "▾" : "▸" : "·"
                font.family: Config.DirectoryStyle.dataFont; font.pixelSize: Config.DirectoryStyle.bodySize; color: Config.DirectoryStyle.muted
                MouseArea { anchors.fill:parent;anchors.margins:-5;onClicked:if(row.modelData.branch)root.toggle(row.modelData) }
            }
            Text {
                id:routeLabel
                x: root.destinationList?Config.DirectoryStyle.controlInset:Config.DirectoryStyle.controlInset+20+row.modelData.depth*14; anchors.verticalCenter:parent.verticalCenter
                width: Math.max(0,parent.width-x-(value.visible?value.width+Config.DirectoryStyle.controlGap:Config.DirectoryStyle.controlInset))
                text:root.destinationList?row.modelData.label.charAt(0)+row.modelData.label.slice(1).toLowerCase():row.modelData.label; font.weight: root.activeNode===row.modelData.id ? Font.DemiBold : Font.Normal; font.family: Config.DirectoryStyle.bodyFont
                font.pixelSize: Config.DirectoryStyle.bodySize
                color: row.modelData.availability ? Config.DirectoryStyle.dim : root.activeNode===row.modelData.id ? Config.DirectoryStyle.ink : Config.DirectoryStyle.muted
                elide: Text.ElideRight
            }
            Text { id:value;anchors.right:parent.right;anchors.rightMargin:Config.DirectoryStyle.controlInset;anchors.verticalCenter:parent.verticalCenter;text:row.modelData.badge || (row.modelData.availability?"N/A":root.telemetry[row.modelData.id] || "");visible:text.length>0 && root.width>=180;color:Config.DirectoryStyle.dim;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12 }
        }
        Text { anchors.centerIn:parent;visible:tree.count===0;text:"No matching objects";color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 12 }
    }
}
