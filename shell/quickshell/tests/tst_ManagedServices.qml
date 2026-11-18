import QtQuick
import QtTest
import "../services"
TestCase {
    id: test
    name: "ManagedServices"
    when: true
    QtObject {
        id: fake
        property bool running: false
        property int calls: 0
        property var argv: []
        function exec(args) { calls++; argv=args; }
    }
    ServiceRestartActions { id: control; helper: "fixture.py"; runner: fake }
    function item(token) { return {unit:"pipewire.service",token:token || "a".repeat(64),restartAllowed:true,impact:"Audio may be interrupted."}; }
    function init() {
        control.active=false;control.blocked=false;control.cancel();control.actionState="idle";control.context="";
        control.items=[item()];control.active=true;control.context="performance:services";
        fake.running=false;fake.calls=0;fake.argv=[];
    }
    function test_review_cancel_and_explicit_confirm() {
        verify(!control.confirm());verify(control.request(item()));compare(fake.calls,0);verify(!control.request(item()));
        verify(control.cancel());compare(control.actionState,"idle");compare(fake.calls,0);
        verify(control.request(item()));verify(control.confirm());compare(fake.calls,1);
        compare(fake.argv[2],"restart-confirmed");compare(fake.argv[3],"pipewire.service");compare(fake.argv[4],item().token);
        verify(!control.confirm());verify(!control.cancel());verify(!control.request(item()));
    }
    function test_context_close_and_replacement_invalidate() {
        verify(control.request(item()));control.context="performance:overview";compare(control.actionState,"idle");verify(!control.confirm());
        verify(control.request(item()));control.active=false;compare(control.actionState,"idle");verify(!control.confirm());compare(fake.calls,0);
    }
    function test_changed_service_rejected() {
        verify(control.request(item()));control.items=[item("b".repeat(64))];verify(!control.confirm());compare(control.actionState,"failed");compare(fake.calls,0);
    }
    function test_missing_disabled_and_busy_rejected() {
        control.context="";verify(!control.request(item()));control.context="performance:services";
        const disabled=item();disabled.restartAllowed=false;verify(!control.request(disabled));
        control.items=[];verify(!control.request(item()));control.items=[item()];
        verify(control.request(item()));fake.running=true;verify(!control.confirm());compare(fake.calls,0);
    }
    function test_other_process_review_blocks_restart() {
        control.blocked=true;verify(!control.request(item()));control.blocked=false;
        verify(control.request(item()));control.blocked=true;verify(!control.confirm());compare(fake.calls,0);
    }
    function test_observed_unverified_failure_and_invalid_output() {
        for (const value of ["succeeded","unverified"]) {
            control.actionState="running";control.completed(0,JSON.stringify({ok:true,data:{state:value,message:"Observed"}}));compare(control.actionState,value);
        }
        control.completed(1,JSON.stringify({ok:false,error:{message:"Provider failed"}}));compare(control.actionState,"failed");compare(control.message,"Provider failed");
        control.completed(0,"bad");compare(control.actionState,"failed");
    }
}
