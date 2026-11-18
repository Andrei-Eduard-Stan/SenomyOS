import QtQuick

QtObject {
    id: root
    required property var provider
    property string context: ""
    property string actionState: "idle"
    property string title: ""
    property string impact: ""
    property string message: ""
    property var requestData: null
    property string requestContext: ""
    readonly property bool locked: actionState === "pending" || actionState === "running"
    function valid() {
        if (provider.ready===false || !context || context !== requestContext || !requestData || !provider.graphSnapshot.available) return false;
        const items = requestData.kind === "move" ? provider.graphSnapshot.nodes : provider.graphSnapshot.cards;
        const object = items.find(x => x.token === requestData.token && x.revision === requestData.revision);
        if (!object) return false;
        if (requestData.kind === "move") return provider.graphSnapshot.canMove && provider.graphSnapshot.nodes.some(x => x.token === requestData.target);
        return true;
    }
    function request(kind, object, target, targetName) {
        if (locked || provider.selectionActions.locked || !context || !object || !object.token) return false;
        requestData = ({kind:kind,token:object.token,revision:object.revision,target:target});
        requestContext = context;
        if (!valid()) { requestData=null; return false; }
        title = (kind === "move" ? "Route " : kind === "profile" ? "Profile: " : "Port: ") + object.name + " → " + targetName;
        impact = kind === "profile" ? "Changing the card profile may stop playback or recording and remove endpoints. The previous profile may need to be selected again to restore them."
            : kind === "port" ? "Change this device port. Playback or recording may move or pause. Review the reported route afterward."
            : "Move this individual stream to the selected device. Playback or recording may briefly pause. Other streams retain their routes.";
        message=""; actionState="pending"; return true;
    }
    function cancel() { if(actionState!=="pending")return false; actionState="idle"; requestData=null; return true; }
    function fail(reason) { actionState="failed"; message=reason; requestData=null; }
    function confirm() {
        if(actionState!=="pending")return false;
        if(!valid()) { fail("The provider, device or current route changed. Review it again.");return false; }
        actionState="running"; message="Waiting for observed provider state…";
        if(!provider.applyGraphRequest(requestData)) {fail("Audio operation could not start.");return false;}
        return true;
    }
    function finish(ok, reason) { if(actionState!=="running")return; actionState=ok?"succeeded":"failed";message=reason;requestData=null; }
    function revalidate() { if(actionState==="pending" && !valid())fail("Audio inventory changed. Nothing was changed; review again."); }
    onContextChanged: { cancel(); if(actionState!=="running")actionState="idle"; }
}
