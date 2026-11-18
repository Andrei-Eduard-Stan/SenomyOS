import QtQuick

// One short-lived review, independent of per-device backend transactions.
// Closing a view cancels a review; it never abandons a running Connect.
QtObject {
    id: root
    required property var provider
    property string context: ""
    onContextChanged: cancel()
    property string actionState: "idle"
    readonly property bool locked: actionState === "pending"
    readonly property bool busy: false
    property string action: ""
    property string targetName: ""
    property string message: ""
    property var target: null
    property var requestData: null
    property string requestContext: ""
    property int sequence: 0
    readonly property string impact: action === "disable"
        ? "Bluetooth keyboards, mice and audio on this adapter will disconnect."
        : action === "disconnect" ? "Disconnect this device. You can reconnect it from the list."
        : action === "forget" ? "Remove this computer’s pairing and cached information. You may need to pair the device again. This is not a connection repair."
        : action === "remove" ? "Remove this unpaired device’s cached record. It may reappear if it continues advertising. No saved pairing is removed."
        : action === "wake" ? ((requestData && requestData.value?"Allow":"Prevent")+" this device waking the computer from suspend. Hardware wake support is independent of this permission.")
        : action === "trust" ? "Allow this known device to reconnect without asking. Trust only devices you recognize."
        : action === "untrust" ? "Stop allowing this device to reconnect without authorization."
        : action === "block" ? "Block incoming connections from this device. Its current connection may end."
        : action === "unblock" ? "Allow this device to request connections again."
        : action === "rename" ? (requestData && requestData.value ? "Rename the local alias to “"+requestData.value+"”. This affects only this computer." : "Reset the local alias to the device-provided name on this computer.")
        : action === "discoverable" ? "Change whether nearby devices can find this computer. Enabling lasts at most three minutes."
        : action === "pairable" ? "Change whether this computer accepts incoming pairing requests. Enabling lasts at most three minutes; requests are not automatically accepted."
        : "Turn on this Bluetooth adapter. Discovery starts only when you choose Scan."

    function valid() {
        if (!provider.available || !context || context !== requestContext || !requestData) return false;
        const current = provider.objectFor(requestData.path);
        const adapter = current ? provider.objectFor(current.adapter || current.id) : null;
        return !!adapter && adapter.token === requestData.adapterToken && !!current && current.token === requestData.token
            && JSON.stringify(current.expected) === JSON.stringify(requestData.expected)
            && !provider.isBusy(current.id);
    }
    function request(verb, device, value) {
        if (locked || !context || !provider.available) return false;
        const adapterVerb = ["enable","disable","discoverable","pairable"].includes(verb);
        const current = adapterVerb ? provider.adapter : provider.objectFor(device ? device.id : "");
        if (!current || provider.isBusy(current.id)) return false;
        if (!["enable","disable","connect","pair","disconnect","forget","trust","untrust","block","unblock","rename","discoverable","pairable","remove","wake"].includes(verb)) return false;
        action = verb; target = current; targetName = current.name+(provider.identityHint && current.address ? " · "+provider.identityHint(current):""); requestContext = context;
        requestData = {command:"request",action:verb,path:current.id,token:current.token,adapterToken:provider.objectFor(current.adapter || current.id).token,expected:JSON.parse(JSON.stringify(current.expected)),value:value === undefined ? null : value};
        if (!valid()) return fail("The device changed. Select the action again.");
        actionState = "pending"; message = "";
        // Explicit Connect/Pair are the routine primary actions. Disruptive
        // changes and trust/removal retain the shared review boundary.
        if (verb === "connect" || verb === "pair") return confirm();
        return true;
    }
    function fail(reason) { actionState="failed"; message=reason; requestData=null; target=null; return false; }
    function confirm() {
        if (actionState !== "pending") return false;
        if (!valid()) return fail("The device or its state changed. Nothing was changed; review again.");
        const request = requestData; request.requestId = String(++sequence);
        actionState="idle"; requestData=null; target=null;
        return provider.send(request);
    }
    function cancel() {
        if (actionState !== "pending") return false;
        actionState="idle"; requestData=null; target=null; message=""; return true;
    }
}
