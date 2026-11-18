import QtQuick
import Quickshell
import Quickshell.Networking

// Quickshell's NetworkManager backend is event driven. The service normalizes
// shared state without a resident nmcli poller or a machine-specific interface.
Scope {
    id: root

    property var networking: Networking
    readonly property var devices: networking.devices.values
    readonly property string providerIdentity: profileService.providerIdentity
    readonly property bool available: networking.backend === NetworkBackendType.NetworkManager && (!profileService.queryEnabled || profileService.providerAvailable)
    readonly property var managedDevices: devices.filter(device => device.nmManaged)
    readonly property bool networkingEnabled: available && (profileService.providerAvailable ? profileService.status.networkingEnabled === true : managedDevices.length > 0)
    readonly property bool wifiEnabled: available && networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: available && networking.wifiHardwareEnabled
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
    readonly property var connectedDevice: devices.find(device => device.connected && device.name === profileService.status.primaryDevice)
        || (!profileService.status.primaryDevice ? devices.find(device => device.connected) || null : null)
    readonly property var connectedWifi: wifiNetworks.find(network => network.connected && network.device === connectedDevice) || null
    readonly property string activeConnection: !available ? "" : profileService.status.primaryConnection || (connectedWifi ? connectedWifi.name
        : connectedDevice ? connectedDevice.name : "")
    readonly property string ssid: available && connectedWifi ? connectedWifi.name : ""
    readonly property real rawSignal: connectedWifi ? connectedWifi.signalStrength : 0
    readonly property int signalPercent: Math.round(Math.max(0, Math.min(100,
        rawSignal <= 1 ? rawSignal * 100 : rawSignal)))
    readonly property int connectionState: profileService.status.primaryConnection ? ConnectionState.Connected : connectedWifi ? connectedWifi.state
        : connectedDevice ? connectedDevice.state : ConnectionState.Disconnected
    readonly property string connectionStateName: ConnectionState.toString(connectionState)
    readonly property int connectivity: !available ? NetworkConnectivity.Unknown : profileService.providerAvailable ? ({full:NetworkConnectivity.Full,portal:NetworkConnectivity.Portal,limited:NetworkConnectivity.Limited,none:NetworkConnectivity.None,unknown:NetworkConnectivity.Unknown}[profileService.status.connectivity] || NetworkConnectivity.Unknown) : networking.connectivity
    readonly property string connectivityName: NetworkConnectivity.toString(connectivity)
    readonly property string primaryDevice: !available ? "" : profileService.status.primaryDevice || (connectedDevice ? connectedDevice.name : "")
    readonly property string label: !available ? "N/A"
        : connectedWifi ? (signalPercent > 0 ? signalPercent + "%" : "WIFI")
        : connectedDevice ? "WIRED" : activeConnection ? "NET" : "OFF"
    readonly property string detail: {
        if (!available)
            return profileService.error || "NetworkManager backend unavailable";
        if (connectedWifi)
            return ssid + " · " + signalPercent + "% · " + connectivityName;
        if (activeConnection)
            return activeConnection + " · " + connectivityName;
        if (!networkingEnabled)
            return "Networking unavailable or no managed devices";
        return wifiEnabled ? "No active connection" : "Wi-Fi disabled";
    }

    property alias profiles: profileService
    property alias connectionAttempt: attempt
    readonly property bool profileActionsLocked: profileService.actions.locked
    readonly property bool connectionAttemptBusy: attempt.busy
    readonly property bool authenticationAvailable: profileService.authenticationAvailable
    NetworkProfiles { id: profileService; active: Boolean(root.actionContext); context: root.actionContext; blocked: guardedActions.locked || attempt.busy }
    ConnectionAttempt { id: attempt; provider: root }
    function failureMessage(reason) {
        switch(reason) {
        case ConnectionFailReason.NoSecrets: return "Authentication is missing or was rejected. Review saved-profile credentials in the native editor or retry secure authentication.";
        case ConnectionFailReason.WifiAuthTimeout: return "Wi-Fi authentication timed out. Check access-point availability and credentials.";
        case ConnectionFailReason.WifiNetworkLost: return "The Wi-Fi network was lost. Check signal and adapter state, then refresh.";
        case ConnectionFailReason.WifiClientDisconnected: return "The Wi-Fi client disconnected during connection. Check current state before retrying.";
        case ConnectionFailReason.WifiClientFailed: return "The Wi-Fi client reported connection failure. Check current state and native network settings.";
        default: return "NetworkManager reported connection failure. Check the authentication terminal or native profile editor before retrying.";
        }
    }
    readonly property var radio: networking
    property string actionContext: ""
    property alias actions: guardedActions
    NetworkActions { id: guardedActions; provider: root; context: root.actionContext }

    onAvailableChanged:if(!available)setScanning(false)
    onWifiDevicesChanged:if(scanning){if(wifiDevices.length)setScanning(true);else setScanning(false);}
    onWifiEnabledChanged: if (!wifiEnabled) setScanning(false)
    onActionContextChanged: if (!actionContext) setScanning(false)
    property var scannedDevices:[]
    property bool scanning: false
    property string scanMessage: ""

    function setScanning(enabled) {
        const next=enabled&&wifiEnabled?wifiDevices.slice():[];
        for(const old of scannedDevices)if(next.indexOf(old)<0){try{if(old)old.scannerEnabled=false;}catch(_){}}
        scannedDevices=next;scanning=next.length>0;
        for(const device of next)device.scannerEnabled=true;
    }

    function refreshNetworks() {
        if (!actionContext || !available || !wifiEnabled || !wifiHardwareEnabled
                || guardedActions.locked || profileActionsLocked || attempt.busy || scanning || wifiDevices.length === 0)
            return false;
        scanMessage="Requesting a fresh NetworkManager scan.";
        setScanning(true);
        scanRelease.restart();
        return true;
    }

    Timer {
        id: scanRelease
        interval: 10000
        onTriggered: {
            root.setScanning(false);
            root.scanMessage="Scan window complete; results remain event-driven.";
        }
    }

    function toggleWifi() {
        if (!actionContext || !available || !wifiHardwareEnabled || guardedActions.locked || profileActionsLocked || attempt.busy)
            return false;
        if (wifiEnabled)
            return guardedActions.request("disable", null);
        networking.wifiEnabled = true;
        return true;
    }

    function activate(network) {
        if (!actionContext || !available || !wifiEnabled || !wifiHardwareEnabled || guardedActions.locked || profileActionsLocked || attempt.busy
                || !network || wifiNetworks.indexOf(network) < 0 || network.stateChanging)
            return false;
        if (network.connected)
            return guardedActions.request("disconnect", network);
        else if (network.known || network.security === WifiSecurityType.Open) {
            if (!attempt.start(network)) return false;
            try { network.connect(); }
            catch (_) { return attempt.fail("NetworkManager rejected the connection request. Check current state before retrying."); }
        }
        else
            return false;
        return true;
    }

    property string handoffMessage:""
    ApplicationLaunch {id:portalLaunch;onFinished:(accepted,detail)=>root.handoffMessage=accepted?"Browser handoff accepted; sign-in and connectivity are not yet verified.":detail;}
    function openPortal(){
        const status=profileService.status,uri=status.portalUri||"";
        if(!actionContext||!available||status.connectivity!=="portal"||!uri||guardedActions.locked||profileActionsLocked||attempt.busy)return false;
        return portalLaunch.request("open",uri,[]);
    }
    ApplicationLaunch {id:authenticationLaunch;onFinished:(accepted,detail)=>{if(!accepted)attempt.fail(detail);}}
    function openSecurePrompt(network) {
        if (!actionContext || !available || !wifiEnabled || !wifiHardwareEnabled || guardedActions.locked || profileActionsLocked || attempt.busy
                || !authenticationAvailable || !network || wifiNetworks.indexOf(network) < 0 || !network.name
                || network.connected || network.stateChanging || network.known
                || network.security === WifiSecurityType.Open)
            return false;
        // Direct argv execution keeps the SSID out of shell interpolation;
        // NetworkManager owns the prompt and secret storage policy.
        if (!attempt.start(network)) return false;
        if (String(network.name).startsWith("-")) return attempt.fail("This network name requires the native editor for secure authentication.");
        if(!network.device || wifiDevices.indexOf(network.device)<0 || !network.device.nmManaged || !/^[A-Za-z0-9_][A-Za-z0-9_.:-]{0,63}$/.test(network.device.name))return attempt.fail("The selected Wi-Fi adapter changed or is unmanaged. Refresh before retrying.");
        if(!authenticationLaunch.request("tool","wifi-auth-interface",[network.name,network.device.name]))return attempt.fail("Authentication terminal launch is already pending.");
        return true;
    }
}
