import Quickshell
import Quickshell.Networking

// Quickshell's NetworkManager backend is event driven. The service normalizes
// shared state without a resident nmcli poller or a machine-specific interface.
Scope {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property bool available: Networking.backend === NetworkBackendType.NetworkManager
    readonly property var managedDevices: devices.filter(device => device.nmManaged)
    readonly property bool networkingEnabled: available && managedDevices.length > 0
    readonly property bool wifiEnabled: available && Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: available && Networking.wifiHardwareEnabled
    readonly property var wifiDevices: devices.filter(device => device.type === DeviceType.Wifi)
    readonly property var wifiNetworks: wifiDevices.reduce((networks, device) =>
        networks.concat(device.networks.values), [])
    readonly property var sortedWifiNetworks: wifiNetworks.slice().sort((left, right) => {
        if (left.connected !== right.connected)
            return left.connected ? -1 : 1;
        if (left.known !== right.known)
            return left.known ? -1 : 1;
        return right.signalStrength - left.signalStrength;
    })
    readonly property var connectedWifi: wifiNetworks.find(network => network.connected) || null
    readonly property var connectedDevice: devices.find(device => device.connected) || null
    readonly property string activeConnection: connectedWifi ? connectedWifi.name
        : connectedDevice ? connectedDevice.name : ""
    readonly property string ssid: connectedWifi ? connectedWifi.name : ""
    readonly property real rawSignal: connectedWifi ? connectedWifi.signalStrength : 0
    readonly property int signalPercent: Math.round(Math.max(0, Math.min(100,
        rawSignal <= 1 ? rawSignal * 100 : rawSignal)))
    readonly property int connectionState: connectedWifi ? connectedWifi.state
        : connectedDevice ? connectedDevice.state : ConnectionState.Disconnected
    readonly property string connectionStateName: ConnectionState.toString(connectionState)
    readonly property int connectivity: Networking.connectivity
    readonly property string connectivityName: NetworkConnectivity.toString(connectivity)
    readonly property string primaryDevice: connectedDevice ? connectedDevice.name : ""
    readonly property string label: !available ? "N/A"
        : connectedWifi ? (signalPercent > 0 ? signalPercent + "%" : "WIFI")
        : connectedDevice ? "WIRED" : "OFF"
    readonly property string detail: {
        if (!available)
            return "NetworkManager backend unavailable";
        if (connectedWifi)
            return ssid + " · " + signalPercent + "% · " + connectivityName;
        if (connectedDevice)
            return activeConnection + " · " + connectivityName;
        if (!networkingEnabled)
            return "Networking unavailable or no managed devices";
        return wifiEnabled ? "No active connection" : "Wi-Fi disabled";
    }

    property bool scanning: false

    function setScanning(enabled) {
        scanning = enabled && wifiEnabled;
        for (const device of wifiDevices)
            device.scannerEnabled = scanning;
    }

    function toggleWifi() {
        if (!available || !wifiHardwareEnabled)
            return false;
        Networking.wifiEnabled = !Networking.wifiEnabled;
        if (!Networking.wifiEnabled)
            setScanning(false);
        return true;
    }

    function activate(network) {
        if (!network || network.stateChanging)
            return false;
        if (network.connected)
            network.disconnect();
        else if (network.known || network.security === WifiSecurityType.Open)
            network.connect();
        else
            return false;
        return true;
    }

    function openSecurePrompt(network) {
        if (!network || !network.name)
            return false;
        // Direct argv execution keeps the SSID out of shell interpolation;
        // NetworkManager owns the prompt and secret storage policy.
        Quickshell.execDetached([
            "kitty", "--title", "SenomyOS Wi-Fi authentication",
            "nmcli", "--ask", "device", "wifi", "connect", network.name
        ]);
        return true;
    }
}
