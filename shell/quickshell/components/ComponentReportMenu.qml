import QtQuick
import "interaction" as Interaction
import "../config" as Config
import QtQuick.Controls
import Quickshell
import Quickshell.Io
Item {
    id: root
    property string componentKey: "component"
    property var report: ({})
    property var targetItem: parent
    property string status: ""
    property bool busy: false
    property bool snapshotEnabled:true
    property var extraActions:[]
    signal extraActionRequested(string action)
    property var frozenImage: null
    width: Config.DirectoryStyle.touchMode?48:38; height: width
    function run(action) {
        if(busy || (action==="snapshot" && !snapshotEnabled))return;
        menu.close(); feedback.close(); status=""; busy=true;
        if(action==="snapshot") {
            Qt.callLater(()=>{
                if(!targetItem || !targetItem.grabToImage(result=>{
                    root.frozenImage=result;
                    runner.exec(["python3",Quickshell.shellDir+"/scripts/component-report.py","snapshot",root.componentKey]);
                })) {root.busy=false;root.status="Snapshot unavailable for this component";feedback.open();feedbackTimer.restart();}
            });
        } else runner.exec(["python3",Quickshell.shellDir+"/scripts/component-report.py",action,componentKey,JSON.stringify(report)]);
    }
    ToolButton {
        id: trigger;objectName:"report-menu-"+root.componentKey;anchors.fill:parent
        text:"⋯";enabled:!root.busy;hoverEnabled:true
        Accessible.name:"Report actions for "+root.componentKey
        contentItem:Text {text:trigger.text;color:Config.DirectoryStyle.muted;font.family:Config.DirectoryStyle.dataFont;font.pixelSize:26;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
        background:Rectangle {color:"transparent";border.width:0;border.color:trigger.activeFocus?Config.DirectoryStyle.ink:Config.DirectoryStyle.rule;radius:2}
        ButtonHoverFrame { focused: trigger.visualFocus; anchors.fill: parent; engaged: trigger.enabled && trigger.hovered }
        onClicked:menu.open()
    }
    Popup {
        enter: Interaction.MenuMotion {}
        exit: Interaction.MenuMotion { opening: false }
        id:menu;objectName:"component-report-popup"
        x:Math.min(0,root.width-width);y:root.height; width:218; padding:8
        closePolicy:Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background:Rectangle {color:"#f2080a0c";border.width:1;border.color:Config.DirectoryStyle.muted;radius:3}
        contentItem:Column {
            spacing:2
            Repeater {
                id:menuItems
                model:[{id:"copy",label:"Copy report"},{id:"text",label:"Save report as text"}].concat(root.snapshotEnabled?[{id:"snapshot",label:"Save snapshot PNG"}]:[]).concat(root.extraActions)
                delegate:ExpandedButton {
                    required property var modelData
                    width:202;height:Config.DirectoryStyle.touchMode?48:36;subtle:true;text:modelData.label;onClicked:if(modelData.custom){menu.close();root.extraActionRequested(modelData.id);}else root.run(modelData.id)
                }
            }
        }
        onOpened:if(menuItems.itemAt(0))menuItems.itemAt(0).forceActiveFocus()
        onClosed:trigger.forceActiveFocus()
    }
    Popup {
        id:feedback;x:Math.min(0,root.width-width);y:root.height;width:Math.min(360,root.targetItem?root.targetItem.width:300);padding:10
        closePolicy:Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background:Rectangle {color:"#f2080a0c";border.width:1;border.color:Config.DirectoryStyle.rule;radius:3}
        contentItem:Text {text:root.status;textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere;color:Config.DirectoryStyle.ink;font.family:Config.DirectoryStyle.dataFont;font.pixelSize: 13}
    }
    Timer {id:feedbackTimer;interval:6000;onTriggered:feedback.close()}
    Process {
        id:runner
        stdout:StdioCollector {id:output}
        onExited:(code,exitStatus)=>{
            try {
                const result=JSON.parse(output.text);
                if(root.frozenImage && result.ok && result.path) {
                    const captured=root.frozenImage;root.frozenImage=null;
                    if(captured.saveToFile(result.path)) {
                        exec(["python3",Quickshell.shellDir+"/scripts/component-report.py","finish",root.componentKey,result.path]);
                        return;
                    }
                    root.status="PNG export failed";
                } else root.status=result.message || "Report export failed";
            } catch(error){root.status="Report export failed";root.frozenImage=null;}
            root.busy=false; feedback.open();feedbackTimer.restart();
        }
    }
}
