import QtQuick
QtObject {
    id:root
    required property var provider
    property var target:null
    property string targetName:""
    property string providerIdentity:""
    property string actionState:"idle"
    property string message:""
    property double deadline:0
    property int timeoutMs:30000
    readonly property bool busy:actionState==="running"
    function start(network){
        if(busy||!provider.available||!network||provider.wifiNetworks.indexOf(network)<0||network.connected||network.stateChanging)return false;
        providerIdentity=provider.providerIdentity || "";target=network;targetName=String(network.name||"Wi-Fi network");deadline=Date.now()+timeoutMs;
        actionState="running";message="Waiting for NetworkManager to report connection to "+targetName+"…";return true;
    }
    function fail(reason){actionState="failed";message=reason;target=null;return false;}
    function observe(){
        if(!busy)return;
        if((provider.providerIdentity || "")!==providerIdentity||!provider.available||!provider.wifiEnabled||!provider.wifiHardwareEnabled||!target||provider.wifiNetworks.indexOf(target)<0||String(target.name||"Wi-Fi network")!==targetName){fail("Network or adapter changed. Connection completion could not be verified.");return;}
        if(target.connected&&!target.stateChanging){actionState="succeeded";message="NetworkManager reports "+targetName+" connected. Internet reachability is reported separately.";target=null;}
        else if(Date.now()>=deadline){actionState="unverified";message="Connection was not observed in time. The request may still finish; check current state before retrying.";target=null;}
    }
    property var targetObserver:Connections {
        target:root.target;ignoreUnknownSignals:true
        function onConnectionFailed(reason){if(root.busy)root.fail(root.provider.failureMessage(reason));}
        function onConnectedChanged(){root.observe();}
        function onStateChangingChanged(){root.observe();}
        function onNameChanged(){root.observe();}
    }
    property Timer observer:Timer {interval:250;repeat:true;running:root.busy;onTriggered:root.observe()}
}
