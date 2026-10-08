import QtQuick
import Quickshell
import "services"
Scope {
    id:test
    property int phase:0
    property int ticks:0
    InsightsService {id:service;active:true;section:"console"}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw new Error(msg);}}
    Timer {
        interval:25;repeat:true;running:true
        onTriggered:{
            test.ticks++;test.check(test.ticks<400,"actual service completion timeout");
            if(test.phase===0 && service.tasksFor("console").length>0){
                test.check(service.runTask("console","safe-task"),"actual console task start");test.phase=1;
            } else if(test.phase===1 && service.actionState!=="running"){
                test.check(service.actionState==="succeeded","silent console helper result verified");
                test.check(service.payloads.consoleResult.data.publicationDisabled===true,"legacy Eww publication disabled");
                test.check(service.payloads.consoleResult.data.correctRoot===true,"collector config root is authoritative");
                service.section="diagnostics";test.phase=2;
            } else if(test.phase===2 && service.tasksFor("diagnostics").length>0){
                test.check(service.runTask("diagnostics","safe-task"),"actual diagnostics task start");test.phase=3;
            } else if(test.phase===3 && service.actionState!=="running"){
                test.check(service.actionState==="failed","exit-zero JSON failure preserved");
                test.check(service.payloads.diagnosticsResult.ok===false,"failed evidence retained");
                console.log("PASS: actual InsightsService process adapters preserve silent console completion, failed JSON and disabled fallback publication; private helpers only");Qt.quit();
            }
        }
    }
}
