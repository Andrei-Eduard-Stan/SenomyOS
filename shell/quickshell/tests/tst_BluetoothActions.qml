import QtQuick
import QtTest
import "../services"
TestCase {
    name:"BluetoothActionReview"
    property var writes:[]
    property var adapter:({id:"a",token:"a1",powered:true,name:"Adapter",expected:{Powered:true}})
    property var device:({id:"d",token:"d1",adapter:"a",name:"Earbuds",paired:true,connected:false,expected:{Paired:true,Connected:false}})
    QtObject {
        id:provider
        property bool available:true
        property var adapter:null
        property var devices:[]
        property bool targetBusy:false
        function objectFor(id){return adapter&&adapter.id===id?adapter:devices.find(x=>x.id===id) || null;}
        function isBusy(id){return targetBusy;}
        function send(request){writes.push(request);return true;}
    }
    BluetoothActions {id:guard;provider:provider;context:"fixture"}
    function init(){writes=[];guard.actionState="idle";guard.context="fixture";provider.available=true;provider.targetBusy=false;provider.adapter=adapter;provider.devices=[device];}
    function test_connect_is_explicit_immediate_request(){verify(guard.request("connect",device));compare(writes.length,1);compare(writes[0].action,"connect");compare(writes[0].path,"d");compare(writes[0].adapterToken,"a1");compare(guard.actionState,"idle");}
    function test_pair_does_not_trust_automatically(){verify(guard.request("pair",device));compare(writes.length,1);compare(writes[0].action,"pair");}
    function test_disruptive_changes_require_review(){for(const action of ["disconnect","forget","disable","trust","untrust","block","unblock","rename","discoverable","pairable"]){verify(guard.request(action,device,"Alias"));compare(writes.length,0);compare(guard.actionState,"pending");verify(guard.cancel());}compare(writes.length,0);}
    function test_confirm_once(){verify(guard.request("forget",device));verify(guard.confirm());verify(!guard.confirm());compare(writes.length,1);compare(writes[0].action,"forget");}
    function test_close_cancels_only_review(){verify(guard.request("disconnect",device));guard.context="";verify(!guard.confirm());compare(writes.length,0);}
    function test_stale_device_state(){verify(guard.request("disconnect",device));provider.devices=[Object.assign({},device,{expected:{Paired:true,Connected:true}})];verify(!guard.confirm());compare(writes.length,0);}
    function test_device_incarnation_changed(){verify(guard.request("forget",device));provider.devices=[Object.assign({},device,{token:"d2"})];verify(!guard.confirm());compare(writes.length,0);}
    function test_adapter_incarnation_changed(){verify(guard.request("forget",device));provider.adapter=Object.assign({},adapter,{token:"a2"});verify(!guard.confirm());compare(writes.length,0);}
    function test_missing_and_busy_devices_rejected(){provider.targetBusy=true;verify(!guard.request("connect",device));provider.targetBusy=false;provider.devices=[];verify(!guard.request("connect",device));compare(writes.length,0);}
    function test_bad_verb_or_closed_context(){verify(!guard.request("shell",device));guard.context="";verify(!guard.request("connect",device));compare(writes.length,0);}
}
