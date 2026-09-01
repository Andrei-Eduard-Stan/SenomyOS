import Quickshell
import Quickshell.Services.UPower

// Event-driven, capability-based battery aggregation. On dual-battery systems
// energy is weighted by each pack's real full-charge capacity.
Scope {
    id: root

    readonly property var batteries: UPower.devices.values.filter(device =>
        device.ready && device.isLaptopBattery && device.isPresent)
    readonly property int count: batteries.length
    readonly property bool available: count > 0
    readonly property bool onBattery: UPower.onBattery
    readonly property real totalEnergy: batteries.reduce((sum, device) => sum + device.energy, 0)
    readonly property real totalCapacity: batteries.reduce((sum, device) => sum + device.energyCapacity, 0)
    readonly property real percentage: totalCapacity > 0
        ? Math.max(0, Math.min(1, totalEnergy / totalCapacity))
        : (UPower.displayDevice && UPower.displayDevice.ready ? UPower.displayDevice.percentage : 0)
    readonly property bool charging: available && !onBattery
    readonly property string label: available ? Math.round(percentage * 100) + "%" : "N/A"
    readonly property string detail: {
        if (!available)
            return "No laptop battery exposed by UPower";
        const packs = count === 1 ? "1 pack" : count + " packs";
        return label + " · " + packs + (charging ? " · charging" : " · on battery");
    }
}
