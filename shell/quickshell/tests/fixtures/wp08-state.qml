import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Services.Notifications
import "../../services" as Services
import "../../services/CpuSample.js" as Samples
import "../../components/notifications" as Notifications
import "../../components" as Components

Window {
    id:test;visible:true;width:460;height:600
    TestCase {id:input;when:false}
    Services.SystemMetrics {id:metrics}
    QtObject {id:session;property bool busy:false;property bool hasSchedule:false;property var schedule:({});property int remainingSeconds:0;property string remainingText:"";property real progress:0;property string error:""}
    Services.NotificationService {id:notifications;sessionService:session}
    Notifications.NotificationList {id:list;anchors.fill:parent;notifications:notifications}
    Components.NotificationToast {id:toast;targetScreen:null;notifications:notifications;visible:false}
    function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}console.log("PASS: "+message);}
    function record(id,summary,urgency,transient){return {id:id,appName:"Fixture",desktopEntry:"fixture.desktop",summary:summary,body:"Private inert detail",urgency:urgency,resident:true,transient:transient,actions:[],tracked:false};}
    function hasText(item,value){if(item.text===value)return true;for(const child of item.children||[])if(hasText(child,value))return true;return false;}
    function net(name,rx,tx){return name+": "+rx+" 0 0 0 0 0 0 0 "+tx+" 0 0 0 0 0 0 0\n";}
    Timer {interval:300;running:true;onTriggered:{
        metrics.previousCpuTotal=1000;metrics.previousCpuIdle=500;metrics.ready=true;metrics.cpuPercent=37;
        metrics.parseCpu("cpu 10 0 10 20 0 0 0 0\ncpu0 10 0 10 20 0 0 0 0");test.check(!metrics.ready,"CPU reset invalidates previous percentage");
        metrics.parseMemory("MemTotal: 1000 kB\nMemAvailable: 400 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB");test.check(metrics.memoryTotalKib===1000 && metrics.memoryPercent===60,"valid memory and zero swap remain valid");
        metrics.parseMemory("");test.check(!metrics.memory.available && metrics.memoryTotalKib===0,"malformed memory cannot retain an available history sample");
        test.check(!Samples.memory("MemTotal: 1000 kB").available && !Samples.memory("MemTotal: 1000 kB\nMemAvailable: 2000 kB").available,"missing/impossible available memory is rejected");
        test.check(!Samples.memory("MemTotal: 1000 kB\nMemAvailable: 400 kB\nSwapTotal: 100 kB").swapAvailable,"missing swap free is unknown rather than NaN");
        metrics.parseNetwork("",100);metrics.parseNetwork("",101);test.check(!metrics.networkReady && metrics.previousNetworkAt===0,"empty network readings remain unavailable rather than zero");
        metrics.parseNetwork(net("eth-fixture",0,0),102);metrics.parseNetwork(net("eth-fixture",0,0),103);test.check(metrics.networkReady && metrics.networkRxKib===0,"genuine idle network delta is zero");
        metrics.parseNetwork(net("new-fixture",10000,10000),104);test.check(!metrics.networkReady,"interface-set changes warm a new delta");
        metrics.parseNetwork(net("new-fixture",0,0),105);test.check(!metrics.networkReady,"network counter reset is unavailable");
        test.check(Samples.cores([{id:0,total:100,idle:0}],[{id:0,total:80,idle:10}])[0].percent===null,"invalid core idle delta is unknown");
        notifications.receive(test.record(1,"One",NotificationUrgency.Normal,false));const before=notifications.toastGeneration;input.wait(5);test.check(test.hasText(toast.contentItem,"One"),"offscreen toast initially renders admitted notification");
        notifications.setDnd(true);notifications.receive(test.record(2,"Critical fixture",NotificationUrgency.Critical,false));notifications.receive(test.record(3,"Transient fixture",NotificationUrgency.Normal,true));
        input.wait(5);test.check(test.hasText(toast.contentItem,"One") && !test.hasText(toast.contentItem,"Critical fixture"),"DND arrivals cannot replace the already presented toast");
        test.check(notifications.toastGeneration===before && notifications.history.length===2,"DND still suppresses critical/transient popups and retains only non-transient history");
        const history=notifications.history,unread=notifications.unreadCount;list.search="CRITICAL";input.wait(30);
        test.check(list.filteredHistory.length===1 && list.filteredHistory[0]===history[0] && notifications.unreadCount===unread,"shared search is case-insensitive and preserves object/read state");
        list.search="absent";test.check(list.filteredHistory.length===0 && notifications.history===history,"no-match search does not delete history");
        list.search="fixture.desktop";test.check(list.filteredHistory.length===2,"desktop-entry attribution is searchable without granting trust");
        list.search="";notifications.setDnd(false);test.check(notifications.toastGeneration===before,"turning off DND does not replay suppressed popups");
        console.log("RESULT: actual metrics and shared notification history/DND pass; private store and synthetic counters only");Qt.exit(0);
    }}
}
