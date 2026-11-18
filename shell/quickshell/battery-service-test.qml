import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "services"
Scope {
 id:tests
 function compare(a,b){if(a!==b){console.error("FAIL: expected "+b+", got "+a);Qt.exit(1);throw new Error("comparison");}}
 function verify(ok){if(!ok){console.error("FAIL: battery assertion");Qt.exit(1);throw new Error("assertion");}}
 BatteryService {id:battery;provider:source;energyEnabled:false}
 QtObject {id:source;property var devices:({values:[]});property bool onBattery:false;property var displayDevice:({ready:false,state:UPowerDeviceState.Unknown,percentage:0,timeToFull:0,timeToEmpty:0})}
 function pack(energy,capacity,state){return {ready:true,isLaptopBattery:true,isPresent:true,energy:energy,energyCapacity:capacity,state:state};}
 function init(){source.devices={values:[]};source.onBattery=false;source.displayDevice={ready:false,state:UPowerDeviceState.Unknown,percentage:0,timeToFull:0,timeToEmpty:0};}
 function test_capacity_weighted_dual_packs(){source.devices={values:[pack(10,10,UPowerDeviceState.Discharging),pack(0,90,UPowerDeviceState.Discharging)]};source.onBattery=true;compare(battery.count,2);compare(battery.percentage,0.1);verify(battery.low);}
 function test_ac_and_full_is_not_charging(){source.devices={values:[pack(10,10,UPowerDeviceState.FullyCharged)]};verify(!battery.charging);compare(battery.chargeState,"fully charged");compare(battery.timeLabel,"Unavailable");}
 function test_pending_charge_is_not_charging(){source.devices={values:[pack(5,10,UPowerDeviceState.PendingCharge)]};verify(!battery.charging);compare(battery.chargeState,"waiting to charge");compare(battery.aggregateTimeSeconds,0);}
 function test_reported_charging_has_matching_estimate(){source.devices={values:[pack(5,10,UPowerDeviceState.Charging)]};source.displayDevice={ready:true,state:UPowerDeviceState.Charging,timeToFull:1800,timeToEmpty:0,percentage:0.5};verify(battery.charging);compare(battery.timeLabel,"0h 30m");}
 function test_inconsistent_display_estimate_is_unavailable(){source.devices={values:[pack(5,10,UPowerDeviceState.Charging)]};source.displayDevice={ready:true,state:UPowerDeviceState.Unknown,timeToFull:1800,timeToEmpty:1000,percentage:0.5};compare(battery.timeLabel,"Unavailable");}
 function test_missing_charge_is_not_zero_percent_alert(){source.devices={values:[pack(0,0,UPowerDeviceState.Unknown)]};verify(!battery.chargeAvailable);compare(battery.label,"N/A");verify(!battery.low);verify(!battery.critical);}
 function test_absent_battery(){verify(!battery.available);compare(battery.count,0);compare(battery.timeLabel,"Unavailable");}

 Timer {interval:100;running:true;onTriggered:{tests.init();tests.test_capacity_weighted_dual_packs();tests.init();tests.test_ac_and_full_is_not_charging();tests.init();tests.test_pending_charge_is_not_charging();tests.init();tests.test_reported_charging_has_matching_estimate();tests.init();tests.test_inconsistent_display_estimate_is_unavailable();tests.init();tests.test_missing_charge_is_not_zero_percent_alert();tests.init();tests.test_absent_battery();console.log("PASS: seven battery aggregation cases: dual weighting, full/pending charge, reliable estimates and missing data");Qt.quit();}}
}
