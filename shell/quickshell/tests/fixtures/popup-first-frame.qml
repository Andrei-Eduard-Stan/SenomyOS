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
 Item {id:trigger;width:44;height:44}
 Interaction.QuickPopoverWindow {id:lens;anchorItem:trigger;coordinator:state;popupToken:"lens:fixture";requestedOpen:state.activePopup===popupToken;waitForFirstFrame:true;width:160;height:100}
 Interaction.QuickPopoverWindow {id:other;anchorItem:trigger;coordinator:state;popupToken:"volume:fixture";requestedOpen:state.activePopup===popupToken;width:160;height:100}
 function check(ok,msg){if(!ok)throw new Error(msg);}
 Timer {interval:200;running:true;onTriggered:{try {
  state.showPrimary("control","fixture","overview");
  for(let i=0;i<12;i++){
   state.togglePopup("lens","fixture");
   test.check(!lens.cardShown,"cold and warm openings initially hide content");
   const generation=lens.localGeneration,lease=lens.lease;
   input.wait(120);test.check(lens.cardShown,"configured frame reveals opening");
   state.togglePopup("volume","fixture");input.wait(20);
   lens.reveal(generation,lease);test.check(!lens.cardShown && !lens.visible && other.cardShown,"old frame cannot reveal replaced popup");
   state.closePopups();
  }
  state.togglePopup("lens","fixture");const oldGeneration=lens.localGeneration,oldLease=lens.lease;
  state.closePopups();state.togglePopup("lens","fixture");
  lens.reveal(oldGeneration,oldLease);test.check(!lens.cardShown,"same-token stale frame cannot reveal new opening");
  input.wait(240);test.check(lens.cardShown,"latest same-token opening receives its own frame");
  state.externalModalActive=true;test.check(!state.togglePopup("volume","fixture") && lens.visible,"modal review retains current opening");
  state.externalModalActive=false;lens.handleEscape();test.check(lens.visible && lens.lifecycle==="closing" && !lens.focusGrabActive,"Escape releases focus and retains exit");input.wait(200);test.check(!lens.visible && state.activePrimary==="control","completed exit unmaps and preserves primary");
  console.log("PASS: 12 cold/warm first-frame openings, replacement, same-token stale frame, modal guard and Escape");Qt.quit();
 }catch(e){console.error("FAIL:",e);Qt.exit(1);}}}
}
