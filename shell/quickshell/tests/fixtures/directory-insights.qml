import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services"
Window {
    id:test;visible:true;width:1120;height:820
    property int mutations:0
    property string out:Quickshell.env("SENOMY_QA_OUT")
    TestCase {id:input;when:false}
    QtObject {id:state;property string activePrimary:"insights";property string primaryScreen:"fixture";property string insightsSection:"briefing";property string performanceSection:"cpu";function showPrimary(kind,screen,section){primaryScreen=screen;activePrimary=kind;}
        function allowInteraction(){return true;}
 function closePrimary(){activePrimary="";}}
    QtObject {id:query;property bool running:false;function exec(args){}}
    QtObject {id:action;property bool running:false;property int calls:0;property var argv:[];function exec(args){calls++;argv=args;}}
    InsightsRequests {id:insights;queryRunner:query;actionRunner:action;sourceRoot:"/fixture";section:state.insightsSection}
    QtObject {
        id:clear
        property string actionState:"idle"
        property bool locked:false
        property string context:"insights:fixture"
        property string message:""
        property int historyCount:0
        property int activeCount:0
        function cancel(){actionState="idle";}
        function confirm(){test.mutations++;}
    }
    InsightsPanel {
        id:panel;anchors.fill:parent;targetScreen:({name:"fixture"});state:state;insights:insights
        senomy:({state:"nominal",message:"Fixture system briefing",systemHealth:"nominal"})
        metrics:({ready:true,memoryTotalKib:32000000,cpuPercent:10,memoryPercent:20});battery:({detail:"Fixture power"});network:({detail:"Fixture connectivity",activeConnection:"Fixture",primaryDevice:"fixture0",connectionStateName:"Connected",connectivityName:"Full"});media:({playing:false,title:"Quiet"})
        notifications:({sessionService:({busy:false,error:"",schedule:{},progress:0,remainingSeconds:0,remainingText:"",cancelSchedule:function(){test.mutations++;},executeSchedule:function(){test.mutations++;},postpone:function(){test.mutations++;}}),history:Array.from({length:24},(_,i)=>({id:i,receivedAt:Date.now()-i*60000,urgency:"Normal",summary:"Notification "+i,appName:"Fixture",body:"Safe fixture",unread:true})),unreadCount:24,activeCount:0,serverEnabled:true,dnd:false,clearAvailable:true,clearActions:clear,setDnd:function(){test.mutations++;},clearAll:function(){test.mutations++;},dismiss:function(){test.mutations++;}})
    }
    function routeData(route,result){
        if(route==="diagnostics"||route==="console")return result?{title:"Fixture result",state:"ready",task_id:"safe-task",finished_at:100,output:Array.from({length:60},(_,i)=>({text:"Sanitized result "+i}))}:{tasks:Array.from({length:24},(_,i)=>({id:"task-"+i,code:"FIX",title:"Task "+i,summary:"Safe fixture",available:true}))};
        if(route==="wiki")return {articles:Array.from({length:24},(_,i)=>({id:"article-"+i,title:"Article "+i,category_title:"Fixture",summary:"Local fixture",blocks:[{type:"heading",text:"Safe local article"}]}))};
        if(route==="timeline")return {count:24,entries:Array.from({length:24},(_,i)=>({time:"12:00",title:"Event "+i,source:"Fixture",message:"Safe fixture",severity:"info"}))};
        if(route==="reports")return {exists:true,latest:{profile_label:"OVERVIEW"},history_count:1,preview:Array.from({length:100},(_,i)=>({line_no:i+1,text:"Sanitized report "+i}))};
        return {known_total_count:24,successful_source_count:1,official:{ok:true,checked_at:Math.floor(Date.now()/1000)-86400,state_label:"AVAILABLE",count:24,freshness:"local-database",checked_at_label:"fixture",packages:Array.from({length:24},(_,i)=>({name:"Package "+i,current:"1",available:"2",source:"Official"}))},aur:{state_label:"NOT CHECKED",count:0,packages:[]}};
    }
    function finishQueries(){while(insights.inFlight){const req=insights.inFlight;insights.queryCompleted(0,JSON.stringify({ok:true,observed_at:100,data:test.routeData(req.route,req.result)}));}}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw new Error(msg);}}
    function revealBriefingControl(item) {
        const view=input.findChild(panel,"insights-briefing");
        if (!view) return;
        item.forceActiveFocus(Qt.TabFocusReason);input.wait(25);view.revealFocus();input.wait(25);
        const pos=item.mapToItem(view,0,0);
        test.check(pos.y>=-1 && pos.y+item.height<=view.height+1,"Briefing control revealed before pointer activation");
    }
    function inside(item,parent){while(item){if(item===parent)return true;item=item.parent;}return false;}
    Timer {
        interval:400;running:true
        onTriggered:{
            const switchTarget=input.findChild(panel.captureItem,"switch-performance");
                test.check(switchTarget!==null && switchTarget.visible,"persistent surface switch is visible");
                switchTarget.forceActiveFocus();input.keyClick(Qt.Key_Return);input.wait(20);
                test.check(state.activePrimary==="performance" && state.primaryScreen==="fixture","keyboard switch uses exclusive primary controller");
                state.activePrimary="insights";input.wait(20);
                            panel.network=({detail:"Fixture connectivity · 70%",activeConnection:"Fixture",primaryDevice:"fixture0",connectionStateName:"Connected",connectivityName:"Full"});
            test.check(panel.changes().find(row=>row.label==="CONNECTION").value==="Unchanged","signal-strength changes do not claim a connection change");
            panel.network=({detail:"Second fixture",activeConnection:"Second",primaryDevice:"fixture0",connectionStateName:"Connected",connectivityName:"Full"});
            test.check(panel.changes().find(row=>row.label==="CONNECTION").value==="Second fixture","connection identity change is reported");
            panel.network=({detail:"Fixture connectivity",activeConnection:"Fixture",primaryDevice:"fixture0",connectionStateName:"Connected",connectivityName:"Full"});
            insights.active=true;test.finishQueries();
            test.check(panel.priorityAttention.route==="updates","stale update evidence precedes notification backlog");
            const readings=input.findChild(panel.captureItem,"briefing-system-summary");
            test.check(readings!==null && !readings.visible,"briefing prioritizes actions before optional telemetry");
            const readingsToggle=input.findChild(panel.captureItem,"briefing-system-toggle");test.revealBriefingControl(readingsToggle);input.mouseClick(readingsToggle);input.wait(20);
            test.check(readings.visible,"current readings have an explicit pointer control");input.keyClick(Qt.Key_Return);input.wait(20);
            test.check(!readings.visible,"current readings collapse with the keyboard");
            const opening=panel.openingSnapshot;
            panel.openingSnapshot=Object.assign({},opening,{cpu:panel.metrics.cpuPercent-0.2,memory:panel.metrics.memoryPercent-0.1});
            test.check(panel.compactChanges()==="No notable changes since opening","small utilisation changes stay out of compact summary");
            test.check(panel.changes().find(row=>row.label==="CPU").value.includes("+0.2"),"full changes retain small utilisation deltas");
            const changesToggle=input.findChild(panel.captureItem,"briefing-changes-toggle");test.revealBriefingControl(changesToggle);input.mouseClick(changesToggle);input.wait(20);test.check(panel.showChangeDetails,"opening changes has visible keyboard/pointer control");
            panel.captureItem.grabToImage(result=>result.saveToFile(test.out+"/insights-changes-expanded.png"));input.wait(60);
            input.keyClick(Qt.Key_Return);input.wait(20);test.check(!panel.showChangeDetails,"keyboard collapses full change details");panel.openingSnapshot=opening;
            const nominal=panel.senomy;
            panel.senomy=({state:"warning",message:"Fixture health needs attention",systemHealth:"warning"});
            test.check(panel.priorityAttention.route==="diagnostics","health evidence becomes first priority");panel.senomy=nominal;
            const nextStep=input.findChild(panel.captureItem,"briefing-priority-action");test.revealBriefingControl(nextStep);input.mouseClick(nextStep);input.wait(20);
            test.check(state.insightsSection==="updates" && action.calls===0,"priority action navigates without running update checks");state.insightsSection="briefing";test.finishQueries();
            for(const size of [{w:1120,h:820},{w:720,h:500},{w:390,h:740}]){
                test.width=size.w;test.height=size.h;input.wait(30);
                for(const section of panel.sections){
                    state.insightsSection=section.id;test.finishQueries();panel.navigation.focusSection();input.wait(40);
                    if(test.out){
                        panel.captureItem.grabToImage(result=>{test.check(result.saveToFile(test.out+"/insights-"+section.id+"-"+size.w+".png"),"save Insights screenshot");});
                        input.wait(70);
                    }
                    const seen=new Set();
                    for(let step=0;step<90;step++){
                        input.keyClick(Qt.Key_Tab);input.wait(2);const item=test.activeFocusItem;
                        if(item && test.inside(item,panel.contentArea)){
                            if(item.text)seen.add(item.text);
                            let parent=item.parent;
                            while(parent && parent!==panel.contentArea){
                                if(parent.clip){const pos=item.mapToItem(parent,0,0);test.check(pos.y>=-1&&pos.y+item.height<=parent.height+1,section.id+" clipped nested focus");}parent=parent.parent;
                            }
                            const pos=item.mapToItem(panel.contentArea,0,0);
                            test.check(pos.y>=-1&&pos.y+item.height<=panel.contentArea.height+1,section.id+" clipped focus at "+pos.y);
                        }
                    }
                    if(["notifications","timeline","updates","wiki"].indexOf(section.id)>=0){
                        const prefix=section.id==="notifications"?"Notification ":section.id==="timeline"?"12:00 // Event ":section.id==="updates"?"Package ":"Article ";
                        for(let i=0;i<24;i++)test.check(seen.has(prefix+i),section.id+" row "+i+" keyboard reachable");
                    }
                    test.check(test.mutations===0 && action.calls===0,"route opening and navigation must not act");
                }
            }
            state.insightsSection="console";test.finishQueries();panel.navigation.focusSection();input.wait(40);
            for(let step=0;step<90;step++){
                input.keyClick(Qt.Key_Tab);input.wait(2);
                if(test.activeFocusItem && test.activeFocusItem.text==="Task 23"){input.keyClick(Qt.Key_Return);break;}
            }
            test.check(action.calls===0,"selecting task does not execute it");
            const runTaskButton=input.findChild(panel.contentArea,"runSelectedTask");test.check(runTaskButton!==null,"explicit task runner exists");
            runTaskButton.forceActiveFocus();input.keyClick(Qt.Key_Return);
            test.check(action.calls===1 && action.argv[2]==="task-23","last curated task keyboard activation");
            console.log("PASS: all eight Insights routes, populated keyboard lists and shared curated task activation at wide/constrained sizes; fake providers only");Qt.quit();
        }
    }
}
