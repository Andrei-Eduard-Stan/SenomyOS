pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../config" as Config

Column {
    id:root
    required property var inventory
    signal review(var argument,string text)
    signal monitorSelected(string name)
    readonly property int selectedWorkspace:inventory.selectedWorkspace||0
    property string label:""
    readonly property var policy:inventory.policy||{}
    readonly property var workspaces:inventory.workspaces||[]
    readonly property var displays:inventory.displays||[]
    readonly property var windows:inventory.windows||[]
    function order(id){return inventory.workspaceOrder?inventory.workspaceOrder(id):id;}
    function labelFor(id){return inventory.workspaceLabel?inventory.workspaceLabel(id):String(id);}
    readonly property var localWorkspaces:root.workspaces.filter(w=>w.monitor===monitor.currentText&&w.id>0).sort((a,b)=>root.order(a.id)-root.order(b.id))
    spacing:8
    Text {width:parent.width;text:"Workspace sets use globally unique native IDs. Independent mode repeats local labels without sharing window groups. Reordering changes the display order only.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.pixelSize:12}
    Flow {
        width:parent.width;spacing:8
        DashboardButton {text:"GLOBAL NAMESPACE";active:root.policy.workspaceMode==="global";onClicked:root.review({action:"mode",mode:"global"},"Show global workspace IDs. Existing windows and native IDs are preserved; Super+1–0 / Super+Shift+1–0 are replaced with managed workspace shortcuts and follow this model.")}
        DashboardButton {text:"INDEPENDENT SETS";active:root.policy.workspaceMode==="independent";onClicked:root.review({action:"mode",mode:"independent"},"Use separate local workspace labels on each display. Existing native IDs and windows are preserved. Each monitor keeps its own active workspace. Super+1–0 and Super+Shift+1–0 become monitor-local managed shortcuts.")}
    }
    ShellComboBox {id:monitor;width:parent.width;model:root.displays.filter(m=>!m.disabled&&(!m.mirrorOf||m.mirrorOf==="none")).map(m=>m.name);Accessible.name:"Workspace monitor";currentIndex:root.displays.filter(m=>!m.disabled&&(!m.mirrorOf||m.mirrorOf==="none")).findIndex(m=>root.inventory.draft&&m.key===root.inventory.draft.selectedKey);onActivated:index=>root.monitorSelected(currentText)}
    Flow {
        width:parent.width;spacing:8
        DashboardButton {width:250;text:"MAIN WORKSPACE DISPLAY";onClicked:root.review({action:"default-home",monitor:monitor.currentText},"Use this display for the normal dynamic workspace module. No unused workspaces are created or moved.")}
        DashboardButton {width:200;text:"RESTORE HOME GROUPS";onClicked:root.review({action:"restore-home"},"Return saved workspace groups to their connected home displays. Disconnected homes stay on a surviving screen. Review before using this after manually reorganizing windows.")}
        DashboardButton {text:"CREATE WORKSPACE";onClicked:root.review({action:"create",monitor:monitor.currentText},"Create a dynamic workspace on "+monitor.currentText+" and focus it.")}
        DashboardButton {text:(root.inventory.railVisible?root.inventory.railVisible(monitor.currentText):true)?"HIDE THIS RAIL":"SHOW THIS RAIL";onClicked:root.review({action:"rail",monitor:monitor.currentText,visible:!(root.inventory.railVisible?root.inventory.railVisible(monitor.currentText):true)},"Change Rail visibility on "+monitor.currentText+". Keyboard and Control Centre access remain available.")}
    }
    DashboardButton {width:parent.width;text:root.policy.externalWorkspaceIndicators?"EXTERNAL INDICATORS: ALWAYS VISIBLE":"EXTERNAL INDICATORS: WHEN USED";onClicked:root.review({action:"external-indicators",visible:!root.policy.externalWorkspaceIndicators},"Change presentation only. No workspaces are created or removed.")}
    Text {width:parent.width;text:"Empty dynamic workspaces disappear when the compositor destroys them. Each external display’s initial empty workspace stays real but quiet until used; pinned or occupied groups are always represented.";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.pixelSize:12}
    Repeater {
        model:root.localWorkspaces
        Column {
            id:row
            required property var modelData
            required property int index
            width:root.width;spacing:6
            readonly property var record:(root.policy.workspaces||{})[String(modelData.id)]||{}
            Flow {
                width:parent.width;spacing:6
                DashboardButton {width:180;text:"WORKSPACE "+root.labelFor(row.modelData.id);detail:row.modelData.windows+" windows · native "+row.modelData.id+(row.record.persistent?" · pinned":row.modelData.indicatorVisible===false?" · initial empty, quiet Rail":" · dynamic");active:root.selectedWorkspace===row.modelData.id;onClicked:root.inventory.selectedWorkspace=row.modelData.id}
                DashboardButton {width:100;text:"SWITCH";onClicked:root.review({action:"switch",id:row.modelData.id},"Focus workspace "+root.labelFor(row.modelData.id)+" on "+row.modelData.monitor+".")}
                DashboardButton {width:160;text:row.record.persistent?"UNPIN EMPTY":"PERSIST EMPTY";onClicked:root.review({action:"persistent",id:row.modelData.id,value:!row.record.persistent},"Change whether workspace "+row.modelData.id+" stays alive when empty.")}
                DashboardButton {width:110;text:"ORDER ↑";enabled:row.index>0;onClicked:{const ids=root.localWorkspaces.map(w=>w.id),old=ids[row.index-1];ids[row.index-1]=ids[row.index];ids[row.index]=old;root.review({action:"reorder",ids:ids},"Reorder indicators only; native IDs and windows do not move.");}}
                DashboardButton {width:110;text:"REMOVE SLOT";enabled:row.modelData.windows===0;onClicked:root.review({action:"remove",id:row.modelData.id},"Unpin and forget the empty saved slot. An active native workspace remains until you leave it; no applications close.")}
            }
            Flow {
                width:parent.width;spacing:6
                Repeater {model:root.displays.filter(m=>!m.disabled&&m.name!==row.modelData.monitor&&(!m.mirrorOf||m.mirrorOf==="none"));DashboardButton {required property var modelData;width:140;text:"MOVE TO "+modelData.name;onClicked:root.review({action:"move",id:row.modelData.id,monitor:modelData.name},"Move the entire workspace "+row.modelData.id+" and all its windows to "+modelData.name+". Native ID is retained; native focus and layout may change.")}}
            }
            Repeater {
                model:root.windows.filter(w=>(w.workspace||{}).id===row.modelData.id)
                Row {
                    id:windowRow
                    required property var modelData
                    width:root.width;spacing:8
                    Rectangle {
                        id:windowChip;width:Math.max(100,parent.width-180);height:44;color:Config.Theme.glassRaised
                        property var windowData:windowRow.modelData
                        Drag.active:windowPointer.drag.active
                        Drag.source:windowChip;Drag.keys:["senomy-window"]
                        Drag.hotSpot.x:width/2;Drag.hotSpot.y:height/2
                        Text {anchors.centerIn:parent;width:parent.width-16;text:windowRow.modelData.class||"Application";color:Config.DirectoryStyle.ink;elide:Text.ElideRight;textFormat:Text.PlainText}
                        MouseArea {id:windowPointer;anchors.fill:parent;drag.target:windowChip;property real originalX;property real originalY;onPressed:{originalX=windowChip.x;originalY=windowChip.y;}onReleased:{windowChip.Drag.drop();windowChip.x=originalX;windowChip.y=originalY;}}
                    }
                    ShellComboBox {id:windowDestination;width:100;property var destinations:root.workspaces.filter(w=>w.id>0&&w.id!==row.modelData.id);model:destinations.map(w=>w.monitor+" · "+root.labelFor(w.id));Accessible.name:"Window destination workspace"}
                    DashboardButton {width:64;text:"MOVE";enabled:windowDestination.currentIndex>=0;onClicked:root.review({action:"window-move",id:windowDestination.destinations[windowDestination.currentIndex].id,address:windowRow.modelData.address,pid:windowRow.modelData.pid,sourceWorkspace:row.modelData.id},"Move this application to native workspace "+windowDestination.currentText+" without following it.")}
                }
            }
            Rectangle {width:parent.width;height:1;color:Config.DirectoryStyle.rule}
        }
    }
    ShellTextField {id:workspaceLabel;width:parent.width;placeholderText:"Name for selected workspace";Accessible.name:"Workspace name"}
    DashboardButton {text:"RENAME SELECTED";enabled:root.selectedWorkspace>0&&workspaceLabel.text.trim().length>0;onClicked:root.review({action:"rename",id:root.selectedWorkspace,label:workspaceLabel.text},"Rename native workspace "+root.selectedWorkspace+" to “"+workspaceLabel.text+"”. Native ID and windows stay unchanged.")}
}
