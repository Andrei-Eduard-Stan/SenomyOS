import QtQuick
import QtQuick.Controls
import "../config" as Config
import "DirectoryFreshness.js" as Freshness
import "DirectoryModel.js" as Directory
PerformanceWorkspaceWindow {
 id:root;interactionCoordinator:state;frameKey:"dashboard";title:"Performance"
 required property var state
 required property var performance
 required property var metrics
 required property var battery
 required property var network
 property var insights:null
 readonly property bool trafficAvailable:metrics.networkReady!==undefined?metrics.networkReady:metrics.ready
 readonly property var telemetry:performance.telemetry || ({memory:{swapAvailable:false},pressure:{available:false}})
 property var pageState:({})
 property string objectView:""
 property string selectedNode:"overview"
 property double now:Date.now()
 property double briefingNow:now
 readonly property string observationKind:activeSection==="processes"?"Process sample":["gpu","storage","network"].includes(activeSection) && !(activeSection==="storage" && objectView==="io") && !(activeSection==="network" && objectView==="traffic")?"Inventory":"Session sample"
 Timer {interval:1000;running:root.requestedOpen;repeat:true;onTriggered:root.now=Date.now()}
 requestedOpen:!state.capturePaused && state.activePrimary==="performance" && state.primaryScreen===(targetScreen?targetScreen.name:"")
 replacementOpening:state.activePrimary!=="" && state.activePrimary!=="performance"
 activeSection:state.performanceSection
 sections:[{id:"overview",label:"Overview",glyph:"\uf201"},{id:"cpu",label:"CPU",glyph:"\uf2db"},{id:"gpu",label:"GPU",glyph:"\uf108"},{id:"memory",label:"Memory",glyph:"\uf538"},{id:"storage",label:"Storage",glyph:"\uf0a0"},{id:"network",label:"Network",glyph:"\uf6ff"},{id:"processes",label:"Processes",glyph:"\uf03a"},{id:"services",label:"Services",glyph:"\uf085"},{id:"diagnostics",label:"Diagnostics",glyph:"\uf0f1"},{id:"console",label:"Console",glyph:"\uf120"},{id:"reports",label:"Reports",glyph:"\uf15c"},{id:"benchmarks",label:"Benchmarks",glyph:"\uf3fd"}]
 directoryNodes:Directory.performance()
 activeNode:currentViews.length?selectedNode:activeSection
 readonly property var views:({cpu:["utilisation","cores","frequency","thermals","processes"],gpu:["utilisation","memory","thermals"],memory:["physical","swap","pressure","processes"],storage:["filesystems","devices","io","health"],network:["traffic","interfaces","connections","dns"]})
 readonly property var currentViews:views[activeSection] || []
 readonly property bool showHistory:["overview","cpu"].includes(activeSection) && objectView!=="processes" || activeSection==="memory" && objectView==="physical" || activeSection==="storage" && objectView==="io" || activeSection==="network" && objectView==="traffic"
 readonly property double observedAt:activeSection==="processes"?(performance.processesObservedAt || 0):["gpu","storage","services"].includes(activeSection) || activeSection==="cpu" && objectView==="thermals" || activeSection==="network" && objectView!=="traffic"?(performance.detailsObservedAt || 0):(telemetry.observedAt || metrics.observedAt || 0)
 function readState(route,key,fallback){const saved=pageState[route] || {};return saved[key]===undefined?fallback:saved[key];}
 function remember(route,key,value){const next=Object.assign({},pageState);next[route]=Object.assign({},next[route] || {});next[route][key]=value;pageState=next;}
 function navigate(route){if(state.allowInteraction())state.performanceSection=route;}
 function selectView(view){if(state.allowInteraction()){objectView=view;selectedNode=activeSection+"/"+view;remember(activeSection,"view",view);}}
 function inspectProcess(row){if(!row || !state.allowInteraction())return;state.performanceSection="processes";performance.selectProcess(row.pid,row.name);}
 function number(value,decimals){return value===undefined || value===null || !Number.isFinite(Number(value))?"Unavailable":Number(value).toFixed(decimals===undefined?1:decimals);}
 function peak(values,floor){return Math.max(floor || 1,...(values || []).filter(v=>v!==null && Number.isFinite(Number(v))).map(Number));}
 function formatBytes(bytes){if(bytes===null || bytes===undefined || !Number.isFinite(Number(bytes)))return "Unavailable";const value=Number(bytes);return value>=1099511627776?(value/1099511627776).toFixed(1)+" TiB":value>=1073741824?(value/1073741824).toFixed(1)+" GiB":value>=1048576?(value/1048576).toFixed(1)+" MiB":Math.round(value/1024)+" KiB";}
 function payload(route){return insights?(insights.payloads[route] || {ok:false,data:{}}):{ok:false,data:{}};}
 function data(route){return payload(route).data || {};}
 onActiveSectionChanged:{objectView=readState(activeSection,"view",(views[activeSection] || [""])[0]);selectedNode=activeSection+(objectView?"/"+objectView:"");}
 Component.onCompleted:{objectView=readState(activeSection,"view",(views[activeSection] || [""])[0]);}
 onCloseRequested:state.closePrimary()
 onSurfaceRequested:kind=>state.showPrimary(kind,targetScreen?targetScreen.name:"",kind==="performance"?state.performanceSection:state.insightsSection)
 onSectionRequested:section=>root.navigate(section)
 onNodeRequested:node=>{if(!state.allowInteraction() || !node.route)return;state.performanceSection=node.route;root.selectView(node.view || root.readState(node.route,"view",(root.views[node.route] || [""])[0]));}
 backHandler:function(){return pageLoader.item && typeof pageLoader.item.back==="function"?pageLoader.item.back():false;}
    function pageReport() {
        const section=state.performanceSection,details=performance.details || {};
        const report={surface:"performance",page:section,view:objectView || null,
            captured_at:Date.now(),history_window_seconds:performance.historySeconds || 60,source_error:performance.error || null,
            observed_at:{inventory:performance.detailsObservedAt || null,
                telemetry:telemetry.observedAt || null,processes:performance.processesObservedAt || null}};
        function processes(limit) {
            const sort=section==="cpu" && pageLoader.item ? pageLoader.item.sortKey || "cpu" : section==="memory" ? "memory" : performance.processSort || "cpu";
            const key=sort==="memory"?"memory_mib":"cpu_percent";
            const rows=(performance.processes || []).slice().sort((a,b)=>sort==="name"?String(a.name).localeCompare(String(b.name)):Number(b[key] || 0)-Number(a[key] || 0));
            return {sort:sort,total:rows.length,included:Math.min(limit,rows.length),rows:rows.slice(0,limit).map(p=>({pid:p.pid,name:p.name,cpu_percent:p.cpu_percent,memory_mib:p.memory_mib,memory_percent:p.memory_percent,state:p.state}))};
        }
        const histories={timestamps:(performance.sampleTimes || []).slice(),cpu_percent:(performance.cpuHistory || []).slice(),memory_percent:(performance.memoryHistory || []).slice(),rx_kib_s:(performance.rxHistory || []).slice(),tx_kib_s:(performance.txHistory || []).slice(),temperature_celsius:(performance.temperatureHistory || []).slice(),frequency_ghz:(performance.frequencyHistory || []).slice(),disk_busy_percent:(performance.diskBusyHistory || []).slice()};
        const memory={used_kib:metrics.memoryTotalKib>0?metrics.memoryUsedKib:null,total_kib:metrics.memoryTotalKib>0?metrics.memoryTotalKib:null,percent:metrics.memoryTotalKib>0?metrics.memoryPercent:null,physical_and_swap:telemetry.memory,pressure:telemetry.pressure};
        const network={interface:details.network,sockets:details.sockets,traffic_available:root.trafficAvailable,rx_kib_s:root.trafficAvailable?metrics.networkRxKib:null,tx_kib_s:root.trafficAvailable?metrics.networkTxKib:null};
        const cpu={inventory:details.cpu_inventory,utilisation_percent:metrics.ready?metrics.cpuPercent:null,cores:telemetry.cores,frequency:telemetry.frequency,base_frequency:telemetry.baseFrequency,thermals:(details.health || {}).temperature,processes:processes(8)};
        switch(section){
        case "cpu": report.data=cpu;report.context={memory:memory,storage:details.storage,network:network};report.history={timestamps:histories.timestamps,cpu_percent:histories.cpu_percent,temperature_celsius:histories.temperature_celsius,frequency_ghz:histories.frequency_ghz};break;
        case "gpu":report.data=details.graphics;break;
        case "memory":report.data=memory;report.history={timestamps:histories.timestamps,memory_percent:histories.memory_percent};report.processes=processes(100);break;
        case "storage":report.data=details.storage;const disk=metrics.history && metrics.history.disk;report.io=disk?{available:disk.available,busy_percent:disk.busyPercent,busiest_device:disk.busiestDevice,observed_at:disk.previousAt || null}:{available:false};report.history={timestamps:histories.timestamps,disk_busy_percent:histories.disk_busy_percent};break;
        case "network":report.data=network;report.history={timestamps:histories.timestamps,rx_kib_s:histories.rx_kib_s,tx_kib_s:histories.tx_kib_s};break;
        case "processes":report.data=processes(100);break;
        case "services":report.data=details.services;break;
        case "overview":report.data={cpu:cpu,memory:memory,storage:details.storage,network:network,health:details.health};report.history=histories;break;
        case "benchmarks":report.data=performance.benchmarkStatus;break;
        default:report.data={available:false,message:"Use the report menu in the displayed Insights task or report."};
        }
        return report;
    }


 Column {id:header;width:parent.width;spacing:10
  InsightsWorkspaceTitle {visible:!["diagnostics","console","reports"].includes(root.activeSection);width:parent.width;title:(root.sections.find(s=>s.id===root.activeSection) || {}).label || "Overview";detail:["diagnostics","console","reports","benchmarks","services"].includes(root.activeSection)?"":root.observedAt>0?root.observationKind+" "+Freshness.ageLabel(root.observedAt,root.now)+(root.now-root.observedAt>10000?" · older evidence":""):"Waiting for an observation";actions:[ComponentReportMenu {objectName:"performance-page-report-menu";visible:!["diagnostics","console","reports"].includes(root.activeSection);componentKey:"performance-page-"+root.activeSection;targetItem:root.contentArea;report:root.pageReport()}]}
  Text {visible:!!root.performance.error && !["diagnostics","console","reports"].includes(root.activeSection);width:parent.width;text:root.performance.error;textFormat:Text.PlainText;wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.Theme.warning}
  Flow {width:parent.width;visible:root.currentViews.length>0;spacing:8
   Repeater {model:root.currentViews
    QuietButton {required property string modelData;objectName:"performance-view-"+modelData;text:({io:"Disk activity",dns:"DNS",utilisation:"Utilisation"})[modelData] || modelData.charAt(0).toUpperCase()+modelData.slice(1);active:root.objectView===modelData;Accessible.checkable:true;Accessible.checked:active;enabled:!root.state.modalActive;onClicked:root.selectView(modelData)}
   }
  }
  Flow {visible:root.showHistory;width:parent.width;spacing:8
   Repeater {model:[{seconds:60,label:"60s"},{seconds:300,label:"5 min"},{seconds:900,label:"15 min"}]
    QuietButton {required property var modelData;objectName:"performance-history-"+modelData.seconds;text:modelData.label;active:root.performance.historySeconds===modelData.seconds;accessibleLabel:"Show "+modelData.label+" of shared session history";Accessible.checkable:true;Accessible.checked:active;onClicked:root.performance.historySeconds=modelData.seconds}
   }
  }
 }
 Loader {id:pageLoader;onLoaded:root.revealContent();objectName:"performance-route-page";active:root.requestedOpen;anchors.left:parent.left;anchors.right:parent.right;anchors.top:header.bottom;anchors.topMargin:header.height>0?16:0;anchors.bottom:parent.bottom
  sourceComponent:{switch(root.activeSection){case "cpu":case "gpu":case "memory":case "storage":case "network":return resourcePage;case "processes":return processPage;case "services":return servicesPage;case "benchmarks":return benchmarkPage;case "diagnostics":case "console":return root.insights?taskPage:bridgePage;case "reports":return root.insights?reportsPage:bridgePage;default:return overviewPage;}}
 }
 Component {id:overviewPage;PerformanceWorkspaceOverview {workspace:root}}
 Component {id:resourcePage;PerformanceWorkspaceResource {workspace:root}}
 Component {id:processPage;PerformanceWorkspaceProcesses {workspace:root}}
 Component {id:servicesPage;PerformanceWorkspaceServices {workspace:root}}
 Component {id:benchmarkPage;PerformanceWorkspaceBenchmarks {workspace:root}}
 Component {id:taskPage;InsightsWorkspaceTasks {workspace:root;domain:root.activeSection}}
 Component {id:reportsPage;InsightsWorkspaceReports {workspace:root}}
 Component {id:bridgePage;Column {spacing:12;Text {width:parent.width;text:"The shared evidence provider is unavailable. Open Insights to review its availability.";wrapMode:Text.WordWrap;font.family:Config.DirectoryStyle.bodyFont;font.pixelSize:Config.DirectoryStyle.bodySize;color:Config.DirectoryStyle.muted}QuietButton {text:"Open Insights";onClicked:root.surfaceRequested("insights")}}}
}
