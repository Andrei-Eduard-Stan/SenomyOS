import QtQuick
import QtQuick.Window
import Quickshell
import QtTest
import "components"
import "components/interaction" as Interaction
import "services"

Window {
    id: test
    visible:true
    TestCase {id:input;when:false}
    width: 1200; height: 800
    ShellState { id: state }
    QtObject {id:audio;property bool available:true;property bool muted:false;property real volume:0.3}
    QtObject {id:network;property bool available:true;property string connectivityName:"Full";property string detail:"Fixture network"}
    QtObject {id:battery;property bool available:true;property bool charging:false;property real percentage:0.6;property string detail:"Fixture battery"}
    SystemControlsIsland {
        id:rail;width:338;height:60;y:720
        audio:audio;network:network;battery:battery
        onOpenControl:section=>state.togglePrimary("control","left",state.controlPath || state.controlSection,state.controlMode)
        onOpenSettings:section=>state.showSettings("left",section)
        onToggleLens:state.togglePopup("lens","left",lensAnchor)
        onToggleNetwork:state.togglePopup("network","left",networkAnchor)
        onToggleVolume:state.togglePopup("volume","left",volumeAnchor)
        onToggleBattery:state.togglePopup("battery","left",batteryAnchor)
    }
    Interaction.QuickPopoverWindow {
        id:wifi;coordinator:state;popupToken:"network:left";anchorItem:rail.networkAnchor
        requestedOpen:state.activePopup===popupToken
        width:460;height:500;focusTarget:wifiCard
        FocusScope {id:wifiCard;anchors.fill:parent;focus:true;Keys.onEscapePressed:wifi.handleEscape()}
    }
    Interaction.QuickPopoverWindow {
        id:volume;coordinator:state;popupToken:"volume:left";anchorItem:rail.volumeAnchor
        requestedOpen:state.activePopup===popupToken
        width:460;height:500;focusTarget:volumeCard
        FocusScope {id:volumeCard;anchors.fill:parent;focus:true;Keys.onEscapePressed:volume.handleEscape()}
    }
    Interaction.QuickPopoverWindow {
        id:lens;keyboardPriority:true;coordinator:state;popupToken:"lens:left";anchorItem:rail.lensAnchor
        requestedOpen:state.activePopup===popupToken
        width:700;height:600;focusTarget:lensCard
        FocusScope {id:lensCard;anchors.fill:parent;focus:true;Keys.onEscapePressed:lens.handleEscape()}
    }
    function test_control_trigger_toggle_retains_route_and_mode() {
        state.showPrimary("control","left","network/wifi");
        mouseClick(button("control"));compare(state.activePrimary,"");
        mouseClick(button("control"));compare(state.activePrimary,"control");compare(state.controlPath,"network/wifi");compare(state.controlMode,"compact");
        mouseClick(button("control"));compare(state.activePrimary,"");
        state.showSettings("left","audio");mouseClick(button("control"));compare(state.activePrimary,"");
        button("control").forceActiveFocus();keyClick(Qt.Key_Space);compare(state.activePrimary,"control");compare(state.controlMode,"full");compare(state.controlSection,"audio");
        keyClick(Qt.Key_Space);compare(state.activePrimary,"");
        state.showSettings("left","input");state.controlDraftDirty=true;
        mouseClick(button("control"));compare(state.activePrimary,"control");verify(state.deferredPrimary && state.deferredPrimary.closing);
        state.deferredPrimary=null;state.controlDraftDirty=false;state.externalModalActive=true;
        mouseClick(button("control"));compare(state.activePrimary,"control");state.externalModalActive=false;
        state.closePrimary();state.showPrimary("control","right","power");
        mouseClick(button("control"));compare(state.activePrimary,"control");compare(state.primaryScreen,"left");compare(state.controlSection,"power");
    }
    function test_lens_prioritizes_keyboard_then_admits_rails() {
        state.railWindows=[test];
        mouseClick(button("applications"));tryVerify(()=>lens.cardShown);
        const grab=findChild(lens,"test-focus-grab");verify(grab);
        compare(grab.initialWindows.length,1);compare(grab.initialWindows[0],lens);
        tryVerify(()=>lens.ownsEscape && grab.windows.length===2);
        compare(grab.windows[1],test);verify(lensCard.activeFocus);
        state.railWindows=[];
    }
    function test_lens_switching_outside_toggle_modal_and_settings() {
        state.showSettings("left","audio");mouseClick(button("applications"));compare(state.activePopup,"lens:left");tryVerify(()=>lens.cardShown);
        mouseClick(button("network"));compare(state.activePopup,"network:left");verify(!lens.visible);compare(state.activePrimary,"control");
        mouseClick(button("applications"));compare(state.activePopup,"lens:left");verify(!wifi.visible);tryVerify(()=>lens.cardShown);
        findChild(lens,"test-focus-grab").outside();compare(state.activePopup,"");compare(state.activePrimary,"control");
        mouseClick(button("applications"));mouseClick(button("applications"));compare(state.activePopup,"");
        state.externalModalActive=true;mouseClick(button("applications"));compare(state.activePopup,"");state.externalModalActive=false;
        verify(rail.controlData("control").icon!==rail.controlData("applications").icon);
    }
    function button(kind){return findChild(rail,"rail-control-"+kind);}
    function init(){state.externalModalActive=false;state.deferredPrimary=null;state.controlDraftDirty=false;state.closePopups();state.closePrimary();wait(1);}
    function test_pointer_opens_switches_toggles_before_animation_finishes(){
        mouseClick(button("network"));compare(state.activePopup,"network:left");tryVerify(()=>wifi.visible);
        mouseClick(button("audio"));compare(state.activePopup,"volume:left");verify(!wifi.visible);tryVerify(()=>volume.visible);
        mouseClick(button("network"));compare(state.activePopup,"network:left");verify(!volume.visible);
        mouseClick(button("network"));compare(state.activePopup,"");verify(!wifi.requestedOpen && !wifi.focusGrabActive);
        wait(200);verify(!wifi.visible && !volume.visible);
    }
    function test_latest_request_wins_and_old_focus_clear_is_inert(){
        mouseClick(button("network"));tryVerify(()=>wifi.cardShown);
        const oldLease=wifi.lease;
        for(let i=0;i<20;i++){mouseClick(button("audio"));mouseClick(button("network"));}
        compare(state.activePopup,"network:left");verify(!volume.visible);
        verify(!state.closePopups("network:left",oldLease));compare(state.activePopup,"network:left");
        tryVerify(()=>wifi.cardShown);wait(200);verify(wifi.visible && !volume.visible);
    }
    function test_secondary_control_opens_full_settings_and_retains_route(){
        state.showSettings("left","audio");
        input.mouseClick(button("control"),undefined,undefined,Qt.RightButton);
        compare(state.controlMode,"full");compare(state.controlSection,"audio");
        state.closePrimary();button("control").forceActiveFocus();keyClick(Qt.Key_Menu);
        compare(state.activePrimary,"control");compare(state.controlMode,"full");
    }
    function test_external_escape_does_not_double_handle_local_escape(){
        state.showSettings("left","audio");mouseClick(button("network"));tryVerify(()=>wifi.cardShown);
        test.verify(wifi.ownsEscape);
        compare(state.dismissExternal(wifi.ownsEscape),"owned");compare(state.activePopup,"network:left");
        wifi.handleEscape();compare(state.activePopup,"");
        compare(state.dismissExternal(false),"none");compare(state.activePrimary,"control");
    }
    function test_missing_anchor_does_not_leave_ghost_popup(){
        const anchor=wifi.anchorItem;wifi.anchorItem=null;
        state.togglePopup("network","left");tryVerify(()=>state.activePopup==="");verify(!wifi.visible);
        wifi.anchorItem=anchor;
    }
    function test_outside_grab_callback_closes_only_popup(){
        state.showSettings("left","audio");mouseClick(button("network"));tryVerify(()=>wifi.cardShown);
        const grab=findChild(wifi,"test-focus-grab");verify(grab);grab.outside();
        compare(state.activePopup,"");compare(state.activePrimary,"control");verify(!wifi.requestedOpen && !wifi.focusGrabActive);tryVerify(()=>!wifi.visible);
    }
    function test_keyboard_space_escape_and_focus_return(){
        const trigger=button("network");trigger.forceActiveFocus();keyClick(Qt.Key_Space);
        compare(state.activePopup,"network:left");tryVerify(()=>wifi.cardShown);keyClick(Qt.Key_Escape);
        compare(state.activePopup,"");verify(trigger.activeFocus);
    }
    function test_modal_ignores_pointer_switch_and_outside(){
        mouseClick(button("network"));tryVerify(()=>wifi.cardShown);state.externalModalActive=true;
        mouseClick(button("audio"));compare(state.activePopup,"network:left");
        findChild(wifi,"test-focus-grab").outside();compare(state.activePopup,"network:left");verify(wifi.visible);tryVerify(()=>findChild(wifi,"test-focus-grab").active);
        state.externalModalActive=false;wifi.handleEscape();compare(state.activePopup,"");
    }
    function verify(value){if(!value)throw new Error("Verification failed");}
    function compare(a,b){if(a!==b)throw new Error("Expected "+b+", got "+a);}
    function wait(ms){input.wait(ms);}
    function mouseClick(item){input.mouseClick(item);}
    function keyClick(key){input.keyClick(key);}
    function findChild(item,name){return input.findChild(item,name);}
    function tryVerify(callback){let count=0;while(!callback() && ++count<100)input.wait(10);verify(callback());}
    Timer {interval:100;running:true;onTriggered:{
        try {
            for(const run of [test.test_control_trigger_toggle_retains_route_and_mode,test.test_lens_prioritizes_keyboard_then_admits_rails,test.test_lens_switching_outside_toggle_modal_and_settings,test.test_pointer_opens_switches_toggles_before_animation_finishes,test.test_latest_request_wins_and_old_focus_clear_is_inert,test.test_secondary_control_opens_full_settings_and_retains_route,test.test_external_escape_does_not_double_handle_local_escape,test.test_missing_anchor_does_not_leave_ghost_popup,test.test_outside_grab_callback_closes_only_popup,test.test_keyboard_space_escape_and_focus_return,test.test_modal_ignores_pointer_switch_and_outside]){test.init();run();}
            console.log("PASS: actual Rail mouse and key activation, shared popup lifecycle, rapid replacement, stale focus callbacks, outside-dismiss transport, modal protection, keyboard focus return");Qt.quit();
        } catch(error){console.error("FAIL: "+error.stack);Qt.exit(1);}
    }}

}
