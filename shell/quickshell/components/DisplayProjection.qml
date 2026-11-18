pragma ComponentBehavior: Bound
import QtQuick
import "../config" as Config

Column {
    id:root
    required property var inventory
    property bool editable:true
    property var externalSelection:[]
    property string membership:""
    readonly property var displays:inventory.displays||[]
    readonly property var externals:displays.filter(m=>! /^(eDP|LVDS|DSI)-/.test(m.name))
    readonly property bool internalAvailable:displays.some(m=>/^(eDP|LVDS|DSI)-/.test(m.name))
    readonly property string stagedMode:inventory.draft&&inventory.draft.policyPatch?inventory.draft.policyPatch.projectionMode||"":""
    readonly property string actualMode:((inventory.snapshot||{}).projection||{}).mode||"custom"
    signal customRequested()
    spacing:8
    function reconcileExternals(){const names=externals.map(m=>m.name),key=names.join("|");if(key===membership)return;const old=membership.split("|");externalSelection=names.filter(n=>externalSelection.indexOf(n)>=0||old.indexOf(n)<0);membership=key;}
    Component.onCompleted:reconcileExternals()
    onExternalsChanged:reconcileExternals()
    Text {width:parent.width;text:"PROJECTION MODE · running: "+root.actualMode.toUpperCase()+(root.stagedMode?" · staged: "+root.stagedMode.toUpperCase():"");color:Config.DirectoryStyle.ink;font.pixelSize:13;wrapMode:Text.WordWrap}
    Text {width:parent.width;text:"Choose a mode to stage it, then Review & Apply. Every physical change has independent rollback. Extend restores the previous saved distribution when the same displays are connected.";color:Config.DirectoryStyle.muted;font.pixelSize:12;wrapMode:Text.WordWrap}
    Flow {
        width:parent.width;spacing:6
        Repeater {
            model:[{id:"pc-only",label:"PC SCREEN ONLY"},{id:"duplicate",label:"DUPLICATE"},{id:"extend",label:"EXTEND"},{id:"external-only",label:"SECOND SCREEN ONLY"}]
            DashboardButton {
                required property var modelData
                objectName:"projection-mode-"+modelData.id
                width:Math.max(150,(root.width-6)/2);text:modelData.label
                active:(root.stagedMode||root.actualMode)===modelData.id
                enabled:root.editable&&!root.inventory.displayBusy&&(modelData.id!=="pc-only"||root.internalAvailable)&&(modelData.id!=="external-only"||root.externalSelection.length>0)&&root.displays.length>0
                onClicked:root.inventory.planProjection(modelData.id,source.currentText,root.externalSelection)
            }
        }
    }
    DashboardButton {width:parent.width;text:"CUSTOM ARRANGEMENT";enabled:root.editable;onClicked:root.customRequested()}
    Text {width:parent.width;visible:!!root.stagedMode;text:"STAGED · Review & Apply below will show the complete change before confirmation.";color:Config.Theme.warning;font.pixelSize:12;wrapMode:Text.WordWrap}
    Text {width:parent.width;text:"Duplicate source";color:Config.DirectoryStyle.muted;font.pixelSize:12}
    ShellComboBox {id:source;width:parent.width;model:root.displays.map(m=>m.name);Accessible.name:"Projection duplicate source"}
    Text {width:parent.width;text:"Second Screen Only uses the selected external group. The laptop is disabled; windows remain accessible on a surviving output.";color:Config.DirectoryStyle.muted;font.pixelSize:12;wrapMode:Text.WordWrap}
    Flow {
        width:parent.width;spacing:6
        Repeater {model:root.externals;DashboardButton {
            required property var modelData
            text:modelData.name;active:root.externalSelection.indexOf(modelData.name)>=0
            onClicked:{const next=root.externalSelection.slice(),i=next.indexOf(modelData.name);if(i<0)next.push(modelData.name);else next.splice(i,1);root.externalSelection=next;}
        }}
    }
    Text {width:parent.width;text:"Custom layouts are available in Arrangement and Settings. Duplicate uses native Hyprland mirroring; different aspect ratios may stretch. A mode advertised by each monitor can still exceed the shared connection’s capacity.";color:Config.DirectoryStyle.muted;font.pixelSize:12;wrapMode:Text.WordWrap}
    Text {width:parent.width;visible:!root.internalAvailable;text:"No built-in display is detected. PC Screen Only is unavailable.";color:Config.Theme.warning;font.pixelSize:12;wrapMode:Text.WordWrap}
}
