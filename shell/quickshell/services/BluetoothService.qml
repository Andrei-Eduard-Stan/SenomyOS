import Quickshell
import Quickshell.Bluetooth

Scope {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool discovering: available && adapter.discovering
    readonly property var devices: Bluetooth.devices.values.slice().sort((left, right) => {
        if (left.connected !== right.connected)
            return left.connected ? -1 : 1;
        if (left.paired !== right.paired)
            return left.paired ? -1 : 1;
        return (left.name || left.deviceName || left.address).localeCompare(
            right.name || right.deviceName || right.address);
    })
    readonly property var connectedDevices: devices.filter(device => device.connected)
    property bool pageActive: false

    function setEnabled(value) {
        if (!available)
            return false;
        adapter.enabled = value;
        if (!value)
            adapter.discovering = false;
        return true;
    }

    function setDiscovery(value) {
        if (!available || !adapter.enabled)
            return false;
        adapter.discovering = value;
        return true;
    }

    function toggleConnection(device) {
        if (!device || device.pairing)
            return false;
        if (device.connected)
            device.disconnect();
        else if (device.paired)
            device.connect();
        else
            device.pair();
        return true;
    }

    onPageActiveChanged: setDiscovery(pageActive)
}
