import QtQuick
import QtTest
import Quickshell
import "../../services" as Services

Scope {
    id:test
    property int failures:0
    TestCase {id:input;when:false}
    QtObject {
        id:controller
        property string state:"stopped"
        property bool owned:false
        property bool startPending:false
        signal manualStop()
        signal manualAction(bool showing)
        signal capabilitiesChanged()
        function disableAutomaticFocus(){return true;}
        function prepareAutomatic(){throw new Error("No provider startup permitted");}
    }
    Services.OskAutomatic {id:automatic;controller:controller;monitoring:false}
    Services.DesktopSettings {id:desktop;active:true;context:"inert-fixture"}
    Services.InputSettings {id:settings;active:false}
    function check(ok,message){if(!ok){failures++;console.error("FAIL: "+message);}else console.log("PASS: "+message);}
    Timer {
        interval:400;running:true
        onTriggered:{
            test.check(!desktop.available && desktop.error.length>0,"nonzero desktop inventory reports failure");
            test.check(Object.keys(desktop.capabilities).length===0 && desktop.capabilityError.length>0,"nonzero portal inventory reports failure");
            desktop.refresh();input.wait(300);
            test.check(desktop.available && desktop.error==="" && desktop.capabilityError==="","desktop and portal read-only retry recovers");
            test.check(desktop.actions.request("default","text/plain","fixture.desktop") && desktop.actions.confirm(),"inert reviewed preference request");input.wait(300);
            test.check(desktop.actions.actionState!=="succeeded" && !desktop.actions.message.includes("False-fixture-success"),"nonzero preference operation cannot show success text");
            automatic.consume('{"ok":true,"mode":"auto","physicalKeyboard":true,"textActive":false,"inputMethod":false,"locked":false,"focusEpoch":1}');
            automatic.setMode("manual");input.wait(250);
            test.check(automatic.mode==="auto" && !automatic.settingMode && automatic.status.includes("verified"),"nonzero OSK mode write does not change acknowledged mode");
            automatic.setMode("manual");input.wait(250);
            test.check(automatic.mode==="auto" && automatic.status.includes("verified"),"OSK mode readback mismatch is rejected");
            automatic.setMode("manual");input.wait(250);
            test.check(automatic.mode==="manual" && !automatic.settingMode,"matching inert mode receipt is accepted");
            settings.refreshNativeTools();input.wait(250);
            test.check(settings.editorAvailable,"inert IME tool discovered");settings.openInputMethodSettings();input.wait(250);
            test.check(!settings.nativeToolsBusy && settings.nativeToolsState!=="started" && !settings.nativeToolsMessage.includes("False-fixture-success"),"nonzero native handoff cannot claim a started application");
            if(desktop.interpreter!==undefined && automatic.interpreter!==undefined && settings.nativeInterpreter!==undefined){
                desktop.interpreter="/nonexistent/senomy-wp07-fixture";
                desktop.actions.request("default","text/plain","fixture.desktop");desktop.actions.confirm();input.wait(350);
                test.check(!desktop.actions.locked && desktop.actions.message.includes("could not start"),"missing preference worker releases review");
                desktop.refresh();input.wait(350);
                test.check(!desktop.loading && desktop.error.includes("could not start") && desktop.capabilityError.includes("could not start"),"missing inventory workers release progress");
                automatic.interpreter="/nonexistent/senomy-wp07-fixture";automatic.setMode("auto");input.wait(350);
                test.check(!automatic.settingMode && automatic.mode==="manual" && automatic.status.includes("could not start"),"missing OSK preference worker leaves confirmed mode intact");
                settings.nativeInterpreter="/nonexistent/senomy-wp07-fixture";settings.openInputMethodSettings();input.wait(350);
                test.check(!settings.nativeToolsBusy && settings.nativeToolsState==="failed" && settings.nativeToolsMessage.includes("could not start"),"missing native handoff worker releases progress");
            }else test.check(false,"missing-worker recovery not implemented");
            console.log("RESULT: inert desktop/OSK/native transports "+test.failures+" failures; no real input, defaults, permissions or applications changed");
            Qt.exit(test.failures?1:0);
        }
    }
}
