import QtQuick
import Quickshell
import Quickshell.Io

// All surfaces share one private, event-driven BlueZ transport. The adapter is
// needed because Quickshell 0.3.1 cannot expose method errors or cancel Connect.
Scope {
    id: root
    property bool transportEnabled: true
    property var snapshot: ({available:false,error:"Loading Bluetooth…",adapters:[],devices:[],operations:{},scan:{state:"idle",owned:false},prompt:null})
    property string actionContext: ""
    onActionContextChanged: if (transportEnabled && transport.running) send({command:"context",active:!!actionContext})
    readonly property bool available: snapshot.available === true
    readonly property var adapters: snapshot.adapters || []
    property string selectedAdapterId: ""
    readonly property var adapter: adapters.find(item=>item.id===selectedAdapterId) || adapters.find(item=>item.powered) || adapters[0] || null
    readonly property bool enabled: !!adapter && adapter.powered
    readonly property bool discovering: !!adapter && adapter.discovering
    readonly property string error: snapshot.error || ""
    readonly property var devices: (snapshot.devices || []).filter(item=>adapter && item.adapter===adapter.id)
    readonly property var connectedDevices: devices.filter(device=>device.connected)
    readonly property var operations: snapshot.operations || ({})
    readonly property var scan: snapshot.scan || ({state:"idle",owned:false})
    readonly property var prompt: snapshot.prompt || null
    property string selectedDeviceId: ""
    property string selectedDeviceToken: ""
    property string inspectorView:"overview"
    onSelectedDeviceTokenChanged:inspectorView="overview"
    readonly property var selectedDevice: devices.find(item=>item.id===selectedDeviceId && item.token===selectedDeviceToken) || null
    property alias actions: guardedActions
    BluetoothActions { id:guardedActions; provider:root; context:root.actionContext }
    signal stateEvent(string message, bool failed)
    function sameNameDevices(device) {
        if (!device || !device.identified) return [];
        const name=String(device.deviceName || device.name || "").trim().toLowerCase();
        return devices.filter(item=>item.id!==device.id && item.identified && String(item.deviceName || item.name || "").trim().toLowerCase()===name);
    }
    function identityHint(device) { return device && device.address ? "…"+device.address.split(":").slice(-3).join(":") : "Identity not reported"; }
    function deviceReport(device, identifiers) {
        if (!device) return {};
        const op=operation(device);
        const report={schemaVersion:1,source:"BlueZ",device:{name:device.name,remoteName:device.deviceName,address:identifiers?device.address:"Hidden",addressType:device.addressType,adapter:device.adapter.split("/").pop(),paired:device.paired,bonded:device.bonded,connected:device.connected,trusted:device.trusted,blocked:device.blocked,servicesResolved:device.servicesResolved,battery:device.battery,wakeAllowed:device.wakeAllowed,class:device.class,appearance:device.appearance,modalias:device.modalias,legacyPairing:device.legacyPairing,reconnectMode:device.reconnectMode,lastObservedAt:device.lastObservedAt,rssi:device.rssi,txPower:device.txPower,uuids:device.uuids,interfaces:device.interfaces,lastDisconnect:device.lastDisconnect || null},lastOperation:op?{action:op.action,state:op.phase,startedAt:op.startedAt,finishedAt:op.finishedAt,message:op.message,errorName:op.errorName,errorDetail:op.errorDetail}:null};
        if (identifiers) return report;
        return JSON.parse(JSON.stringify(report).replace(/(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}/g,"[redacted]").replace(/dev_(?:[0-9A-Fa-f]{2}_){5}[0-9A-Fa-f]{2}/g,"device_[redacted]"));
    }
    function objectFor(id) { return (snapshot.devices || []).concat(adapters).find(item=>item.id===id) || null; }
    function selectDevice(device) { selectedDeviceId=device ? device.id : ""; selectedDeviceToken=device ? device.token : ""; }
    function chooseAdapter(id) {
        if (guardedActions.locked) return false;
        send({command:"stopScan"}); selectedAdapterId=id; selectDevice(null); return true;
    }
    function operation(device) { const op=operations[typeof device === "string" ? device : device ? device.id : ""];return op && (!device || typeof device === "string" || op.token===device.token) ? op : null; }
    function isBusy(id) { const op=operation(id);return !!op && ["running","cancelling"].includes(op.phase); }
    function setEnabled(value) {return guardedActions.request(value?"enable":"disable",null);}
    function toggleConnection(device) {return device ? guardedActions.request(device.connected?"disconnect":device.paired?"connect":"pair",device):false;}
    function cancelOperation(device) {
        const op=operation(device);
        return !!op && op.phase==="running" && ["connect","pair"].includes(op.action) && send({command:"cancel",path:device.id,id:op.id});
    }
    function startScan() {return enabled && send({command:"scan",path:adapter.id});}
    function stopScan() {return send({command:"stopScan"});}
    function refresh() {
        if (transportEnabled && !transport.running) {transport.running=true;return true;}
        return send({command:"refresh"});
    }
    function answer(accept,value) {return !!prompt && send({command:"answer",id:prompt.id,accept:accept,value:value || ""});}
    function send(request) {
        if (!transportEnabled) { testRequest(request); return true; }
        if (!transport.running && request.command!=="request") return false;
        if (!transport.running) return guardedActions.fail("Bluetooth controller is unavailable. Choose Refresh to reconnect it.");
        transport.write(JSON.stringify(request)+"\n");return true;
    }
    signal testRequest(var request)
    function receive(data) {
        try {
            const result=JSON.parse(data);
            if (result.type === "state") {
                const previous=operations;
                snapshot=result.state;
                for (const key of Object.keys(result.state.operations || {})) {
                    const op=result.state.operations[key],before=previous[key];
                    if (["connect","pair","disconnect"].includes(op.action) && ["succeeded","failed"].includes(op.phase) && before && before.id===op.id && before.phase!==op.phase) {
                        const device=(result.state.devices || []).find(item=>item.id===key);
                        stateEvent((device?device.name+" · ":"")+op.message,op.phase==="failed");
                    }
                }
            } else if (result.type === "ack" && !result.ok) guardedActions.fail(result.message);
        } catch (error) { guardedActions.fail("Bluetooth returned an unreadable response. Choose Refresh."); }
    }
    Process {
        id:transport
        command:["python3","-B",Quickshell.shellDir+"/scripts/bluetooth-controller.py"]
        stdinEnabled:true
        running:root.transportEnabled
        stdout:SplitParser { onRead:data=>root.receive(data) }
        onStarted: root.send({command:"context",active:!!root.actionContext})
        onExited:{
            if (!root.transportEnabled) return;
            root.snapshot={available:false,error:!root.snapshot.available && root.snapshot.error && root.snapshot.error!=="Loading Bluetooth…" ? root.snapshot.error : "Bluetooth controller stopped. Choose Refresh to reconnect it.",adapters:[],devices:[],operations:{},scan:{state:"idle",owned:false},prompt:null};
        }
    }
}
