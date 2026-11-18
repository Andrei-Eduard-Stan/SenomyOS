import QtQuick
import QtTest
import Quickshell
import "../../services/calendar" as Calendar
Scope {
    id:test
    property bool uncertain:false
    TestCase {id:input;when:false}
    Calendar.CalendarService {
        id:calendar
        onRequestFinished:(id,operation,result,ok)=>{if(operation==="save"&&!ok&&String(result.error).includes("unverified"))test.uncertain=true;}
    }
    function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}console.log("PASS: "+message);}
    Timer {interval:200;running:true;onTriggered:{
        test.check(calendar.available,"private fake calendar connected");
        test.check(calendar.request("save",{fixture:true}).length>0 && calendar.busy,"pending inert save is tracked");input.wait(250);
        test.check(!calendar.busy && test.uncertain && Object.keys(calendar.pending).length===0,"provider loss releases pending operation with uncertain outcome");
        input.wait(5300);test.check(calendar.available && !calendar.busy,"read-only reconnect recovers without replaying a mutation");
        console.log("RESULT: actual calendar reconnect and pending failure pass; no real calendar data");Qt.exit(0);
    }}
}
