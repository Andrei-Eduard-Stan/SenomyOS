import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "services"
import "components/control"
Window {
    id: suite; visible:true; width:390; height:800
    property int phase:0
    property int ticks:0
    BatteryService { id:shared; energyEnabled:false; energy:fakeEnergy; care:care; actionContext:"fixture"; provider:fakeProvider }
    QtObject { id:fakeProvider; property var devices:({values:[]}); property bool onBattery:true; property var displayDevice:({ready:false}) }
    QtObject { id:fakeEnergy; property bool available:true; property string profile:"balanced"; property string identity:"fixture"; property var profiles:["balanced","power-saver"]; property var backend:({token:"fixture",kind:"tlp"}); property bool busy:false; property bool runningAction:false; property bool actionFailed:false; property string actionError:"" }
    BatteryCare { id:care;context:"fixture"; blocked:fakeEnergy.busy || shared.selectionActions.locked; helper:Quickshell.shellDir+"/tests/fixtures/battery-care-fake.py" }
    BatteryCareEditor {id:editor;width:parent.width;care:care}
    TestCase {id:input;when:false}
    function check(ok,why){if(!ok)throw new Error(why);}
    Timer {interval:100;repeat:true;running:true;onTriggered:{
        try{
            if(++suite.ticks>80)throw new Error("Care fixture deadline phase "+suite.phase+": "+care.message);
            if(suite.phase===0){
                if(!care.fresh)return;
                suite.check(care.packs.length===2,"dual-pack state");
                care.edit(care.packs[0],"selected",true);care.edit(care.packs[0],"start",80);care.edit(care.packs[0],"stop",70);
                suite.check(!care.requestApply()&&care.actionState==="failed","invalid pair refused");
                care.edit(care.packs[0],"start",70);care.edit(care.packs[0],"stop",80);
                suite.check(care.requestApply()&&care.actionState==="pending","review only");
                suite.check(care.packs[0].effective[0]===0,"review does not mutate");
                suite.check(shared.selectionOptions("profile").length===0&&!shared.setPowerProfile(0),"shared quick/Settings profile interlock");
                suite.check(care.cancel(),"cancel review");suite.check(care.requestApply(),"repeat review");
                suite.check(care.confirm(),"confirm through native Process");suite.check(!care.requestApply(),"single flight");suite.phase++;return;
            }
            if(suite.phase===1){
                if(care.actionState==="running")return;
                suite.check(care.actionState==="succeeded"&&care.packs[0].effective[0]===70,"actual fixture readback");
                suite.check(care.packs[1].effective[0]===0,"other pack untouched");suite.check(care.requestRestore(),"restore review");
                suite.check(care.confirm(),"restore command");suite.phase++;return;
            }
            if(suite.phase===2){
                if(care.actionState==="running")return;
                suite.check(care.actionState==="succeeded"&&care.packs[0].effective[0]===0&&!care.lastReceipt,"restored/shortcut cleared");
                suite.check(editor.implicitHeight>600,"narrow source/threshold layout");suite.width=1120;suite.phase++;return;
            }
            if(suite.phase===4){
                if(care.actionState==="running")return;
                suite.check(care.actionState==="failed"&&!care.fresh,"missing interpreter settles honestly");
                console.log("PASS: native care transport, review/cancel, exact readback/restore, invalid pairs, single-flight, dual-pack, shared profile interlock, missing interpreter, stale guards, narrow/wide and keyboard; no hardware writes");Qt.quit();return;
            }
            suite.check(editor.width===1120,"wide layout");
            const select=input.findChild(editor,"care-select-BAT0");suite.check(!!select,"keyboard target");select.forceActiveFocus();input.keyClick(Qt.Key_Space);suite.check(care.draft(care.packs[0]).selected,"keyboard selection");
            care.persistentChoice=true;care.snapshot=Object.assign({},care.snapshot,{persistentAvailable:false});
            const persistent=input.findChild(editor,"care-persistent"),apply=input.findChild(editor,"care-apply");
            suite.check(persistent.enabled&&!apply.enabled,"external persistence conflict blocks Apply but permits runtime fallback");
            persistent.forceActiveFocus();input.keyClick(Qt.Key_Space);suite.check(!care.persistentChoice&&!persistent.enabled,"uncheck blocked persistence");
            care.snapshot=Object.assign({},care.snapshot,{persistentAvailable:true});
            care.blocked=true;suite.check(!care.requestApply(),"profile operation blocks care");
            care.blocked=false;care.lastReceipt={receipt:"c".repeat(32),restorableToken:"a".repeat(64)};care.snapshot=Object.assign({},care.snapshot,{token:"d".repeat(64)});suite.check(!care.requestRestore(),"stale receipt refused");
            care.interpreter="/senomy-fixture-missing-python";suite.check(care.requestApply()&&care.confirm(),"missing interpreter attempted in fixture only");suite.phase=4;
        }catch(e){console.error("FAIL: "+e.message+" "+e.stack);Qt.exit(1);}
    }}
}
