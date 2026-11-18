import QtQuick
import QtTest
import "../services"
TestCase {
    id:test;name:"AudioGraphActions"
    property int writes:0
    property var card:({token:"1:2",revision:"r",name:"Fixture card"})
    QtObject {
        id:provider
        property var selectionActions:({locked:false})
        property var graphSnapshot:({available:true,nodes:[],cards:[test.card],canMove:false})
        function applyGraphRequest(request){test.writes++;return true;}
    }
    AudioGraphActions {id:actions;provider:provider;context:"audio:fixture"}
    function init(){actions.actionState="idle";actions.requestData=null;actions.context="audio:fixture";provider.selectionActions=({locked:false});provider.graphSnapshot=({available:true,nodes:[],cards:[card],canMove:false});writes=0;}
    function test_request_cancel(){verify(actions.request("profile",card,1,"Duplex"));compare(writes,0);verify(actions.cancel());compare(writes,0);compare(actions.actionState,"idle");}
    function test_confirm_once_and_completion(){verify(actions.request("profile",card,1,"Duplex"));verify(actions.confirm());compare(writes,1);verify(!actions.confirm());actions.finish(true,"Observed profile");compare(actions.actionState,"succeeded");}
    function test_other_review_lock(){provider.selectionActions=({locked:true});verify(!actions.request("profile",card,1,"Duplex"));compare(writes,0);}
    function test_context_expiry(){actions.request("profile",card,1,"Duplex");actions.context="";compare(actions.actionState,"idle");verify(!actions.confirm());compare(writes,0);}
    function test_stale_revision(){actions.request("profile",card,1,"Duplex");provider.graphSnapshot=({available:true,nodes:[],cards:[{token:card.token,revision:"changed"}],canMove:false});verify(!actions.confirm());compare(writes,0);compare(actions.actionState,"failed");}
    function test_provider_loss(){actions.request("profile",card,1,"Duplex");provider.graphSnapshot=({available:false,nodes:[],cards:[],canMove:false});actions.revalidate();compare(actions.actionState,"failed");compare(writes,0);}
    function test_running_context_and_failure(){actions.request("profile",card,1,"Duplex");actions.confirm();actions.context="";compare(actions.actionState,"running");actions.finish(false,"Unverified timeout");compare(actions.actionState,"failed");compare(writes,1);}
}
