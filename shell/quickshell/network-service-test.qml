import QtQuick
import Quickshell
import Quickshell.Networking
import "services"
Scope {
    id:test
    NetworkService {id:network}
    NetworkProfiles {id:profiles;queryEnabled:false}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw new Error(msg);}}
    Timer {
        interval:100;running:true
        onTriggered:{
            test.check(!network.toggleWifi(),"contextless Wi-Fi action rejected");test.check(!network.activate(null),"contextless connection rejected");test.check(!network.openSecurePrompt(null),"contextless secure prompt rejected");
            test.check(network.failureMessage(ConnectionFailReason.NoSecrets).indexOf("Authentication")>=0,"normalized native failure reason");
            test.check(!profiles.openEditor("all",""),"inactive editor rejected");
            profiles.active=true;profiles.context="fixture";profiles.editorAvailable=true;
            test.check(!profiles.openEditor("arbitrary",""),"unknown editor mode rejected");test.check(!profiles.openEditor("edit","foreign"),"unknown profile rejected");
            profiles.blocked=true;test.check(!profiles.openEditor("all",""),"busy network operation blocks editor");
            console.log("PASS: actual NetworkService/NetworkProfiles load and reject contextless/foreign/busy actions; no device mutation");Qt.quit();
        }
    }
}
