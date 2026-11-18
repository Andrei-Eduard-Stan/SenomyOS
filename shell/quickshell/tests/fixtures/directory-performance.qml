import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "config" as Config
import "services"
Window {
    id: test
    visible:true; width:1580; height:820
    property int mutations:0
    property int phase:0
    property string out:Quickshell.env("SENOMY_QA_OUT")
    property var stateProvider:state
    property var performanceProvider:performance
    TestCase { id: input; when:false }
    QtObject {
        id: state
        property string activePrimary:"performance"
        property string primaryScreen:"fixture"
        property string performanceSection:"cpu"
        property string insightsSection:"briefing"
        function showPrimary(kind,screen,section){primaryScreen=screen;activePrimary=kind;}
        function allowInteraction(){return true;}
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
        property bool active:state.activePrimary === "performance"
        property bool benchmarkPageActive:active && state.performanceSection === "benchmarks"
        property bool processPageActive:active && state.performanceSection === "processes"
        property string actionContext:active ? "performance:" + state.performanceSection + ":" + state.primaryScreen : ""
        property var managedServices:services
        property string error:""
        property double detailsObservedAt:Date.now()
        property double processesObservedAt:Date.now()
        property var sampleTimes:Array.from({length:60},(_,i)=>Date.now()-(59-i)*1000)
        property var details:({cpu_inventory:{architecture:"x86_64",model:"Fixture CPU / 8 logical processors",logical_cpus:8,physical_cores:4,sockets:1,max_mhz:3600,virtualization:"VT-x"},health:{hostname:"fixture",kernel:"test-kernel",temperature:{available:true,celsius:48,source:"Fixture hwmon"}},services:{available:true,failed_total:0},storage:{percent:44,used_bytes:47000000000,total_bytes:100000000000,mount:"/",filesystem:"ext4",source:"/dev/fixture0p1",devices:[{name:"fixture0",model:"Fixture device",size_bytes:100000000000,transport:"Fixture",partition_count:2}]},graphics:{available:false},network:{available:true,interface:"fixture0",state:"connected",kind:"ethernet",mtu:1500,ipv4:"192.0.2.1",ipv6:null,gateway:"192.0.2.254"},sockets:{available:true,used:12,tcp:{established:3,listening:2},udp_in_use:4},sensors:{temperatures:[]}})
        property var telemetry:({observedAt:Date.now(),cores:Array.from({length:8},(_,i)=>({id:i,percent:12+i*4})),frequency:{available:true,mhz:2400},baseFrequency:{available:true,mhz:1800},memory:{swapAvailable:true,swapTotalKib:8000000,swapUsedKib:1000000},pressure:{available:true,avg10:0.05}})
        property var cpuHistory:Array.from({length:60},(_,i)=>17+Math.abs(Math.sin(i*1.2))*10+(i===39?28:0))
        property var temperatureHistory:Array.from({length:60},(_,i)=>45+Math.sin(i/6)*4)
        property var frequencyHistory:Array.from({length:60},(_,i)=>1.8+Math.abs(Math.sin(i/5)))
        property var diskBusyHistory:Array.from({length:60},(_,i)=>10+Math.abs(Math.sin(i/5))*20)
        function coreHistory(id){return sampleTimes.map((_,i)=>10+id+i/5);}
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
        property var processes:Array.from({length:12},(_,i)=>({pid:100+i,name:"Process "+i,rank:i+1,cpu_percent:12-i,memory_percent:1,memory_mib:10,state:"S",user:"fixture"}))
        property string processActionState:"idle"
        property string processActionMessage:""
        property var benchmarkStatus:({state:"idle",logs:[]})
        property var benchmarkPlans:({})
        property string pendingBenchmark:"quick"
        property string benchmarkActionState:"idle"
        function selectProcess(pid,name) { selectedProcessPid=pid;selectedProcessName=name; }
        function configureProcesses(kind,value) { test.mutations++; }
        property string pendingProcessAction:""
        function requestProcessSignal(action){pendingProcessAction=action;processActionState="pending";}
        function requestProcessTermination() { processActionState="pending"; }
        function cancelProcessAction() { processActionState="idle"; }
        function confirmProcessAction() { test.mutations++; }
        function requestBenchmark(profile) { benchmarkActionState="pending"; }
        function cancelBenchmarkRequest() { benchmarkActionState="idle"; }
        function confirmBenchmark() { test.mutations++; }
        function stopBenchmark() { test.mutations++; }
    }
    PerformanceDashboard {
        id: panel;anchors.fill:parent;targetScreen:({name:"fixture"});state:state;performance:performance
        metrics:({ready:true,cpuPercent:17,memoryPercent:23,memoryTotalKib:32000000,memoryUsedKib:7360000,uptimeLabel:"3h 33m",networkRxKib:3,networkTxKib:0.9})
        battery:({label:"Fixture",detail:"Fixture"});network:({label:"Fixture",detail:"Fixture"})
    }
    Component {
        id: otherOutput
        PerformanceDashboard {
            targetScreen:({name:"second-fixture"});state:test.stateProvider;performance:test.performanceProvider
            metrics:panel.metrics;battery:panel.battery;network:panel.network
            visible:false
        }
    }
    DirectoryFreshness {id:clockProbe;visible:false}
    function check(ok,message) { if(!ok) {console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);} }
    function inside(item,parent) {while(item){if(item===parent)return true;item=item.parent;}return false;}
    Timer {
        id:phaseTimer
        interval:450;running:true;repeat:true
        onTriggered:{
            phaseTimer.stop();
            if(test.phase===0){
                clockProbe.now=1;clockProbe.observedAt=Date.now();test.check(clockProbe.now>=clockProbe.observedAt,"new observation refreshes freshness immediately");
                clockProbe.now=1;clockProbe.visible=true;test.check(clockProbe.now>=clockProbe.observedAt,"reopening refreshes freshness before timer");clockProbe.visible=false;
                const nav=panel.navigation;
                nav.query="temperature";input.wait(30);
                test.check(nav.rows.some(n=>n.id==="cpu/thermals") && nav.rows.some(n=>n.id==="gpu/thermals") && nav.rows.some(n=>n.id==="storage/health"),"search exposes ancestors and tagged temperature objects");
                nav.query="does-not-exist";input.wait(30);test.check(nav.rows.length===0,"search empty state");nav.query="";
                const cpu=nav.rows.find(n=>n.id==="cpu");nav.toggle(cpu);input.wait(20);test.check(!nav.rows.some(n=>n.id==="cpu/cores"),"CPU collapses");nav.toggle(cpu);
                input.wait(30);nav.focusSection();input.wait(40);input.keyClick(Qt.Key_Down);input.wait(40);input.keyClick(Qt.Key_Return);input.wait(30);
                test.check(panel.objectView==="cores" && state.performanceSection==="cpu","keyboard activates nested CPU view");
                for(const route of ["cpu","memory","storage","network"]){
                    const group=panel.directoryNodes[route==="cpu"?1:route==="memory"?2:route==="storage"?3:4];
                    const leaves=route==="cpu"?group.children[0].children:group.children;
                    for(const leaf of leaves){
                        panel.nodeRequested(leaf);panel.sectionRequested(leaf.route);input.wait(40);
                        panel.captureItem.grabToImage(result=>result.saveToFile(test.out+"/leaf-"+leaf.id.replace("/","-")+".png"));input.wait(60);
                        test.check(panel.objectView===leaf.view,"leaf selection retains focused view "+leaf.id);
                        if(leaf.id==="cpu/frequency" || leaf.id==="cpu/thermals" || leaf.id==="storage/io"){
                            const label=leaf.id==="cpu/frequency"?"CPU FREQUENCY HISTORY":leaf.id==="cpu/thermals"?"CPU/SOC TEMPERATURE HISTORY":"DISK ACTIVE-TIME HISTORY";
                            const chart=input.findChild(panel.captureItem,"history-chart-"+label);
                            test.check(chart && chart.values.length===60 && chart.recordedSamples>0,"detailed history view uses matching real model timestamps "+leaf.id);
                            test.check(chart.unit===(leaf.id==="cpu/frequency"?"GHz":leaf.id==="cpu/thermals"?"°C":"%"),"history unit is explicit "+leaf.id);
                            if(leaf.id==="cpu/frequency")test.check(chart.axisLabel(0)==="3.6","frequency axis retains the fractional maximum instead of rounding to 4 GHz");
                        }
                        if(leaf.id==="cpu/cores"){
                            const button=input.findChild(panel.captureItem,"cpu-core-history-1");button.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(20);
                            const chart=input.findChild(panel.captureItem,"history-chart-CORE 1 UTILISATION HISTORY");test.check(chart && chart.values[0]===11,"per-core keyboard selection switches shared historical series");
                        }
                    }
                }
                state.performanceSection="cpu";panel.selectedNode="cpu/utilisation";panel.objectView="utilisation";input.wait(40);
                const switchTarget=input.findChild(panel.captureItem,"switch-insights");
                test.check(switchTarget!==null && switchTarget.visible,"persistent surface switch is visible");
                switchTarget.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(20);
                test.check(state.activePrimary==="insights" && state.primaryScreen==="fixture","keyboard switch uses exclusive primary controller");
                state.activePrimary="performance";input.wait(20);
                                const pageMenu=input.findChild(panel.captureItem,"performance-page-report-menu");
                test.check(pageMenu!==null && pageMenu.report.page==="cpu","CPU parent report menu is available");
                pageMenu.run("text");input.wait(500);
                test.check(!pageMenu.busy && pageMenu.status.startsWith("Saved "),"parent CPU report text export succeeds");
                const parentReport=panel.pageReport();
                test.check(parentReport.data.inventory.logical_cpus===8 && parentReport.data.cores.length===8 && parentReport.history.timestamps.length>0,"CPU report collates inventory, cores and timestamped history");
                state.performanceSection="gpu";input.wait(20);
                test.check(panel.pageReport().data.available===false,"GPU parent report preserves unavailable status");
                state.performanceSection="cpu";input.wait(20);
                const history=input.findChild(panel.captureItem,"history-chart-CPU UTILISATION");
                const cpuPage=input.findChild(panel.captureItem,"cpu-object-page");
                const originalProcesses=performance.processes;
                performance.processes=[{pid:100,name:"Smaller",cpu_percent:9,memory_percent:4,memory_mib:10},{pid:101,name:"Larger",cpu_percent:1,memory_percent:1,memory_mib:200}];cpuPage.sortKey="memory";input.wait(20);
                test.check(cpuPage.sortedProcesses[0].pid===101,"memory sort uses resident MiB");
                test.check(input.findChild(panel.captureItem,"process-sample-heading").text==="TOP PROCESSES / MEMORY","process heading names selected sort");
                panel.captureItem.grabToImage(result=>result.saveToFile(test.out+"/performance-memory-sort.png"));input.wait(60);
                performance.processes=originalProcesses;cpuPage.sortKey="cpu";input.wait(20);
                history.forceActiveFocus();input.wait(20);input.keyClick(Qt.Key_End);input.wait(20);
                test.check(history.inspectedIndex===59 && history.sampleReadout.includes("%") && history.sampleReadout.includes("//"),"keyboard history readout contains value and timestamp");
                input.keyClick(Qt.Key_Left);input.wait(20);test.check(history.inspectedIndex===58,"history keyboard moves to previous sample");
                test.check(history.recordedSamples>0 && history.collectionLabel.includes("/60s"),"history exposes measured collection span");
                const sampleTimes=performance.sampleTimes.slice(),sampleValues=performance.cpuHistory.slice(),chosenAt=history.inspectedAt;
                performance.cpuHistory=sampleValues.slice(1).concat([18]);performance.sampleTimes=sampleTimes.slice(1).concat([Date.now()]);input.wait(20);
                test.check(history.inspectedAt===chosenAt && history.inspectedIndex===57,"history selection follows timestamp as samples roll");
                performance.cpuHistory=sampleValues;performance.sampleTimes=sampleTimes;input.wait(20);
                performance.cpuHistory=[12,16];performance.sampleTimes=[Date.now()-1000,Date.now()];input.wait(20);
                test.check(input.findChild(history,"history-collecting-note").visible,"partial history explains unrecorded region");
                panel.captureItem.grabToImage(result=>result.saveToFile(test.out+"/performance-history-collecting.png"));input.wait(60);
                performance.cpuHistory=sampleValues;performance.sampleTimes=sampleTimes;input.wait(20);
                history.step(-1);
                panel.captureItem.grabToImage(result=>result.saveToFile(test.out+"/performance-history-readout.png"));input.wait(60);
                input.keyClick(Qt.Key_Escape);input.wait(20);test.check(history.inspectedIndex===-1 && state.activePrimary==="performance","Escape clears inspection before surface");
                const process=input.findChild(panel.captureItem,"cpu-process-100");input.mouseClick(process);input.wait(40);
                test.check(state.performanceSection==="processes" && performance.selectedProcessPid===100 && performance.processActionState==="idle","CPU process shortcut selects details without termination");
                const manager=input.findChild(panel.captureItem,"process-manager");
                const managerList=input.findChild(manager,"process-manager-list");
                test.check(managerList.count===12 && managerList.height>100,"process manager has a populated nonzero-height table");
                manager.query="Process 11";input.wait(30);test.check(managerList.count===1,"local process search filters rows");manager.query="";input.wait(30);
                const force=input.findChild(manager,"process-action-kill");input.mouseClick(force);input.wait(30);
                test.check(performance.processActionState==="pending" && performance.pendingProcessAction==="kill","force kill opens explicit review without execution");
                const cancel=input.findChild(manager,"process-cancel");input.mouseClick(cancel);input.wait(30);test.check(performance.processActionState==="idle","process review cancels without execution");

                test.width=520;test.height=740;input.wait(60);
                test.check(manager.compact && input.findChild(manager,"process-manager-inspector").width>450,"narrow inspector uses available width");
                panel.captureItem.grabToImage(result=>result.saveToFile(test.out+"/process-manager-narrow-inspector.png"));input.wait(80);
                performance.selectProcess(0,"");test.width=390;input.wait(60);
                test.check(managerList.visible && managerList.height>100,"portrait manager retains visible rows");
                managerList.forceActiveFocus();input.keyClick(Qt.Key_End);input.wait(30);test.check(managerList.currentIndex===11,"process table keyboard reaches final row");
                panel.captureItem.grabToImage(result=>result.saveToFile(test.out+"/process-manager-portrait-list.png"));input.wait(80);
                test.width=1580;test.height=820;input.wait(40);
                state.performanceSection="cpu";panel.objectView="utilisation";nav.focusSection();input.wait(40);
            }
            const names=["cpu-wide","overview","gpu","memory","storage","network","processes","services","diagnostics","console","reports","benchmarks","cpu-narrow","cpu-touch","cpu-portrait"];
            if(test.phase>=names.length){console.log("PASS: directory search/collapse/keyboard, all Performance routes, narrow/touch captures; no mutations");Qt.quit();return;}
            panel.captureItem.grabToImage(result=>{
                test.check(result.saveToFile(test.out+"/performance-"+names[test.phase]+".png"),"save screenshot");
                test.phase++;
                if(test.phase>=names.length){phaseTimer.start();return;}
                const next=names[test.phase];
                state.performanceSection=next.startsWith("cpu")?"cpu":next;
                panel.objectView=state.performanceSection==="cpu"?"utilisation":"";
                panel.selectedNode=state.performanceSection==="cpu"?"cpu/utilisation":state.performanceSection;
                if(test.phase===12){
                    test.width=520;test.height=740;input.wait(30);
                    const toggle=input.findChild(panel.captureItem,"directory-toggle");
                    input.mouseClick(toggle);input.wait(40);
                    test.check(panel.directoryOpen && panel.navigation.visible,"narrow directory opens by visible control");
                    panel.captureItem.grabToImage(result=>result.saveToFile(test.out+"/performance-directory-drawer.png"));input.wait(60);
                    input.keyClick(Qt.Key_Escape);input.wait(30);
                    test.check(!panel.directoryOpen && state.activePrimary==="performance","Escape dismisses drawer before surface");
                    input.mouseClick(toggle);input.wait(30);
                    panel.navigation.activate({id:"memory/pressure",route:"memory",view:"pressure"});input.wait(30);
                    test.check(state.performanceSection==="memory" && panel.objectView==="pressure" && !panel.directoryOpen,"drawer selection opens focused leaf and closes drawer");
                    state.performanceSection="cpu";panel.objectView="utilisation";panel.selectedNode="cpu/utilisation";
                }
                if(test.phase===13){test.width=720;panel.touchMode=true;Config.DirectoryStyle.touchMode=true;}
                if(test.phase===14){test.width=390;test.height=820;}
                phaseTimer.start();
            });
            test.check(test.mutations===0,"opening routes must not mutate devices");
        }
    }
}
