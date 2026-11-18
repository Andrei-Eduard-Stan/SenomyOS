import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Services.UPower
import "interaction" as Interaction
import "../config" as Config

Interaction.QuickPopoverWindow {
    id:root
    required property var battery
    signal openSettingsRequested(string route)
    signal openSessionRequested()
    property bool packsOpen:false
    readonly property real availableWidth:(targetScreen?targetScreen.width:800)-2*Config.Theme.screenInset
    readonly property real availableHeight:(targetScreen?targetScreen.height:800)-Config.Theme.railHeight-2*Config.Theme.screenInset
    readonly property var energy:battery.energy || null
    readonly property bool locked:battery.selectionActions.locked || !!(battery.care && battery.care.locked) || !!(energy && energy.busy)
    readonly property bool hasEstimate:battery.available && battery.aggregateTimeSeconds>0
    function estimateDuration(seconds){const minutes=Math.round(seconds/60);if(minutes<1)return "less than a minute";const hours=Math.floor(minutes/60);return (hours?hours+"h ":"")+(minutes%60)+"m";}
    readonly property string estimate:!battery.available?"No laptop battery reported":hasEstimate?"Estimated "+estimateDuration(battery.aggregateTimeSeconds)+(battery.charging?" until full":" remaining"):battery.chargeState==="fully charged"?"Charge complete":"Time estimate unavailable"
    function profileLabel(value){return value===PowerProfile.PowerSaver?"Saver":value===PowerProfile.Balanced?"Balanced":value===PowerProfile.Performance?"Performance":"Unavailable";}
    function percent(pack){return Number.isFinite(pack.percentage) && pack.percentage>=0 && pack.percentage<=1?Math.round(pack.percentage*100)+"%":"Unavailable";}
    function energyLabel(value,suffix){return Number.isFinite(value) && value>=0?Math.round(value*10)/10+suffix:"Unavailable";}
    implicitWidth:Math.min(460,Math.max(1,availableWidth))
    implicitHeight:Math.min(availableHeight,Math.max(220,2*frame.contentInset+header.height+24+body.implicitHeight+footer.implicitHeight))
    color:"transparent";focusTarget:card
    // Preserve the established native Rail anchor and shared popup lifecycle.
    anchor.item:anchorItem
    anchor.edges:Edges.Top
    anchor.gravity:Edges.Top
    anchor.rect.x:anchorItem?anchorItem.width/2:0
    anchor.rect.width:0
    anchor.rect.height:0
    anchor.rect.y:-12
    FocusScope {
        id:card;anchors.fill:parent;focus:root.cardShown;opacity: root.presentationProgress
        Keys.onEscapePressed:root.handleEscape()
        IslandPopupFrame {
            id:frame;anchors.fill:parent;contentInset:24;frameKey:"power"
            Item {
                id:header;width:parent.width;height:Config.DirectoryStyle.controlTarget
                Text {height:parent.height;text:"// Power";verticalAlignment:Text.AlignVCenter;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Math.round(16*Config.DirectoryStyle.textScale)}
                QuietButton {objectName:"batteryClose";anchors.right:parent.right;width:Config.DirectoryStyle.controlTarget;height:width;iconOnly:true;glyph:"\uf00d";accessibleLabel:"Close Power";onClicked:root.dismiss()}
            }
            Column {
                id:footer;anchors.bottom:parent.bottom;width:parent.width;spacing:12
                IslandRule {width:parent.width;leadingPoint:false}
                Flow {
                    id:exits;width:parent.width;spacing:8
                    TextMetrics {id:exitMeasure;text:"Session actions";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                    readonly property bool stacked:width<2*(exitMeasure.advanceWidth+24+2*Config.DirectoryStyle.controlInset)+8
                    readonly property real cellWidth:stacked?width:(width-8)/2
                    QuietButton {objectName:"batterySettings";width:exits.cellWidth;height:Config.DirectoryStyle.controlTarget;text:"Power Settings";glyph:"\uf013";onClicked:root.openSettingsRequested("power")}
                    QuietButton {objectName:"batterySession";width:exits.cellWidth;height:Config.DirectoryStyle.controlTarget;text:"Session actions";glyph:"\uf011";onClicked:root.openSessionRequested()}
                }
            }
            FocusScrollArea {
                id:viewport;objectName:"batteryViewport";anchors.fill:parent;anchors.topMargin:header.height+12;anchors.bottomMargin:footer.implicitHeight+12
                contentHeight:body.implicitHeight;ScrollBar.vertical:ShellScrollBar {}
                Column {
                    id:body;width:parent.width;spacing:12
                    Row {
                        width:parent.width;spacing:12
                        Column {
                            width:Math.max(1,parent.width-(charge.visible?charge.width+parent.spacing:0));anchors.verticalCenter:parent.verticalCenter;spacing:6
                            Text {width:parent.width;text:!root.battery.available?"No battery reported":root.battery.onBattery?"On battery":"External power";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Math.round(20*Config.DirectoryStyle.textScale);font.weight:Font.DemiBold;color:Config.DirectoryStyle.ink;wrapMode:Text.WordWrap}
                            Text {width:parent.width;text:root.battery.available?(root.battery.chargeState || "State unavailable"):(root.battery.powerProfileAvailable?"Power profiles remain available":"Power-policy provider unavailable");textFormat:Text.PlainText;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize;color:root.battery.low?Config.Theme.warning:Config.DirectoryStyle.muted;wrapMode:Text.WordWrap}
                        }
                        Text {id:charge;objectName:"batteryCharge";visible:root.battery.available;text:root.battery.chargeAvailable?root.battery.label:"—";font.family:Config.DirectoryStyle.valueFont;font.pixelSize:Math.round(44*Config.DirectoryStyle.textScale);color:root.battery.critical?Config.Theme.danger:root.battery.low?Config.Theme.warning:Config.DirectoryStyle.ink;Accessible.name:"Combined charge "+text}
                    }
                    Rectangle {
                        width:parent.width;height:4;visible:root.battery.chargeAvailable;color:Config.DirectoryStyle.rule
                        Rectangle {width:parent.width*Math.max(0,Math.min(1,root.battery.percentage));height:parent.height;color:root.battery.critical?Config.Theme.danger:root.battery.low?Config.Theme.warning:Config.DirectoryStyle.ink}
                    }
                    Text {objectName:"batteryEstimate";width:parent.width;visible:root.battery.available;text:root.estimate;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize}
                    Text {width:parent.width;visible:root.battery.available;text:root.battery.count+(root.battery.count===1?" battery pack":" battery packs")+(root.battery.energyAvailable?" · capacity-weighted charge":" · reported charge estimate");wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                    QuietButton {objectName:"batteryPacks";width:parent.width;height:Config.DirectoryStyle.controlTarget;visible:root.battery.available;text:root.packsOpen?"Hide battery details":"Battery details";glyph:root.packsOpen?"\uf077":"\uf078";Accessible.expandable:true;Accessible.expanded:root.packsOpen;onClicked:root.packsOpen=!root.packsOpen}
                    Column {
                        id:packDetails
                        visible:root.packsOpen && root.battery.available;width:parent.width;spacing:12
                        Repeater {
                            model:root.battery.batteries
                            delegate:Column {
                                required property var modelData
                                required property int index
                                width:parent.width;spacing:6
                                Row {
                                    width:parent.width;spacing:8
                                    Text {width:parent.width-packLevel.width-parent.spacing;text:"Battery "+(index+1);color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;font.weight:Font.DemiBold}
                                    Text {id:packLevel;text:root.percent(modelData);color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:Config.DirectoryStyle.bodySize}
                                }
                                Rectangle {width:parent.width;height:2;color:Config.DirectoryStyle.rule;visible:Number.isFinite(modelData.percentage) && modelData.percentage>=0 && modelData.percentage<=1;Rectangle {width:parent.width*Math.max(0,Math.min(1,modelData.percentage));height:parent.height;color:Config.DirectoryStyle.muted}}
                                Text {width:parent.width;text:[modelData.model || modelData.nativePath || "Battery pack",UPowerDeviceState.toString(modelData.state),root.energyLabel(modelData.energy," Wh")+" / "+root.energyLabel(modelData.energyCapacity," Wh"),"Reported rate "+root.energyLabel(modelData.changeRate," W")].join(" · ");textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                            }
                        }
                        QuietButton {objectName:"batteryCareSettings";width:parent.width;height:Config.DirectoryStyle.controlTarget;text:"Battery care in Settings";onClicked:root.openSettingsRequested("power/batteries")}
                    }
                    IslandRule {width:parent.width;leadingPoint:false}
                    Text {width:parent.width;text:"Power profile";color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.headingFont;font.pixelSize:Math.round(13*Config.DirectoryStyle.textScale)}
                    Flow {
                        id:profiles;width:parent.width;spacing:8
                        TextMetrics {id:profileMeasure;text:"Performance";font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                        readonly property real cellMin:profileMeasure.advanceWidth+2*Config.DirectoryStyle.controlInset
                        readonly property int columns:width>=3*cellMin+16?3:width>=2*cellMin+8?2:1
                        readonly property real cellWidth:Math.floor((width-(columns-1)*spacing)/columns)
                        Repeater {
                            model:[PowerProfile.PowerSaver,PowerProfile.Balanced,PowerProfile.Performance]
                            delegate:QuietButton {
                                id:profileChoice;required property int modelData
                                objectName:"batteryProfile-"+modelData;width:profiles.cellWidth;height:Config.DirectoryStyle.controlTarget
                                text:root.profileLabel(modelData);active:root.battery.powerProfile===modelData;Accessible.checkable:true;Accessible.checked:active
                                enabled:!root.locked && root.battery.selectionOptions("profile").indexOf(modelData)>=0
                                onClicked:if(root.battery.powerProfile!==modelData)root.battery.setPowerProfile(modelData)
                                Rectangle {anchors.bottom:parent.bottom;anchors.bottomMargin:6;anchors.horizontalCenter:parent.horizontalCenter;width:16;height:1;color:Config.DirectoryStyle.ink;visible:profileChoice.active}
                            }
                        }
                    }
                    Text {width:parent.width;visible:!root.battery.powerProfileAvailable;text:root.energy?(root.energy.error || root.energy.backend.reason || "Power-profile changes unavailable"):"Power-policy provider unavailable";wrapMode:Text.WordWrap;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.detailSize}
                    BatteryQuickProfileReview {width:parent.width;actions:root.battery.selectionActions}
                    // Care transactions share the same protected review context as Settings.
                    BatteryQuickProfileReview {
                        objectName:"batteryCareReview"
                        width:parent.width
                        visible:!!root.battery.care && root.battery.care.actionState!=="idle"
                        actions:root.battery.care || root.battery.selectionActions
                        confirmLabel:"Confirm battery-care action"
                    }
                }
            }
        }
    }
}
