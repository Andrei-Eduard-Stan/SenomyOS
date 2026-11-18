import QtQuick
import Quickshell
import "services"
Scope {
    id:test
    DesktopSettings{id:settings;queryEnabled:false}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw new Error(msg);}}
    Timer {interval:100;running:true;onTriggered:{test.check(!settings.actions.request("default","text/plain","foreign.desktop"),"inactive preference rejected");settings.active=true;settings.context="fixture";test.check(!settings.actions.request("execute","foreign.desktop",""),"unsupported desktop action rejected");console.log("PASS: actual DesktopSettings loads and rejects inactive/unsupported actions; query-disabled service only");Qt.quit();}}
}
