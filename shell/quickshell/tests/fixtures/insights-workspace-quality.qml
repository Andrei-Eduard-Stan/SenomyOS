import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services"
import "config" as Config
Window {
 id:test;visible:true;width:1320;height:780;color:"#15181c"
 property int writes:0
 property int sessionOpens:0
 property bool baseline:Quickshell.env("SENOMY_INSIGHTS_PHASE")==="baseline"
 property double now:Date.now()
 TestCase {id:input;when:false}
 QtObject {id:state;property bool capturePaused:false;property bool modalActive:false;property string activePopup:"";property string activePrimary:"insights";property string primaryScreen:"fixture";property string insightsSection:"briefing";property string performanceSection:"overview";function allowInteraction(){return !modalActive;}function closePrimary(){activePrimary="";}function showPrimary(kind,screen,section){activePrimary=kind;primaryScreen=screen;}function escapeOverlay(){}}
 QtObject {id:query;property bool running:false;property var commands:[];function exec(args){commands=commands.concat([args]);}}
 QtObject {id:action;property bool running:false;property var commands:[];function exec(args){commands=commands.concat([args]);}}
 InsightsRequests {id:insights;queryRunner:query;actionRunner:action;sourceRoot:"/fixture";section:state.insightsSection}
 NotificationClearActions {id:clear;provider:notices;context:"insights:fixture"}
 QtObject {
  id:notices
  property var history:[{id:1,receivedAt:test.now-60000,summary:"Build finished",appName:"Terminal",desktopEntry:"terminal",body:"The local build completed. Review its output before continuing.",urgency:"Normal",unread:true},{id:2,receivedAt:test.now-300000,summary:"Meeting in 15 minutes",appName:"Calendar",desktopEntry:"calendar",body:"Design review · 14:30",urgency:"Normal",unread:true},{id:3,receivedAt:test.now-600000,summary:"Screenshot saved",appName:"Flameshot",desktopEntry:"flameshot",body:"Saved to your local picture folder.",urgency:"Normal",unread:false}]
  property var activeNotifications:[]
  readonly property int unreadCount:history.filter(n=>n.unread).length
  readonly property int activeCount:activeNotifications.length
  property bool serverEnabled:true
  property bool dnd:false
  property bool clearAvailable:true
  property var clearActions:clear
  property var commitment:null
  property var sessionService:({busy:false,error:"",schedule:{},progress:0,remainingSeconds:0,remainingText:"",cancelSchedule:function(){test.writes++;}})
  function openSessionRequested(){test.sessionOpens++;}
  function recordKey(record){return record?String(record.id)+"@"+String(record.receivedAt || 0):"";}
  function isLive(record){return false;}
  function markRead(record){const key=recordKey(record);history=history.map(n=>!record || recordKey(n)===key?Object.assign({},n,{unread:false}):n);test.writes++;}
  function dismiss(record){history=history.filter(n=>recordKey(n)!==recordKey(record));test.writes++;}
  function setDnd(value){dnd=value;test.writes++;}
  function clearAll(context){return clear.request(context);}
  function clearConfirmed(expected,active){if(expected!==history)return false;history=[];test.writes++;Qt.callLater(()=>clear.saved());return true;}
 }
 InsightsPanel {id:panel;anchors.fill:parent;targetScreen:({name:"fixture",width:test.width,height:test.height});state:state;insights:insights
  senomy:({systemHealth:"nominal",message:"Local system observations are available."})
  metrics:({ready:true,memoryTotalKib:32000000,cpuPercent:18,memoryPercent:43})
  network:({available:true,label:"Connected",detail:"Ethernet · full connectivity",activeConnection:"Ethernet",primaryDevice:"fixture0",connectionStateName:"Connected",connectivityName:"Full"})
  battery:({label:"78%",detail:"On battery · about 3h 20m"})
  media:({playing:false,title:""});notifications:notices
 }
 function routeData(route,result){
  if(route==="diagnostics" || route==="console")return result?{title:"Network checks",task_id:"task-1",state:"ready",finished_at:Math.floor(now/1000),output:[{text:"Local connectivity observation"},{text:"Interface: fixture0"},{text:"Connection: connected"},{text:"DNS capability: unavailable in fixture"}]}:{tasks:[{id:"task-0",code:"SYS",title:"System overview",summary:"Inspect local machine, session and component availability.",available:true,command_preview:"system-status · bounded local evidence",scope:"Read only. Sanitized local observations."},{id:"task-1",code:"NET",title:"Network checks",summary:"Inspect the active connection and available diagnostic evidence.",available:true,command_preview:"network-status · bounded local evidence",scope:"Read only. No connection changes."},{id:"task-2",code:"PWR",title:"Power and batteries",summary:"Inspect reported batteries, policy and source state.",available:true},{id:"task-3",code:"LOG",title:"Recent session events",summary:"Read the bounded sanitized event history.",available:true},{id:"task-4",code:"GPU",title:"GPU diagnostics",summary:"Requires a supported graphics provider.",available:false}]};
  if(route==="timeline")return {count:8,entries:Array.from({length:8},(_,i)=>({time:"14:"+String(20-i).padStart(2,"0"),title:["Local build finished","Power source changed","Screenshot saved","Update evidence is old","Calendar reminder delivered","Network connected","Session started","Report saved"][i],source:["Terminal","Power","Flameshot","Updates","Calendar","Network","Session","Reports"][i],message:i===3?"The last repository check is outside the current evidence window. No package check ran automatically.":"Sanitized local event detail for this fixture.",severity:i===3?"warning":"info"}))};
  if(route==="reports")return {exists:true,history_count:2,latest:{profile:"overview",profile_label:"System overview",generated_at:Math.floor(now/1000)-600},preview:[{line_no:1,text:"SENOMYOS SYSTEM EVIDENCE"},{line_no:2,text:"Profile: System overview"},{line_no:3,text:"Collected: fixture observation"},{line_no:4,text:""},{line_no:5,text:"SYSTEM"},{line_no:6,text:"Local sanitized machine and session observations."},{line_no:7,text:""},{line_no:8,text:"AVAILABILITY"},{line_no:9,text:"Optional provider absence is recorded explicitly."},{line_no:10,text:"This example contains no real machine data."}]};
  if(route==="wiki")return {articles:[{id:"island",title:"Getting around SenomyOS",category_title:"Desktop",summary:"The Rail connects quick actions, working surfaces and local evidence.",blocks:[{type:"heading",text:"Start with the task"},{type:"paragraph",text:"Use the Rail for quick actions. Open Performance to inspect measurements, or Insights to understand local observations and decide what to review next."},{type:"heading",text:"Keep your place"},{type:"paragraph",text:"Each destination has a clear reading or working area. Keyboard focus stays visible, and Back returns from the detail you opened."}]},{id:"updates",title:"Understanding update checks",category_title:"Maintenance",summary:"A cached package count and a verified repository check answer different questions.",blocks:[{type:"heading",text:"Check the source age"},{type:"paragraph",text:"An old or unavailable check cannot establish that the system is up to date. Inspect the source and timestamp before deciding about package maintenance."},{type:"heading",text:"Review before applying"},{type:"paragraph",text:"Checking metadata does not install packages. Package maintenance uses a separate terminal review and normal authentication."}]},{id:"reports",title:"Private evidence reports",category_title:"Evidence",summary:"Choose a bounded report scope and keep the result local.",blocks:[{type:"paragraph",text:"Reports remain on this device unless you deliberately export or share them."}]}]};
  return {maintenance:{handoffAvailable:true,reboot:{state:"unknown",reason:"No universal reboot marker was assessed."}},official:{ok:true,count:4,checked_at:Math.floor(now/1000)-7200,state_label:"AVAILABLE",freshness:"repository",packages:[{name:"linux",current:"6.18.1",available:"6.18.2",source:"Official"},{name:"mesa",current:"25.2.1",available:"25.2.2",source:"Official"},{name:"quickshell",current:"0.3.1",available:"0.3.2",source:"Official"},{name:"qt6-base",current:"6.10.0",available:"6.10.1",source:"Official"}]},aur:{ok:false,state_label:"NOT CHECKED",count:null,packages:[]}};
 }
 function finishQueries(){let count=0;while(insights.inFlight && count++<30){const request=insights.inFlight;insights.queryCompleted(0,JSON.stringify({ok:true,observed_at:Math.floor(now/1000),data:routeData(request.route,request.result)}));}}
 function check(ok,message){if(!ok)throw new Error(message);}
 function named(name){const item=input.findChild(panel,name);check(!!item,"exists: "+name);return item;}
 function enter(name){const item=named(name);check(item.visible && item.enabled,"available: "+name);item.forceActiveFocus(Qt.TabFocusReason);input.keyClick(Qt.Key_Return);input.wait(30);finishQueries();}
 function route(id){state.insightsSection=id;finishQueries();input.wait(70);}
 function capture(name){if(!Quickshell.env("SENOMY_QA_OUT"))return;input.wait(60);let done=false;panel.captureItem.grabToImage(result=>{check(result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"),"capture: "+name);done=true;});for(let i=0;i<100&&!done;i++)input.wait(10);check(done,"capture complete");}
 Timer {interval:350;running:true;onTriggered:{try{
  const defaultRegistry=Config.Skin.registry;insights.active=true;finishQueries();capture("00-briefing-wide");
  if(test.baseline){console.log("PASS: baseline native Insights composition captured with inert providers");Qt.quit();return;}

  if(Quickshell.env("SENOMY_INSIGHTS_CHECK_STATES")==="1"){
   route("wiki");insights.store("wiki",{ok:true,observed_at:Math.floor(Date.now()/1000),data:{articles:[]}});input.wait(30);check(named("insights-route-page").item.filtered.length===0 && !named("insights-route-page").item.selected,"empty Wiki has no invented article");capture("state-empty-wiki");
   insights.status("wiki","failed","Fixture article collector unavailable",Math.floor(Date.now()/1000));input.wait(30);const failed=named("insights-status-wiki");check(failed.status.state==="failed" && failed.children.some(child=>child.text && child.text.includes("Fixture article collector unavailable") && child.visible),"provider failure is visible with the retry control");capture("state-failed-wiki");
   route("diagnostics");insights.store("diagnostics",{ok:false,observed_at:Math.floor(Date.now()/1000),data:{},error:{message:"Fixture diagnostics catalog unavailable"}});input.wait(30);check(named("insights-route-page").item.tasks.length===0 && !named("runSelectedTask").enabled,"unavailable catalog cannot execute a retained task");capture("state-unavailable-diagnostics");
   route("briefing");notices.history=[];const source={ok:true,count:0,checked_at:Math.floor(Date.now()/1000),freshness:"repository",packages:[]};insights.store("briefing",{ok:true,observed_at:Math.floor(Date.now()/1000),data:{official:source,aur:source}});input.wait(30);check(panel.attention.length===0,"no-review state requires current verified checks and no unread backlog");capture("state-clear-briefing");
   panel.senomy={systemHealth:"unavailable",message:"Fixture observation provider unavailable"};input.wait(30);check(panel.priorityAttention.route==="diagnostics" && named("briefing-assessment").text!=="No active health alerts","unknown observation never becomes healthy");capture("state-unavailable-briefing");
   check(action.commands.length===0 && writes===0,"empty/failure/unknown states never dispatch or write");console.log("PASS: native empty, failed, unavailable, verified no-review and unknown-health states; no actions");Qt.quit();return;
  }
  for(const section of panel.sections){route(section.id);capture("wide-"+section.id);}
  test.width=620;test.height=760;input.wait(60);
  for(const section of panel.sections){route(section.id);capture("narrow-"+section.id);}
  const registry=JSON.parse(JSON.stringify(Config.Skin.registry));registry.persona=Object.assign({},registry.persona || {},{uiTextScale:1.5,highContrast:true,reducedMotion:true});Config.Skin.registry=registry;
  test.width=720;test.height=620;input.wait(60);route("briefing");capture("large-briefing");route("console");capture("large-console");route("wiki");capture("large-wiki");
  check(action.commands.length===0 && writes===0,"opening all routes never dispatches an action or notification write");

  Config.Skin.registry=defaultRegistry;test.width=1320;test.height=780;input.wait(70);
  route("console");const tasks=named("insights-route-page").item;
  check(tasks.selected.id==="task-1" && tasks.resultMatches,"retained result selects its exact known task for reading only");
  enter("task-task-0");check(action.commands.length===0 && !tasks.resultMatches && !named("insights-task-output").visible,"task selection never runs or misattributes another result");
  enter("runSelectedTask");check(action.commands.length===1 && action.commands[0][2]==="task-0","explicit Run reaches the exact allowlisted task once");
  insights.actionCompleted(0,JSON.stringify({ok:true,observed_at:Math.floor(Date.now()/1000),data:{task_id:"task-0",title:"System overview",state:"ready",finished_at:Math.floor(Date.now()/1000),output:[{text:"Selected task result, private fixture only."}].concat(Array.from({length:120},(_,i)=>({text:"Bounded fixture output line "+(i+1)})))}}));
  check(tasks.resultMatches && named("insights-task-output").text.includes("Selected task result"),"verified result remains bound to selected task");const output=named("insights-task-output-view");output.forceActiveFocus();input.wait(30);input.keyClick(Qt.Key_PageDown);check(output.contentY>0 && output.height<=output.parent.parent.height,"long output has a bounded keyboard-scrollable viewport");capture("detail-console");
  enter("task-task-4");check(!named("runSelectedTask").enabled,"unavailable task cannot run");enter("task-task-0");
  state.modalActive=true;panel.navigate("wiki");check(state.insightsSection==="console" && !named("runSelectedTask").enabled,"protected modal blocks navigation and dispatch");state.modalActive=false;
  route("wiki");route("console");check(named("insights-route-page").item.selectedId==="task-0","selected task survives route navigation");
  route("updates");check(!named("insights-update-state-official").text.includes("0 reported") && named("insights-update-state-aur").text==="Not checked","unknown source counts stay unknown");
  const packageSearch=named("insights-package-search");packageSearch.forceActiveFocus();for(const ch of "linux")input.keyClick(ch.toUpperCase().charCodeAt(0));input.wait(30);check(named("insights-route-page").item.filtered.length===1,"local package search filters actual returned names");
  route("timeline");route("updates");check(named("insights-package-search").text==="linux","package query survives route navigation");
  enter("insights-maintenance-toggle");capture("detail-update-options");check(action.commands.length===1,"disclosing maintenance does not request terminal or update checks");
  route("timeline");enter("insights-timeline-issues");check(named("insights-route-page").item.filtered.length===1,"issue filter retains warning evidence");enter("insights-event-0");capture("detail-timeline");
  route("wiki");check(named("insights-route-page").item.selected.id==="island","wide Wiki opens existing first article for reading");
  const wikiSearch=named("insights-wiki-search");wikiSearch.forceActiveFocus();for(const ch of "update")input.keyClick(ch.toUpperCase().charCodeAt(0));input.wait(30);check(named("insights-route-page").item.filtered.length===1,"local Wiki search");enter("insights-article-updates");capture("detail-wiki");
  test.width=620;input.wait(60);check(named("insights-route-page").item.articleOpen,"selected article stays open as width constrains");capture("detail-wiki-narrow");check(named("insights-route-page").item.back(),"narrow Back returns to catalog");
  enter("insights-directory-toggle");check(panel.directoryOpen,"labelled narrow navigation opens");const reportRoute=input.findChild(panel.navigation,"insights-nav-reports");check(!!reportRoute && reportRoute.visible,"all routes available in drawer");reportRoute.forceActiveFocus();input.keyClick(Qt.Key_Return);finishQueries();input.wait(60);check(state.insightsSection==="reports" && !panel.directoryOpen,"drawer route closes without changing action state");
  enter("insights-report-scope-full");check(action.commands.length===1,"report scope selection does not generate");enter("report-generate");check(action.commands.length===2 && action.commands[1][2]==="full","explicit generation uses exact supported scope once");
  insights.actionCompleted(0,JSON.stringify({ok:true,observed_at:Math.floor(Date.now()/1000),data:{exists:true,history_count:1,latest:{profile:"full",profile_label:"Full evidence",generated_at:Math.floor(Date.now()/1000)},preview:[{line_no:1,text:"Private fixture report"}]}}));
  route("notifications");const unreadBefore=notices.unreadCount;enter("insights-inbox-unread");enter("notification-open-0");check(notices.unreadCount===unreadBefore-1 && notices.history[1].unread,"opening reads only one exact notification");const inbox=named("insights-inbox-list");check(inbox.filteredHistory.length===unreadBefore,"opened Unread record remains until closed");capture("detail-inbox");check(named("insights-route-page").item.back() && inbox.filteredHistory.length===unreadBefore-1,"closing opened Unread record applies read filter");
  enter("insights-inbox-clear");check(clear.actionState==="pending" && notices.history.length===3,"Clear prepares review without deleting");capture("detail-clear-review");enter("notificationClearCancel");
  enter("insights-inbox-clear");notices.history=notices.history.concat([{id:99,receivedAt:Date.now(),summary:"Arrived after review",appName:"Fixture",body:"New record",unread:true}]);check(!clear.confirm("insights:fixture") && notices.history.length===4,"real guard refuses stale clear after provider identity changes");enter("insights-inbox-clear");enter("notificationClearCancel");


  notices.sessionService=Object.assign({},notices.sessionService,{schedule:{id:"fixture-timer",state:"scheduled",action:"reboot",label:"Restart",dueLabel:"In 30 minutes",statusDetail:"Fixture commitment"},remainingText:"30:00",remainingSeconds:1800,progress:.5});notices.commitment=notices.sessionService.schedule;notices.dnd=true;input.wait(50);check(named("system-commitment").visible,"system commitment stays separate and visible through quiet mode");capture("detail-system-commitment");enter("session-change");check(test.sessionOpens===1,"pinned record opens the authoritative session route once");notices.commitment=null;notices.sessionService=Object.assign({},notices.sessionService,{schedule:{}});notices.dnd=false;
  route("updates");const beforeChecks=action.commands.length;
  enter("insights-check-official");check(action.commands.length===beforeChecks+1 && action.commands[action.commands.length-1][1]==="check-official","official check requires explicit action");
  let checked=routeData("updates",false);checked.official=Object.assign({},checked.official,{ok:true,checked_at:Math.floor(Date.now()/1000)});insights.actionCompleted(0,JSON.stringify({ok:true,observed_at:Math.floor(Date.now()/1000),data:checked}));finishQueries();
  enter("insights-check-aur");check(action.commands.length===beforeChecks+2 && action.commands[action.commands.length-1][1]==="check-aur","AUR check requires explicit action");
  checked.aur={ok:true,count:0,checked_at:Math.floor(Date.now()/1000),freshness:"repository",state_label:"CURRENT",packages:[]};insights.actionCompleted(0,JSON.stringify({ok:true,observed_at:Math.floor(Date.now()/1000),data:checked}));finishQueries();
  enter("insights-maintenance-toggle");enter("insights-maintenance-open");check(action.commands.length===beforeChecks+3 && action.commands[action.commands.length-1].slice(-1)[0]==="open","terminal review handoff is explicit and separate from checks");insights.actionCompleted(0,JSON.stringify({ok:true,data:{state:"terminal-requested"}}));
  test.width=1320;input.wait(60);route("briefing");check(panel.priorityAttention.route==="updates","unknown update evidence precedes unread backlog");const calls=action.commands.length;enter("briefing-priority-action");check(state.insightsSection==="updates" && action.commands.length===calls,"priority action navigates without checking repositories");
  for(const size of [{w:1320,h:780},{w:620,h:620}]){test.width=size.w;test.height=size.h;input.wait(40);for(const section of panel.sections){route(section.id);if(panel.narrowLayout){panel.directoryOpen=true;panel.navigation.focusSection();}else panel.navigation.focusSection();input.wait(20);for(let n=0;n<45;n++){input.keyClick(Qt.Key_Tab);input.wait(2);const focused=test.activeFocusItem;if(!focused || !focused.visible)continue;let ancestor=focused.parent;while(ancestor && ancestor!==panel.captureItem){if(ancestor.clip){const position=focused.mapToItem(ancestor,0,0);check(position.y>=-1 && position.y+focused.height<=ancestor.height+1,section.id+" keyboard focus fully visible at "+size.w);}ancestor=ancestor.parent;}}}}
  check(action.commands.length===calls,"keyboard navigation never dispatches");
  test.width=620;route("briefing");panel.directoryOpen=true;named("briefing-priority-action").forceActiveFocus();input.wait(30);check(!panel.directoryOpen,"drawer closes before keyboard focus enters the covered body");
  test.width=620;Config.DirectoryStyle.touchMode=true;route("briefing");input.wait(40);check(named("insights-close").width>=48 && named("insights-directory-toggle").width>=48,"native touch targets");capture("touch-briefing");
  console.log("PASS: all eight Insights routes and constrained focus; safe navigation/selection, exact task result/run, local filters/state, narrow drawer/back, report scope/generation and exact-version notification read/real stale-clear guard; inert actions only");Qt.quit();
 }catch(error){console.error("FAIL: "+error.message);Qt.exit(1);}}}
}
