import QtQuick
import QtQuick.Window
import QtTest
import "components"
import "config" as Config
Window {
    id:test;visible:true;width:400;height:200
    TestCase {id:input;when:false}
    MetalSheen {id:rail;anchors.fill:parent;idleMotion:false;engaged:false}
    MetalSheen {id:ambient;anchors.fill:parent;animate:false}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw Error(msg);}}
    Timer {interval:250;running:true;onTriggered:{
        test.check(Config.ReflectionLight.activeClients===0 && !Config.ReflectionLight.running,"idle Rail does not register");
        rail.engaged=true;input.wait(20);test.check(Config.ReflectionLight.activeClients===1,"engagement acquires light");
        rail.visible=false;input.wait(20);test.check(Config.ReflectionLight.activeClients===0,"hidden client releases light");
        rail.visible=true;input.wait(20);test.check(Config.ReflectionLight.activeClients===1,"visible engaged client resumes");
        rail.engaged=false;const frozen=rail.phase;ambient.animate=true;input.wait(550);test.check(rail.phase===frozen,"idle Rail stays still while another surface animates");
        ambient.animate=false;rail.engaged=true;
        const original=Config.Skin.registry;Config.Skin.registry=Object.assign({},original,{persona:Object.assign({},original.persona||{},{reducedMotion:true})});input.wait(20);
        test.check(Config.ReflectionLight.activeClients===0 && !Config.ReflectionLight.running,"reduced motion releases all clients");
        Config.Skin.registry=original;rail.engaged=false;input.wait(20);test.check(Config.ReflectionLight.activeClients===0,"no registration leak");
        console.log("PASS: Rail engagement, hidden/reduced-motion release, frozen idle light and ambient compatibility");Qt.quit();
    }}
}
