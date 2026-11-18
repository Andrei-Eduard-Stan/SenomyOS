pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../config" as Config
import "../services/DisplayGeometry.js" as Geometry

Item {
    id:root
    required property var draft
    property bool editable:true
    property bool snapping:true
    property bool workspaceMode:false
    property var inventory:null
    property real factor:0.1
    property real panX:24
    property real panY:24
    property var guideX:null
    property var guideY:null
    property bool dragging:false
    property bool fitted:false
    property var cardModel:[]
    readonly property var canvasOutputs:draft.displays.map(d=>draft.outputs.find(o=>o.key===(d.key||d.name))||Geometry.fromDisplay(d))
    function reconcileCards(){if(dragging)return;const changed=cardModel.map(d=>d.key||d.name).join("|")!==draft.displays.map(d=>d.key||d.name).join("|");if(changed){cardModel=draft.displays.slice();Qt.callLater(fit);}}
    signal selected(string name)
    implicitHeight:300
    clip:true
    function fit(){if(dragging)return;fitted=true;const m=Geometry.fit(canvasOutputs,width,height,36);factor=m.factor;panX=m.panX;panY=m.panY;}
    function zoom(amount){if(dragging)return;const next=Math.max(0.008,Math.min(1.5,factor*amount)),cx=width/2,cy=height/2;panX=cx-(cx-panX)*next/factor;panY=cy-(cy-panY)*next/factor;factor=next;}
    onWidthChanged:if(!dragging)Qt.callLater(fit)
    onHeightChanged:if(!dragging)Qt.callLater(fit)
    Component.onCompleted:{reconcileCards();Qt.callLater(fit);}
    Connections {target:root.draft;function onDisplaysChanged(){root.reconcileCards();if(!root.fitted)Qt.callLater(root.fit);}}
    Rectangle {anchors.fill:parent;color:Config.Theme.glassRaised;border.width:1;border.color:Config.DirectoryStyle.rule}
    MouseArea {
        anchors.fill:parent;acceptedButtons:Qt.MiddleButton;property real oldX;property real oldY
        onPressed:mouse=>{oldX=mouse.x;oldY=mouse.y;}
        onPositionChanged:mouse=>{root.panX+=mouse.x-oldX;root.panY+=mouse.y-oldY;oldX=mouse.x;oldY=mouse.y;}
        onWheel:wheel=>{if(root.dragging){wheel.accepted=true;return;}if(wheel.modifiers&Qt.ControlModifier)root.zoom(wheel.angleDelta.y>0?1.15:1/1.15);else {root.panX+=wheel.angleDelta.x/2;root.panY+=wheel.angleDelta.y/2;}wheel.accepted=true;}
    }
    Repeater {
        model:root.cardModel
        delegate:Rectangle {
            id:card
            required property var modelData
            readonly property var output:root.draft.outputs.find(o=>o.key===(modelData.key||modelData.name))||Geometry.fromDisplay(modelData)
            visible:!!output&&output.enabled&&!output.mirrorOf
            readonly property var geometry:Geometry.rectangle(output)
            readonly property var display:root.draft.displays.find(d=>(d.key||d.name)===(modelData.key||modelData.name))||{}
            readonly property bool selected:root.draft.selectedKey===output.key
            objectName:"display-card-"+(card.display.name||modelData.name)
            x:root.panX+geometry.x*root.factor;y:root.panY+geometry.y*root.factor
            width:geometry.width*root.factor;height:geometry.height*root.factor
            color:selected?Config.Theme.glassFocus:Config.Theme.glassRaised
            border.width:selected||activeFocus?2:1;border.color:selected?Config.DirectoryStyle.ink:Config.DirectoryStyle.rule
            activeFocusOnTab:true
            Accessible.role:Accessible.Button
            Accessible.name:"Monitor "+display.number+", "+(display.friendlyName||modelData.name)+", "+modelData.name+", "+modelData.mode+", position "+modelData.x+", "+modelData.y
            function select(){root.draft.selectedKey=output.key;root.selected(card.display.name||output.name);forceActiveFocus();}
            function nudge(dx,dy,event){select();if(root.editable){const n=event.modifiers&Qt.ShiftModifier?10:1;root.draft.patch(output.key,{x:output.x+dx*n,y:output.y+dy*n});}}
            Keys.onReturnPressed:select()
            Keys.onSpacePressed:select()
            Keys.onLeftPressed:event=>nudge(-1,0,event)
            Keys.onRightPressed:event=>nudge(1,0,event)
            Keys.onUpPressed:event=>nudge(0,-1,event)
            Keys.onDownPressed:event=>nudge(0,1,event)
            Column {
                anchors.centerIn:parent;width:parent.width-8;spacing:3;visible:card.width>30&&card.height>25
                Text {width:parent.width;text:String(card.display.number||"")+" · "+(card.display.name||card.output.name);color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:12;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight;textFormat:Text.PlainText}
                Text {width:parent.width;visible:card.height>60;text:card.output.mode+" · "+card.output.scale+"×";color:Config.DirectoryStyle.muted;font.pixelSize:10;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight}
                Text {width:parent.width;visible:card.height>85;text:(card.display.friendlyName||"")+(root.draft.outputs.some(o=>o.mirrorOf===card.output.name)?" · mirrored outputs":"");color:Config.DirectoryStyle.muted;font.pixelSize:10;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight;textFormat:Text.PlainText}
            }
            Flow {
                id:workspaceChips
                z:3;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:4
                spacing:3;visible:root.workspaceMode&&root.inventory&&card.height>55
                Repeater {
                    model:root.inventory?root.inventory.workspaces.filter(w=>w.monitor===card.output.name&&w.id>0):[]
                    Rectangle {
                        id:workspaceChip
                        required property var modelData
                        property int workspaceId:modelData.id
                        width:38;height:30
                        color:((card.display.activeWorkspace||{}).id===workspaceId)?Config.Theme.glassFocus:Config.Theme.surfaceHover
                        border.width:1;border.color:Config.DirectoryStyle.rule
                        Drag.active:workspacePointer.drag.active;Drag.source:workspaceChip;Drag.keys:["senomy-workspace"]
                        Drag.hotSpot.x:width/2;Drag.hotSpot.y:height/2
                        Text {anchors.centerIn:parent;text:root.inventory.workspaceLabel(workspaceChip.workspaceId)+(workspaceChip.modelData.windows?" •":"");color:Config.DirectoryStyle.ink;font.pixelSize:11}
                        DropArea {anchors.fill:parent;keys:["senomy-window"];onDropped:drop=>{const w=drop.source.windowData;root.inventory.requestWorkspace({action:"window-move",id:workspaceChip.workspaceId,address:w.address,pid:w.pid,sourceWorkspace:w.workspace.id},"Move this window to workspace "+workspaceChip.workspaceId+" without following it.");drop.acceptProposedAction();}}
                        MouseArea {id:workspacePointer;anchors.fill:parent;drag.target:workspaceChip;property real originalX;property real originalY;onPressed:{originalX=workspaceChip.x;originalY=workspaceChip.y;}onClicked:{card.select();root.inventory.selectedWorkspace=workspaceChip.workspaceId;root.inventory.requestWorkspace({action:"switch",id:workspaceChip.workspaceId},"Switch to workspace "+workspaceChip.workspaceId+" on "+card.output.name+".");}onReleased:{workspaceChip.Drag.drop();workspaceChip.x=originalX;workspaceChip.y=originalY;}}
                    }
                }
            }
            DropArea {anchors.fill:parent;keys:["senomy-workspace"];onDropped:drop=>{root.inventory.requestWorkspace({action:"move",id:drop.source.workspaceId,monitor:card.output.name},"Move this entire workspace and its windows to "+card.output.name+". Native identity is retained; native focus and layout can change.");drop.acceptProposedAction();}}
            MouseArea {
                id:pointer;anchors.fill:parent;hoverEnabled:true;preventStealing:true
                acceptedButtons:Qt.LeftButton
                property point startPointer
                property point startOutput
                property bool moved:false
                cursorShape:root.editable?Qt.OpenHandCursor:Qt.PointingHandCursor
                onPressed:mouse=>{
                    // Capture in canvas coordinates, never in the moving card's space.
                    startPointer=mapToItem(root,mouse.x,mouse.y);startOutput=Qt.point(card.output.x,card.output.y);
                    moved=false;card.select();root.draft.checkpoint();
                }
                onPositionChanged:mouse=>{
                    if(!pressed||!root.editable)return;
                    const point=mapToItem(root,mouse.x,mouse.y),dx=point.x-startPointer.x,dy=point.y-startPointer.y;
                    if(!moved&&Math.sqrt(dx*dx+dy*dy)<6)return;
                    moved=true;root.dragging=true;
                    let x=startOutput.x+dx/root.factor,y=startOutput.y+dy/root.factor;
                    if(root.snapping&&!(mouse.modifiers&Qt.AltModifier)){
                        const snapped=Geometry.snap(card.output,root.canvasOutputs,x,y,8/root.factor);
                        x=snapped.x;y=snapped.y;root.guideX=snapped.guideX;root.guideY=snapped.guideY;
                    }else{root.guideX=null;root.guideY=null;}
                    root.draft.patch(card.output.key,{x:Math.round(x),y:Math.round(y)},false);
                }
                onReleased:{root.dragging=false;root.guideX=null;root.guideY=null;Qt.callLater(root.reconcileCards);}
                onCanceled:{root.dragging=false;root.guideX=null;root.guideY=null;Qt.callLater(root.reconcileCards);}
            }
        }
    }
    Rectangle {visible:root.guideX!==null;x:root.panX+Number(root.guideX)*root.factor;width:1;height:parent.height;color:Config.DirectoryStyle.ink;opacity:0.65}
    Rectangle {visible:root.guideY!==null;y:root.panY+Number(root.guideY)*root.factor;height:1;width:parent.width;color:Config.DirectoryStyle.ink;opacity:0.65}
    Text {anchors.left:parent.left;anchors.top:parent.top;anchors.margins:8;width:parent.width-16;elide:Text.ElideRight;text:"LOGICAL DESKTOP · click to select · Alt: free drag · middle-drag: pan";color:Config.DirectoryStyle.muted;font.pixelSize:10}
}
