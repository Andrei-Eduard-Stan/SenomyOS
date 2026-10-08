import QtQuick
import QtTest
import "../services"
TestCase {
    id:test;name:"InsightsRequests";when:true
    QtObject {id:query;property bool running:false;property var calls:[];function exec(args){calls=calls.concat([args]);}}
    QtObject {id:action;property bool running:false;property var calls:[];function exec(args){calls=calls.concat([args]);}}
    InsightsRequests {id:model;queryRunner:query;actionRunner:action;sourceRoot:"/fixture"}
    function payload(data,ok) {return JSON.stringify({ok:ok===undefined?true:ok,observed_at:100,data:data,error:ok===false?{message:"Provider reported failure"}:null});}
    function catalog(domain) {const next={};next[domain]={ok:true,data:{tasks:[{id:"safe-task",available:true}]}};model.payloads=next;}
    function finishQuery(data,ok,code){model.queryCompleted(code||0,payload(data||{},ok));}
    function drainAll(){while(model.inFlight)finishQuery();}
    function init(){model.active=false;model.action=null;model.inFlight=null;model.queue=[];model.payloads={};model.statuses={};model.actionState="idle";model.actionMessage="";model.lastActionDomain="";model.section="briefing";query.calls=[];action.calls=[];query.running=false;action.running=false;}
    function open(domain){model.section=domain;model.active=true;drainAll();}
    function taskResult(id,state){return {task_id:id||"safe-task",state:state||"ready",finished_at:Math.floor(Date.now()/1000),output:["Safe evidence"]};}
    function test_busy_route_change_queues_new_route(){
        model.active=true;compare(query.calls.length,1);model.section="wiki";compare(model.queue.length,1);
        finishQuery({known_total_count:3});compare(query.calls.length,2);compare(query.calls[1][0],"/fixture/scripts/wiki-status.py");
        finishQuery({articles:[]});verify(model.payloads.briefing.data.known_total_count===3);verify(model.payloads.wiki.ok);compare(model.statuses.wiki.state,"ready");
    }
    function test_refresh_deduplicates_and_closing_drops_pending(){
        model.active=true;model.section="timeline";verify(model.refresh("timeline",false));compare(model.queue.length,1);
        model.active=false;compare(model.queue.length,0);finishQuery();compare(query.calls.length,1);verify(!model.refresh("wiki",false));
    }
    function test_errors_are_per_route_and_retain_previous_evidence(){
        open("wiki");model.payloads={wiki:{ok:true,data:{articles:[{id:"old"}]}}};model.refresh("wiki",false);
        model.queryCompleted(0,"invalid");compare(model.statuses.wiki.state,"failed");compare(model.payloads.wiki.data.articles[0].id,"old");
        model.section="timeline";compare(model.error,"");finishQuery({},false);compare(model.error,"Provider reported failure");
        model.section="wiki";compare(model.error,"");compare(model.statuses.wiki.state,"loading");drainAll();
    }
    function test_missing_unallowlisted_and_wrong_route_tasks(){
        open("console");catalog("console");verify(!model.runTask("console","arbitrary;id"));verify(!model.runTask("console","unknown"));verify(!model.runTask("diagnostics","safe-task"));
        model.payloads.console.data.tasks[0].available=false;verify(!model.runTask("console","safe-task"));compare(action.calls.length,0);
    }
    function test_json_failure_does_not_become_success_on_exit_zero(){
        open("diagnostics");catalog("diagnostics");verify(model.runTask("diagnostics","safe-task"));compare(action.calls[0][2],"safe-task");
        model.actionCompleted(0,payload(taskResult("safe-task","failed"),false));compare(model.actionState,"failed");compare(model.payloads.diagnosticsResult.ok,false);
    }
    function test_success_is_verified_task_identity_and_freshness(){
        for(const data of [taskResult(),taskResult("old-task"),{task_id:"safe-task",state:"ready",finished_at:1}]){
            open("diagnostics");catalog("diagnostics");verify(model.runTask("diagnostics","safe-task"));model.actionCompleted(0,payload(data));
            compare(model.actionState,data.task_id==="safe-task" && data.finished_at>1?"succeeded":"failed");
        }
    }
    function test_console_empty_stdout_reads_cached_result_even_after_close(){
        open("console");catalog("console");verify(model.runTask("console","safe-task"));model.active=false;
        model.actionCompleted(0,"");compare(model.actionState,"running");verify(model.inFlight.afterAction);compare(query.calls[query.calls.length-1][1],"read");
        finishQuery(taskResult());compare(model.actionState,"succeeded");compare(model.payloads.consoleResult.data.task_id,"safe-task");verify(!model.runTask("console","safe-task"));
    }
    function test_action_deduplicates_and_reports_failure_without_result(){
        open("console");catalog("console");verify(model.runTask("console","safe-task"));verify(!model.runTask("console","safe-task"));
        model.actionCompleted(1,"");compare(model.actionState,"failed");compare(action.calls.length,1);
    }
    function test_update_requires_requested_source_success(){
        open("updates");verify(!model.runUpdate("install"));verify(model.runUpdate("official"));
        model.actionCompleted(0,payload({official:{ok:false,checked_at:Math.floor(Date.now()/1000)},aur:{ok:true}}));compare(model.actionState,"failed");drainAll();
        verify(model.runUpdate("official"));model.actionCompleted(0,payload({official:{ok:true,checked_at:Math.floor(Date.now()/1000)}}));compare(model.actionState,"succeeded");drainAll();
    }
    function test_report_success_requires_new_requested_profile(){
        open("reports");verify(!model.generateReport("unrestricted"));
        for(const latest of [{profile:"network",generated_at:Math.floor(Date.now()/1000)},{profile:"full",generated_at:1},{profile:"full",generated_at:Math.floor(Date.now()/1000)}]){
            verify(model.generateReport("full"));model.actionCompleted(0,payload({exists:true,latest:latest}));
            compare(model.actionState,latest.profile==="full"&&latest.generated_at>1?"succeeded":"failed");
        }
        verify(model.openLatestReport());model.actionCompleted(0,"");compare(model.actionState,"started");
    }
    function test_notifications_and_unknown_routes_do_not_collect(){
        model.section="notifications";model.active=true;compare(query.calls.length,0);verify(!model.refresh("unknown",false));compare(query.calls.length,0);
    }
}
