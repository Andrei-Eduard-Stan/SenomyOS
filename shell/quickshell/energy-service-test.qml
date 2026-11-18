import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "services"
import "services/SystemHealth.js" as Health

Scope {
    id: suite
    function verify(value) { if (!value) throw new Error("Energy assertion failed"); }
    function compare(a, b) { if (a !== b) throw new Error("Expected " + b + ", got " + a); }
    BatteryService { id: battery; provider: source; energy: fake; energyEnabled: false; actionContext: "test-power" }
    EnergyService { id: transport; enabled: false }
    QtObject {
        id: fake
        property bool available: true
        property string profile: "balanced"
        property string identity: "owner-1"
        property var profiles: ["balanced", "power-saver", "performance"]
        property var backend: ({kind:"tlp",token:"token",semantics:"runtime"})
        property bool busy: false
        property bool runningAction: false
        property bool actionFailed: false
        property string actionError: "Denied"
        property int submissions: 0
        function submit(name, token) {
            if (token !== backend.token) return false;
            submissions++; busy = true; runningAction = true; return true;
        }
    }
    QtObject {
        id: source
        property var devices: ({values:[]})
        property bool onBattery: true
        property var displayDevice: ({ready:false, state:UPowerDeviceState.Unknown})
    }
    function pack(energy, capacity, state) { return {ready:true,isLaptopBattery:true,isPresent:true,energy:energy,energyCapacity:capacity,state:state}; }
    function init() {
        if (battery.selectionActions.actionState === "pending") battery.selectionActions.cancel();
        battery.selectionActions.actionState="idle";
        fake.available=true;fake.profile="balanced";fake.identity="owner-1";fake.backend={kind:"tlp",token:"token",semantics:"runtime"};
        fake.profiles=["balanced","power-saver","performance"];fake.busy=false;fake.runningAction=false;fake.actionFailed=false;fake.submissions=0;
        source.devices={values:[]};source.onBattery=true;source.displayDevice={ready:false,state:UPowerDeviceState.Unknown};
    }
    function test_review_and_cancel_never_submit() {
        verify(battery.setPowerProfile(PowerProfile.PowerSaver));compare(fake.submissions,0);
        verify(battery.selectionActions.cancel());compare(fake.submissions,0);
    }
    function test_pending_blocks_conflicts_and_echo_waits_for_receipt() {
        verify(battery.setPowerProfile(PowerProfile.PowerSaver));verify(!battery.setPowerProfile(PowerProfile.Performance));
        verify(battery.selectionActions.confirm());compare(fake.submissions,1);
        fake.profile="power-saver";battery.selectionActions.observe();compare(battery.selectionActions.actionState,"running");
        fake.runningAction=false;fake.busy=false;battery.selectionActions.observe();compare(battery.selectionActions.actionState,"succeeded");
    }
    function test_refusal_does_not_become_success_on_watcher_echo() {
        verify(battery.setPowerProfile(PowerProfile.PowerSaver));battery.selectionActions.confirm();
        fake.profile="power-saver";fake.actionFailed=true;fake.runningAction=false;
        battery.selectionActions.observe();compare(battery.selectionActions.actionState,"failed");
    }
    function test_owner_and_source_drift_refuse_before_submission() {
        battery.setPowerProfile(PowerProfile.PowerSaver);fake.identity="replacement";
        verify(!battery.selectionActions.confirm());compare(fake.submissions,0);
        init();battery.setPowerProfile(PowerProfile.PowerSaver);fake.backend={kind:"tlp",token:"new-source",semantics:"runtime"};
        verify(!battery.selectionActions.confirm());compare(fake.submissions,0);
    }
    function test_late_provider_availability_and_external_profile() {
        fake.available=false;verify(!battery.powerProfileAvailable);compare(battery.selectionOptions("profile").length,0);
        fake.available=true;compare(battery.selectionOptions("profile").length,3);
        fake.profile="performance";compare(battery.powerProfile,PowerProfile.Performance);
        fake.available=false;verify(!battery.setPowerProfile(PowerProfile.PowerSaver));
    }
    function test_weighted_physical_packs_exclude_synthetic_device() {
        const a=pack(10,20,UPowerDeviceState.Discharging), b=pack(10,80,UPowerDeviceState.PendingDischarge), display=pack(80,100,UPowerDeviceState.Discharging);
        display.isLaptopBattery=false;
        source.devices={values:[a,b,display]};compare(battery.count,2);compare(battery.percentage,.2);compare(battery.chargeState,"discharging");
        source.devices={values:[a]};compare(battery.percentage,.5);
        source.devices={values:[]};verify(!battery.available);verify(!battery.critical);
    }
    function test_invalid_pack_energy_and_time_are_not_zero_alerts() {
        source.devices={values:[pack(NaN,20,UPowerDeviceState.Unknown)]};verify(!battery.chargeAvailable);compare(battery.label,"N/A");
        const metrics={memoryTotalKib:1,memoryPercent:1,ready:true,cpuPercent:1};const network={available:false};
        verify(Health.observation(metrics,battery,network).id !== "battery-critical");
        source.displayDevice={ready:true,state:UPowerDeviceState.Discharging,percentage:.5,timeToEmpty:NaN};
        verify(battery.chargeAvailable);compare(battery.percentage,.5);compare(battery.timeLabel,"Unavailable");
    }
    function test_threshold_wait_is_not_charging_on_ac() {
        source.onBattery=false;source.devices={values:[pack(8,10,UPowerDeviceState.PendingCharge)]};
        verify(!battery.charging);compare(battery.chargeState,"waiting to charge");verify(!battery.critical);
    }
    function test_invalid_observation_removes_profile_controls_only() {
        source.devices={values:[pack(8,10,UPowerDeviceState.Discharging)]};
        verify(transport.adopt({schemaVersion:1,ok:true,backend:{available:true,active:"balanced",profiles:["balanced"],identity:"bus-owner"}}));
        verify(transport.available);verify(!transport.adopt({ok:false,message:"bus gone"}));verify(!transport.available);verify(battery.available);
    }
    Timer { interval:100; running:true; onTriggered: {
        let count=0;
        try {
            for (const name of Object.keys(suite)) if (name.startsWith("test_")) { suite.init(); suite[name](); count++; }
            if (count !== 9) throw new Error("Expected 9 cases, got " + count);
            console.log("PASS: " + count + " native energy/battery/state integration cases"); Qt.quit();
        } catch(e) { console.error("FAIL: " + e.stack); Qt.exit(1); }
    }}
}
