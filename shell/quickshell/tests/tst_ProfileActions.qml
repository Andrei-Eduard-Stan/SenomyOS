import QtQuick
import QtTest
import "../services"
TestCase {
    id:test;name:"ProfileActions";when:true
    QtObject {id:runner;property bool running:false;property int calls:0;property var argv:[];function exec(args){calls++;argv=args;}}
    ProfileActions {id:control;runner:runner;helper:"fixture.py"}
    function item(active,token){return {uuid:"12345678-1234-1234-1234-123456789abc",name:"Fixture",type:"wifi",mutable:true,active:Boolean(active),token:token||"a".repeat(64)};}
    function init(){control.active=false;control.actionState="idle";control.cancel();control.blocked=false;control.context="network:fixture";control.items=[item()];control.active=true;runner.running=false;runner.calls=0;runner.argv=[];}
    function test_explicit_review_cancel_and_confirm(){
        verify(!control.confirm());verify(control.request("forget",item()));compare(runner.calls,0);verify(!control.request("forget",item()));verify(control.cancel());compare(runner.calls,0);
        verify(control.request("autoconnect",item()));verify(control.confirm());compare(runner.calls,1);compare(runner.argv[2],"apply-confirmed");compare(runner.argv[3],"autoconnect");verify(!control.confirm());verify(!control.cancel());
    }
    function test_active_forget_inactive_disconnect_and_unknown_rejected(){
        verify(!control.request("disconnect",item()));control.items=[item(true)];verify(!control.request("forget",item(true)));verify(!control.request("unknown",item(true)));compare(runner.calls,0);
    }
    function test_context_close_or_replacement_cancels(){
        verify(control.request("forget",item()));control.context="network:other";compare(control.actionState,"idle");verify(!control.confirm());
        verify(control.request("forget",item()));control.active=false;compare(control.actionState,"idle");compare(runner.calls,0);
    }
    function test_changed_profile_and_other_operation_rejected(){
        verify(control.request("forget",item()));control.items=[item(false,"b".repeat(64))];verify(!control.confirm());compare(control.actionState,"failed");compare(runner.calls,0);
        control.cancel();control.items=[item()];control.blocked=true;verify(!control.request("forget",item()));control.blocked=false;verify(control.request("forget",item()));control.blocked=true;verify(!control.confirm());compare(runner.calls,0);
    }
    function test_succeeded_unverified_failed_and_invalid(){
        for(const state of ["succeeded","unverified"]){control.completed(0,JSON.stringify({ok:true,data:{state:state,message:"Observed"}}));compare(control.actionState,state);}
        control.completed(0,JSON.stringify({ok:false,error:{message:"Failed"}}));compare(control.actionState,"failed");control.completed(0,"bad");compare(control.actionState,"failed");
    }
}
