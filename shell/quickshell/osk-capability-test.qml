import QtQuick
import QtTest
import Quickshell
import "services"
import "components"
Scope {
    id: test
    InputSettings { id: settings; active: false }
    NativeInputToolsView { id: view; width: 340; settings: settings }
    function check(ok, message) {
        if (!ok) { console.error("FAIL: " + message); Qt.exit(1); throw new Error(message); }
    }
    Timer {
        running: true; interval: 300
        onTriggered: {
            for (const text of ["bad JSON", "{}", JSON.stringify({ok:true,providerInstalled:true,provider:"arbitrary-command",protocolState:"advertised",message:"fixture"}), JSON.stringify({ok:true,providerInstalled:false,protocolState:"fake",message:"fixture"})]) {
                settings.consumeOskCapabilities(text);
                test.check(settings.oskCapabilities.ok === false && settings.oskCapabilities.protocolState === "unknown","malformed data must reset compatibility");
            }
            settings.consumeOskCapabilities(JSON.stringify({ok:true,providerInstalled:true,provider:"wvkbd-mobintl",protocolState:"unknown",manualCandidate:true,integrated:true,message:"fixture unknown"}));
            test.check(!settings.oskCapabilities.integrated && !settings.oskCapabilities.manualCandidate,"unknown data cannot promote integration or readiness");
            settings.consumeOskCapabilities(JSON.stringify({ok:true,providerInstalled:true,provider:"wvkbd-mobintl",protocolState:"advertised",manualCandidate:true,integrated:true,message:"fixture candidate"}));
            test.check(settings.oskCapabilities.manualCandidate && !settings.oskCapabilities.integrated,"advertised candidate is still not integrated");
            console.log("PASS: OSK capability schema rejects invalid data and never claims completed integration; isolated provider only");
            Qt.quit();
        }
    }
}
