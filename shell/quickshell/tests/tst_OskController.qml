import QtQuick
import QtTest
import "../services"
TestCase {
    id: test
    name: "OskController"
    when: true
    QtObject {
        id: fake
        property int owner: 0
        property int starts: 0
        property int shows: 0
        property int hides: 0
        property int stops: 0
        property bool acceptStart: true
        property bool acceptShow: true
        property bool acceptHide: true
        property bool acceptStop: true
        property string commandName: ""
        property int externalOwner: 999
        function owns(id) { return id === owner && owner > 0; }
        function start(name,id) { starts++; commandName=name; if (!acceptStart) return false; owner=id; return true; }
        function show(id) { if (!owns(id)) return false; shows++; return acceptShow; }
        function hide(id) { if (!owns(id)) return false; hides++; return acceptHide; }
        function stop(id) { if (!owns(id)) return false; stops++; return acceptStop; }
    }
    OskController { id: control; provider: fake }
    SignalSpy { id: focus; target: control; signalName: "releasePrimaryFocusRequested" }
    function candidate() { return {providerInstalled:true,protocolState:"advertised",manualCandidate:true,provider:"wvkbd-mobintl"}; }
    function init() {
        control.startupTimer.stop();control.startPending=false;control.serial=0;control.state="unavailable";
        fake.owner=0;fake.starts=0;fake.shows=0;fake.hides=0;fake.stops=0;fake.commandName="";
        fake.acceptStart=true;fake.acceptShow=true;fake.acceptHide=true;fake.acceptStop=true;
        control.capabilities=candidate();control.refreshState();focus.clear();
    }
    function requestLaunch() { verify(control.requestShow());compare(control.state,"pending-start");verify(control.confirmStart()); }
    function start() { requestLaunch();control.started(control.serial); }
    function test_start_confirmation_cancel_and_capability_change() {
        verify(!control.confirmStart());verify(control.requestShow());compare(control.state,"pending-start");compare(fake.starts,0);
        verify(!control.requestShow());verify(control.cancelStart());compare(control.state,"stopped");compare(fake.starts,0);
        verify(control.requestShow());control.capabilities={providerInstalled:false,protocolState:"unknown",manualCandidate:false,provider:""};
        verify(!control.confirmStart());compare(fake.starts,0);compare(control.state,"unavailable");
    }
    function test_unknown_absent_incompatible_and_unallowlisted() {
        for (const caps of [{providerInstalled:false,protocolState:"advertised",manualCandidate:false,provider:""},
            {providerInstalled:true,protocolState:"unknown",manualCandidate:true,provider:"wvkbd-mobintl"},
            {providerInstalled:true,protocolState:"incompatible",manualCandidate:true,provider:"wvkbd-mobintl"},
            {providerInstalled:true,protocolState:"advertised",manualCandidate:true,provider:"arbitrary-command"}]) {
            control.capabilities=caps;verify(!control.requestShow());compare(control.state,"unavailable");
        }
        compare(fake.starts,0);compare(focus.count,0);
    }
    function test_start_deduplicates_and_releases_focus_after_owned_start() {
        compare(control.state,"stopped");requestLaunch();compare(control.state,"starting");
        verify(!control.requestShow());compare(fake.starts,1);compare(focus.count,0);
        control.started(control.serial);compare(control.state,"show-requested");compare(fake.shows,1);compare(focus.count,1);
        compare(fake.commandName,"wvkbd-mobintl");verify(control.message.indexOf("unverified")>=0);
    }
    function test_show_hide_keep_one_owned_child() {
        start();verify(control.requestHide());compare(control.state,"hide-requested");
        verify(control.requestShow());compare(fake.starts,1);compare(fake.shows,2);compare(fake.hides,1);compare(fake.externalOwner,999);
    }
    function test_stop_requires_explicit_confirmation_and_cancel() {
        start();verify(!control.confirmStop());compare(fake.stops,0);
        verify(control.requestStop());compare(control.state,"pending-stop");compare(fake.stops,0);
        verify(!control.requestShow());verify(!control.requestHide());verify(control.cancelStop());compare(control.state,"show-requested");compare(fake.stops,0);
        verify(control.requestStop());verify(control.confirmStop());compare(fake.stops,1);compare(control.state,"stop-requested");
        verify(!control.confirmStop());verify(!control.requestShow());compare(fake.stops,1);
        fake.owner=0;control.exited(control.serial,true);compare(control.state,"stopped");
    }
    function test_removed_or_failed_launch_is_not_ready() {
        fake.acceptStart=false;verify(control.requestShow());verify(!control.confirmStart());compare(control.state,"failed");compare(fake.shows,0);compare(focus.count,0);
    }
    function test_child_ownership_required() {
        requestLaunch();fake.owner=0;control.started(control.serial);compare(control.state,"failed");compare(fake.shows,0);compare(focus.count,0);
    }
    function test_show_failure_does_not_release_focus() {
        fake.acceptShow=false;requestLaunch();control.started(control.serial);compare(control.state,"failed");compare(focus.count,0);
    }
    function test_hide_and_stop_failure_are_truthful() {
        start();fake.acceptHide=false;verify(!control.requestHide());compare(control.state,"failed");
        fake.acceptStop=false;verify(control.requestStop());verify(!control.confirmStop());compare(control.state,"failed");
    }
    function test_stale_callbacks_cannot_control_new_instance() {
        requestLaunch();const old=control.serial;fake.owner=0;control.failed(old);
        requestLaunch();const current=control.serial;verify(current>old);
        control.started(old);control.exited(old,true);control.failed(old);compare(control.state,"starting");compare(fake.shows,0);
        control.started(current);compare(control.state,"show-requested");compare(fake.shows,1);
    }
    function test_unexpected_exit_and_lost_ownership_do_not_signal_external_instance() {
        start();fake.owner=0;control.exited(control.serial,false);compare(control.state,"failed");
        verify(!control.requestHide());verify(!control.requestStop());compare(fake.hides,0);compare(fake.stops,0);compare(fake.externalOwner,999);
    }
    function test_capability_loss_does_not_kill_child_or_block_hide() {
        start();control.capabilities={providerInstalled:false,protocolState:"unknown",manualCandidate:false,provider:""};
        verify(control.owned);compare(fake.stops,0);verify(control.requestHide());
        fake.owner=0;control.exited(control.serial,true);compare(control.state,"unavailable");verify(!control.requestShow());
    }
    function test_startup_timeout_has_no_readiness_or_forced_stop() {
        control.startupTimer.interval=5;requestLaunch();wait(30);compare(control.state,"failed");compare(focus.count,0);compare(fake.stops,0);
        control.started(control.serial);compare(control.state,"failed");control.startupTimer.interval=12000;
    }
    function cleanup() { control.startupTimer.stop(); }
}
