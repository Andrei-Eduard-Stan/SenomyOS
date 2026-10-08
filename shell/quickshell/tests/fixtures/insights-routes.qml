import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "services"
Window {
    id:test;visible:true;width:1120;height:820
    property int mutations:0
    TestCase {id:input;when:false}
    QtObject {id:state;property string activePrimary:"insights";property string primaryScreen:"fixture";property string insightsSection:"briefing";function closePrimary(){activePrimary="";}}
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
        metrics:({cpuPercent:10,memoryPercent:20});battery:({detail:"Fixture power"});network:({detail:"Fixture connectivity"});media:({playing:false,title:"Quiet"})
        notifications:({history:Array.from({length:24},(_,i)=>({summary:"Notification "+i,appName:"Fixture",body:"Safe fixture",unread:true})),unreadCount:24,activeCount:0,serverEnabled:true,dnd:false,clearAvailable:true,clearActions:clear,setDnd:function(){test.mutations++;},clearAll:function(){test.mutations++;},dismiss:function(){test.mutations++;}})
    }
    function routeData(route,result){
        if(route==="diagnostics"||route==="console")return result?{title:"Fixture result",state:"ready",task_id:"safe-task",finished_at:100,output:Array.from({length:60},(_,i)=>({text:"Sanitized result "+i}))}:{tasks:Array.from({length:24},(_,i)=>({id:"task-"+i,code:"FIX",title:"Task "+i,summary:"Safe fixture",available:true}))};
        if(route==="wiki")return {articles:Array.from({length:24},(_,i)=>({id:"article-"+i,title:"Article "+i,category_title:"Fixture",summary:"Local fixture",blocks:[{type:"heading",text:"Safe local article"}]}))};
        if(route==="timeline")return {count:24,entries:Array.from({length:24},(_,i)=>({time:"12:00",title:"Event "+i,source:"Fixture",message:"Safe fixture",severity:"info"}))};
        if(route==="reports")return {exists:true,latest:{profile_label:"OVERVIEW"},history_count:1,preview:Array.from({length:100},(_,i)=>({line_no:i+1,text:"Sanitized report "+i}))};
        return {known_total_count:24,successful_source_count:1,official:{state_label:"AVAILABLE",count:24,freshness:"local-database",checked_at_label:"fixture",packages:Array.from({length:24},(_,i)=>({name:"Package "+i,current:"1",available:"2",source:"Official"}))},aur:{state_label:"NOT CHECKED",count:0,packages:[]}};
    }
    function finishQueries(){while(insights.inFlight){const req=insights.inFlight;insights.queryCompleted(0,JSON.stringify({ok:true,observed_at:100,data:test.routeData(req.route,req.result)}));}}
    function check(ok,msg){if(!ok){console.error("FAIL: "+msg);Qt.exit(1);throw new Error(msg);}}
    function inside(item,parent){while(item){if(item===parent)return true;item=item.parent;}return false;}
    Timer {
        interval:400;running:true
        onTriggered:{
            insights.active=true;test.finishQueries();
            for(const size of [{w:1120,h:820},{w:720,h:500}]){
                test.width=size.w;test.height=size.h;input.wait(30);
                for(const section of panel.sections){
                    state.insightsSection=section.id;test.finishQueries();panel.navigation.focusSection();input.wait(40);
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
                if(test.activeFocusItem && test.activeFocusItem.text==="FIX // Task 23"){input.keyClick(Qt.Key_Return);break;}
            }
            test.check(action.calls===1 && action.argv[2]==="task-23","last curated task keyboard activation");
            console.log("PASS: all eight Insights routes, populated keyboard lists and shared curated task activation at wide/constrained sizes; fake providers only");Qt.quit();
        }
    }
}
