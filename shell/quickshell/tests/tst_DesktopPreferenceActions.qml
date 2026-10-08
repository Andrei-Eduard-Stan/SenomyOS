import QtQuick
import QtTest
import "../services"
TestCase {
    id:test;name:"DesktopPreferenceActions";when:true
    QtObject {id:runner;property bool running:false;property int calls:0;property var argv:[];function exec(args){calls++;argv=args;}}
    DesktopPreferenceActions {id:actions;runner:runner;helper:"fixture.py"}
    function init(){
        actions.active=false;actions.actionState="idle";actions.cancel();actions.context="apps:fixture";actions.active=true;runner.calls=0;runner.running=false;runner.argv=[];
        actions.defaults=[{mime:"text/plain",label:"Text files",current:"one.desktop",options:[{id:"two.desktop",name:"Fixture"}],token:"role-token"}];
        actions.apps=[{id:"two.desktop",name:"Fixture",autostartAllowed:true,token:"app-token"}];
        actions.autostart=[{id:"one.desktop",name:"Fixture",protected:false,enabled:true,token:"entry-token"},{id:"agent.desktop",name:"Protected",protected:true,enabled:true,token:"protected"}];
        actions.deployment={supported:true,enabled:false,token:"deployment-token"};
    }
    function test_default_review_cancel_and_confirm(){verify(!actions.confirm());verify(actions.request("default","text/plain","two.desktop"));compare(runner.calls,0);verify(actions.cancel());compare(runner.calls,0);verify(actions.request("default","text/plain","two.desktop"));verify(actions.confirm());compare(runner.argv[2],"default-confirmed");compare(runner.argv[3],"text/plain");compare(runner.argv[4],"two.desktop");compare(runner.argv[5],"role-token");verify(!actions.confirm());verify(!actions.cancel());}
    function test_autostart_add_and_deploy_fixed_arguments(){
        for(const choice of [{kind:"autostart",key:"one.desktop",value:"no",verb:"autostart-confirmed"},{kind:"add-autostart",key:"two.desktop",value:"",verb:"add-autostart-confirmed"},{kind:"enable-autostart",key:"",value:"",verb:"enable-autostart-confirmed"}]){
            verify(actions.request(choice.kind,choice.key,choice.value));verify(actions.confirm());compare(runner.argv[2],choice.verb);actions.completed(0,JSON.stringify({ok:true,data:{state:"succeeded",message:"Saved for future login"}}));
        }
        compare(runner.calls,3);
    }
    function test_protected_unknown_missing_foreign_and_duplicate_rejected(){
        verify(!actions.request("autostart","agent.desktop","no"));verify(!actions.request("default","unknown","two.desktop"));verify(!actions.request("default","text/plain","evil"));verify(!actions.request("autostart","one.desktop","arbitrary"));verify(!actions.request("add-autostart","one.desktop",""));verify(!actions.request("execute","two.desktop",""));compare(runner.calls,0);
    }
    function test_changed_snapshot_and_context_close_rejected(){
        verify(actions.request("default","text/plain","two.desktop"));actions.defaults=[{mime:"text/plain",options:[{id:"two.desktop",name:"Fixture"}],token:"changed"}];verify(!actions.confirm());compare(actions.actionState,"failed");compare(runner.calls,0);
        actions.cancel();verify(actions.request("autostart","one.desktop","no"));actions.context="settings:fixture";compare(actions.actionState,"idle");verify(!actions.confirm());
        verify(actions.request("autostart","one.desktop","no"));actions.active=false;compare(actions.actionState,"idle");compare(runner.calls,0);
    }
    function test_busy_and_result_failures(){runner.running=true;verify(!actions.request("autostart","one.desktop","no"));runner.running=false;actions.completed(0,JSON.stringify({ok:false,error:{message:"Failed"}}));compare(actions.actionState,"failed");actions.completed(0,"bad");compare(actions.actionState,"failed");actions.completed(0,JSON.stringify({ok:true,data:{state:"unverified",message:"Check registry"}}));compare(actions.actionState,"unverified");}
}
