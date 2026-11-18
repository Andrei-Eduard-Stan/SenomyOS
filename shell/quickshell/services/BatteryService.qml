import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Event-driven, capability-based battery aggregation. On dual-battery systems
// energy is weighted by each pack's real full-charge capacity.
Scope {
    id: root

    property var provider: UPower
    property var energy: energyService
    property bool energyEnabled: true
    property var care: careService
    BatteryCare { id: careService; enabled: root.energyEnabled && root.care === careService; context: root.actionContext; blocked: root.energy.busy || selectionGuard.locked }
    EnergyService { id: energyService; enabled: root.energyEnabled; active: root.actionContext !== "" }
    readonly property var batteries: provider.devices.values.filter(device =>
        device.ready && device.isLaptopBattery && device.isPresent)
    readonly property int count: batteries.length
    readonly property bool available: count > 0
    readonly property bool onBattery: provider.onBattery
    readonly property bool energyAvailable: count > 0 && batteries.every(device => Number.isFinite(device.energy) && device.energy >= 0 && Number.isFinite(device.energyCapacity) && device.energyCapacity > 0)
    readonly property bool displayChargeAvailable: Boolean(provider.displayDevice && provider.displayDevice.ready && provider.displayDevice.state !== UPowerDeviceState.Unknown && Number.isFinite(provider.displayDevice.percentage) && provider.displayDevice.percentage >= 0 && provider.displayDevice.percentage <= 1)
    readonly property real totalEnergy: energyAvailable ? batteries.reduce((sum, device) => sum + device.energy, 0) : 0
    readonly property real totalCapacity: energyAvailable ? batteries.reduce((sum, device) => sum + device.energyCapacity, 0) : 0
    readonly property real percentage: totalCapacity > 0
        ? Math.max(0, Math.min(1, totalEnergy / totalCapacity))
        : (displayChargeAvailable ? provider.displayDevice.percentage : 0)
    readonly property bool chargeAvailable: available && (energyAvailable || displayChargeAvailable)
    readonly property bool charging: batteries.some(device => device.state === UPowerDeviceState.Charging)
    readonly property string chargeState: !available ? "Unavailable" : charging ? "charging" : batteries.some(device => device.state === UPowerDeviceState.Discharging) ? "discharging" : batteries.every(device => device.state === UPowerDeviceState.FullyCharged) ? "fully charged" : batteries.some(device => device.state === UPowerDeviceState.PendingCharge) ? "waiting to charge" : batteries.some(device => device.state === UPowerDeviceState.PendingDischarge) ? "waiting to discharge" : onBattery ? "on battery · pack state unknown" : "external power · pack state unknown"
    readonly property double aggregateTimeSeconds: {
        const display = provider.displayDevice;
        if (!display || !display.ready)
            return 0;
        if(charging && display.state === UPowerDeviceState.Charging && Number.isFinite(display.timeToFull))return Math.max(0,display.timeToFull);
        if(onBattery && display.state === UPowerDeviceState.Discharging && Number.isFinite(display.timeToEmpty))return Math.max(0,display.timeToEmpty);
        return 0;
    }
    readonly property string timeLabel: {
        if (aggregateTimeSeconds <= 0)
            return "Unavailable";
        const minutes = Math.round(aggregateTimeSeconds / 60);
        return Math.floor(minutes / 60) + "h " + (minutes % 60) + "m";
    }
    readonly property bool low: available && chargeAvailable && percentage <= 0.20
    readonly property bool critical: available && chargeAvailable && percentage <= 0.08
    readonly property bool powerProfileAvailable: energy.available
    readonly property int powerProfile: toEnum(energy.profile)
    readonly property string powerProfileName: energy.profile || "Unavailable"
    readonly property string label: available && chargeAvailable ? Math.round(percentage * 100) + "%" : "N/A"
    readonly property string detail: {
        if (!available)
            return "No laptop battery exposed by UPower";
        const packs = count === 1 ? "1 pack" : count + " packs";
        return label + " · " + packs + " · " + chargeState + " · UPower energy estimate" + (energy.profile ? " · " + energy.profile : "");
    }

    readonly property var selectionBackend: powerProfileAvailable ? energy.identity : null
    property string actionContext: ""
    property string reviewToken: ""
    signal profileFailure(string message)
    property alias selectionActions: selectionGuard
    SelectionActions { id: selectionGuard; provider: root; context: root.actionContext; timeoutMs: 100000 }
    Connections {
        target: root.energy
        function onActionFailedChanged() {
            if (root.energy.actionFailed) {
                if (selectionGuard.actionState === "running") selectionGuard.fail(root.energy.actionError);
                root.profileFailure(root.energy.actionError);
            }
        }
    }

    function toEnum(name) { return name === "power-saver" ? PowerProfile.PowerSaver : name === "balanced" ? PowerProfile.Balanced : name === "performance" ? PowerProfile.Performance : -1; }
    function profileId(value) { return value === PowerProfile.PowerSaver ? "power-saver" : value === PowerProfile.Balanced ? "balanced" : value === PowerProfile.Performance ? "performance" : ""; }

    function selectionAvailable(kind) { return kind === "profile" && powerProfileAvailable && !care.locked; }
    function selectionOptions(kind) {
        if (!selectionAvailable(kind)) return [];
        return energy.profiles.map(toEnum).filter(value => value >= 0);
    }
    function selectionCurrent(kind) {
        // A watcher echo cannot prematurely turn an in-flight request into
        // success; the operation must complete with an actual verified receipt.
        if (energy.runningAction || energy.actionFailed) return null;
        return kind === "profile" && powerProfileAvailable ? powerProfile : null;
    }
    function selectionLabel(kind, profile) { return "Power profile: " + PowerProfile.toString(profile); }
    function selectionImpact(kind) {
        return "Change system power policy through " + (energy.backend.kind || "the provider") + ". Heat, fan noise and runtime may change. " + (energy.backend.semantics || "") + " No idle, lid or charge-threshold policy is changed by SenomyOS.";
    }
    function applySelection(kind, profile) {
        if (selectionGuard.actionState !== "running" || selectionGuard.kind !== kind
                || selectionGuard.target !== profile || !selectionGuard.valid()) return false;
        return energy.submit(profileId(profile), reviewToken);
    }
    function setPowerProfile(profile) {
        if (energy.busy || care.locked) return false;
        energy.actionFailed = false;
        reviewToken = energy.backend.token || "";
        return selectionGuard.request("profile", profile);
    }
}
