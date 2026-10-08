import QtQuick
import Quickshell
import "services"
Scope {
    id: test
    PerformanceService {
        id: service
        metrics: ({cpuPercent:1,memoryPercent:2,networkRxKib:0,networkTxKib:0})
    }
    function check(ok,msg) {if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw new Error(msg);}}
    Timer {
        interval:100;running:true
        onTriggered: {
            service.managedServices.queryEnabled=false;
            service.selectedProcessPid=100;service.selectedProcessName="Fixture";
            service.selectedProcess={action_allowed:true,start_ticks:123};service.processes=[{pid:100,name:"Fixture"}];
            test.check(!service.requestProcessTermination(),"inactive termination rejected");
            service.active=true;test.check(!service.requestProcessTermination(),"contextless termination rejected");
            service.actionContext="performance:processes:fixture";
            test.check(service.requestProcessTermination(),"termination review captured");
            service.actionContext="performance:overview:fixture";
            test.check(service.processActionState==="idle","route change cancels process review");
            test.check(!service.confirmProcessAction(),"old review cannot signal");
            test.check(service.requestProcessTermination(),"new review");service.active=false;
            test.check(service.processActionState==="idle","closing cancels process review");
            service.active=true;service.managedServices.actions.actionState="pending";
            test.check(!service.requestProcessTermination(),"service review blocks termination");
            service.managedServices.actions.actionState="idle";
            test.check(service.requestProcessTermination(),"review after idle");
            service.selectedProcess={action_allowed:true,start_ticks:124};
            test.check(!service.confirmProcessAction(),"changed process identity rejected");
            test.check(service.processActionState==="failed","changed identity explicit failure");
            console.log("PASS: actual PerformanceService closes stale process previews and rejects overlapping service reviews without actions");Qt.quit();
        }
    }
}
