import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components/interaction" as Interaction
import "services"
Window {
    id:test;visible:true;width:320;height:200
    TestCase {id:input;when:false}
    ShellState {id:state;availableScreens:["fixture"]}
    Item {id:anchor;width:44;height:44}
    Interaction.QuickPopoverWindow {id:first;anchorItem:anchor;coordinator:state;popupToken:"volume:fixture";requestedOpen:state.activePopup===popupToken;width:160;height:100}
    Interaction.QuickPopoverWindow {id:second;anchorItem:anchor;coordinator:state;popupToken:"calendar:fixture";requestedOpen:state.activePopup===popupToken;width:160;height:100}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw Error(msg);}}
    Timer {interval:250;running:true;onTriggered:{
        state.showPrimary("control","fixture","overview");
        for(let i=0;i<30;i++){
            state.togglePopup("volume","fixture");const old=state.popupGeneration;
            state.togglePopup("calendar","fixture");
            test.check(!first.visible && second.visible,"replacement unmaps outgoing popup immediately");
            test.check(!state.closePopups("volume:fixture",old),"old dismissal cannot close replacement");
            state.closePopups();test.check(!first.visible&&!second.visible,"close does not retain invisible input surface");
        }
        state.togglePopup("volume","fixture");input.wait(30);test.check(first.cardShown && first.visible,"final open survives stale queued reveals");
        const held=state.popupGeneration;state.externalModalActive=true;
        test.check(!state.togglePopup("calendar","fixture") && state.popupGeneration===held,"review protects opening lease");
        state.externalModalActive=false;first.handleEscape();input.wait(20);test.check(!first.visible && state.activePrimary==="control","Escape dismisses inner popup and preserves primary");
        state.togglePopup("volume","fixture");anchor.visible=false;state.closePopups();input.wait(20);
        console.log("PASS: 30 real quick-popover replacements, stale callback/dismissal rejection, immediate unmap, review guard and primary-preserving Escape");Qt.quit();
    }}
}
