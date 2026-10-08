import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services"
Window {
    id: test
    visible:true; width:1580; height:820
    property int mutations:0
    property int curatedCalls:0
    QtObject {
        id: sharedInsights
        property string actionState:"idle"
        property string actionMessage:""
        property string actionDomain:""
        property bool busy:false
        property var statuses:({})
        property var payloads:({reports:{data:{exists:true,latest:{profile_label:"FIXTURE"},history_count:1,preview:[]}},consoleResult:{data:{title:"Fixture",output:[]}},diagnosticsResult:{data:{title:"Fixture",output:[]}}})
        function tasksFor(domain){return Array.from({length:24},(_,i)=>({id:"task-"+i,code:"FIX",title:"Task "+i,summary:"Safe fixture"}));}
        function refresh(route,result){return true;}
        function runTask(domain,id){test.curatedCalls++;test.check(domain==="console"&&id==="task-23","fixed curated task");}
        function generateReport(profile){test.curatedCalls++;}
        function openLatestReport(){test.curatedCalls++;}
    }
    TestCase { id: input; when:false }
    QtObject {
        id: state
        property string activePrimary:"performance"
        property string primaryScreen:"fixture"
        property string performanceSection:"overview"
        property string insightsSection:"briefing"
        function closePrimary() { activePrimary=""; }
    }
    QtObject { id: fakeRunner; property bool running:false; function exec(args) { test.mutations++; } }
    ServiceRestartActions {
        id: actions; active:true; context:"fixture"; helper:"fixture.py";runner:fakeRunner
        items:[{unit:"pipewire.service",state:"active",restartAllowed:true,token:"a".repeat(64),impact:"Fixture audio only"}]
    }
    QtObject {
        id: services
        property bool available:true
        property string error:""
        property var items:actions.items
        property var processService:actions.items[0]
        property var actions:actions
    }
    QtObject {
        id: performance
        property bool active:true
        property bool benchmarkPageActive:false
        property bool processPageActive:false
        property string actionContext:""
        property var managedServices:services
        property string error:""
        property var details:({})
        property var cpuHistory:[1,2]
        property var memoryHistory:[1,2]
        property var rxHistory:[1,2]
        property var txHistory:[1,2]
        property string processSort:"cpu"
        property string processFilter:"all"
        property int selectedProcessPid:0
        property string selectedProcessName:"Fixture"
        property var selectedProcess:({action_allowed:true,start_ticks:123})
        property string processDetailError:""
        property var processSummary:({process_count:12,thread_count:12})
        property var processes:Array.from({length:12},(_,i)=>({pid:100+i,name:"Process "+i,rank:i+1,cpu_percent:1,memory_mib:10,state:"S",user:"fixture"}))
        property string processActionState:"idle"
        property string processActionMessage:""
        property var benchmarkStatus:({state:"idle",logs:[]})
        property var benchmarkPlans:({})
        property string pendingBenchmark:"quick"
        property string benchmarkActionState:"idle"
        function selectProcess(pid,name) { selectedProcessPid=pid;selectedProcessName=name; }
        function configureProcesses(kind,value) { test.mutations++; }
        function requestProcessTermination() { processActionState="pending"; }
        function cancelProcessAction() { processActionState="idle"; }
        function confirmProcessAction() { test.mutations++; }
        function requestBenchmark(profile) { benchmarkActionState="pending"; }
        function cancelBenchmarkRequest() { benchmarkActionState="idle"; }
        function confirmBenchmark() { test.mutations++; }
        function stopBenchmark() { test.mutations++; }
    }
    PerformanceDashboard {
        id: panel;anchors.fill:parent;targetScreen:({name:"fixture"});state:state;performance:performance;insights:sharedInsights
        metrics:({cpuPercent:10,memoryPercent:20,uptimeLabel:"Fixture",networkRxKib:1,networkTxKib:2})
        battery:({label:"Fixture",detail:"Fixture"});network:({label:"Fixture",detail:"Fixture"})
    }
    function check(ok,message) { if(!ok) {console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);} }
    function inside(item,parent) {while(item){if(item===parent)return true;item=item.parent;}return false;}
    Timer {
        interval:400;running:true
        onTriggered: {
            for(const size of [{w:1580,h:820},{w:900,h:600}]) {
                test.width=size.w;test.height=size.h;input.wait(40);
                for(const section of panel.sections) {
                    state.performanceSection=section.id;panel.navigation.focusSection();input.wait(50);
                    const seen=new Set();
                    for(let step=0;step<50;step++) {
                        input.keyClick(Qt.Key_Tab);input.wait(2);
                        const item=test.activeFocusItem;
                        if(item && test.inside(item,panel.contentArea)) {
                            if(item.modelData && item.modelData.name) seen.add(item.modelData.name);
                            const pos=item.mapToItem(panel.contentArea,0,0);
                            test.check(pos.y>=-1 && pos.y+item.height<=panel.contentArea.height+1,section.id+" focused control clipped at "+pos.y);
                        }
                    }
                    if(section.id==="processes") test.check(seen.size===12,"all twelve process rows reachable");
                }
            }
            state.performanceSection="services";input.wait(50);
            test.check(actions.request(actions.items[0]),"review requested");input.wait(20);
            test.check(test.activeFocusItem.objectName==="selectionCancel","service review defaults to Cancel");
            input.keyClick(Qt.Key_Return);input.wait(20);test.check(actions.actionState==="idle","Cancel works");
            state.performanceSection="processes";performance.selectedProcessPid=100;input.wait(50);
            performance.requestProcessTermination();input.wait(20);
            test.check(test.activeFocusItem.text==="CANCEL","terminate review defaults to Cancel");input.keyClick(Qt.Key_Return);
            test.check(performance.processActionState==="idle","terminate cancelled without mutation");
            test.check(test.mutations===0,"no provider mutation");
            state.performanceSection="console";input.wait(30);
            panel.navigation.focusSection();input.wait(30);
            for(let step=0;step<90;step++) {
                input.keyClick(Qt.Key_Tab);input.wait(2);
                if(test.activeFocusItem && test.activeFocusItem.text==="FIX // Task 23") {input.keyClick(Qt.Key_Return);break;}
            }
            test.check(test.curatedCalls===1,"shared last curated task keyboard activation");
            test.check(state.activePrimary==="performance","shared runner retains current primary surface");
            console.log("PASS: shared Performance Diagnostics/Console/Reports routes, keyboard tasks and guarded focus; fake providers only");Qt.quit();
        }
    }
}
