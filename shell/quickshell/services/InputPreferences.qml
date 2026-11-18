import QtQuick

// One state owner; transport is supplied by InputSettings, or an inert test.
QtObject {
    id: root
    property bool active: false
    property bool available: false
    property bool busy: false
    property bool firstRun: true
    property bool dirty: false
    property bool staleDraft: false
    property bool revertAfterApply: false
    property int serial: 0
    property string operation: ""
    property string state: "unavailable"
    property string message: "Input values have not been read."
    property string fingerprint: ""
    property string draftFingerprint: ""
    property string persistence: "not-saved"
    property bool externalConflict: false
    property bool persistenceReady: false
    property var rawOptions: ({})
    property var effective: ({})
    property var draft: ({})
    property var saved: ({})
    property var requested: ({})
    property var capabilities: ({})
    property var devices: []
    property var layouts: []
    property var variants: ({})
    property var pending: ({state:"none",token:""})
    readonly property string pendingToken: pending.state === "preview" ? pending.token : ""
    readonly property bool locked: busy || pendingToken.length > 0
    readonly property real sensitivity: Number(effective.sensitivity || 0)
    readonly property bool naturalScroll: effective.naturalScroll === true
    readonly property bool tapToClick: effective.tapToClick === true
    readonly property string layout: String(effective.layout || "")
    readonly property bool usFallback: effective.usFallback === true
    readonly property int repeatRate: Number(effective.repeatRate || 0)
    readonly property int repeatDelay: Number(effective.repeatDelay || 0)
    signal dispatch(string operation, string payload, int serial)

    function begin(verb, payload) {
        if (busy) return false;
        serial++; operation=verb; busy=true;
        if (verb !== "get") { state="pending"; message="Waiting for the input controller…"; }
        payload.requestId=String(serial);
        dispatch(verb, JSON.stringify(payload), serial);
        return true;
    }
    function refresh() { return begin("get",{}); }
    function resetDraft() {
        draft=Object.assign({},effective); draftFingerprint=fingerprint;
        dirty=false; staleDraft=false;
    }
    function edit(key,value) {
        if (locked || !available || capabilities[key] !== true) return false;
        if (!dirty) draftFingerprint=fingerprint;
        let next=Object.assign({},draft); next[key]=value;
        if (key === "layout") { next.variant=""; if (value === "us") next.usFallback=false; }
        draft=next;
        dirty=Object.keys(next).some(k=>next[k] !== effective[k]);
        return true;
    }
    function applyDraft(part) {
        if (locked || !available || staleDraft) return false;
        let changes={};
        Object.keys(draft).forEach(k=>{if (draft[k] !== effective[k]) changes[k]=draft[k];});
        if (Object.keys(changes).length === 0 && firstRun) {
            const keys=part === "keyboard" ? ["layout","variant","usFallback","repeatRate","repeatDelay"]
                : ["sensitivity","naturalScroll","tapToClick","mouseNaturalScroll","mouseScrollFactor","touchpadScrollFactor","disableWhileTyping","leftHanded"];
            keys.forEach(k=>{if (capabilities[k] === true) changes[k]=draft[k];});
        }
        if (["layout","variant","usFallback"].some(k=>changes[k] !== undefined))
            ["layout","variant","usFallback"].forEach(k=>changes[k]=draft[k]);
        if (Object.keys(changes).length === 0) return false;
        requested=changes;
        return begin("apply",{changes:changes,fingerprint:draftFingerprint});
    }
    function confirm() { return pendingToken && !busy ? begin("confirm",{token:pendingToken}) : false; }
    function revert() { return pendingToken && !busy ? begin("revert",{token:pendingToken}) : false; }
    function transportFailed(id,detail) {
        if (id !== serial || !busy) return;
        busy=false; available=false; state="transport-failed"; message=detail;
        if (pendingToken) pending={state:"unknown",token:pending.token};
        // The compositor timer remains independent of this transport/UI.
    }
    function validEffective(value) {
        if (!value || typeof value !== "object") return false;
        const numeric=["sensitivity","repeatRate","repeatDelay","mouseScrollFactor","touchpadScrollFactor"];
        const boolean=["naturalScroll","tapToClick","usFallback","mouseNaturalScroll","disableWhileTyping","leftHanded"];
        return numeric.every(k=>typeof value[k] === "number" && isFinite(value[k]))
            && boolean.every(k=>typeof value[k] === "boolean")
            && typeof value.layout === "string" && typeof value.variant === "string";
    }
    function consume(text,exitCode,id) {
        if (id !== serial || !busy) return false;
        let response;
        try {
            response=JSON.parse(text);
            if (response.schemaVersion !== 2 || response.requestId !== String(id)
                    || typeof response.ok !== "boolean" || typeof response.state !== "string"
                    || typeof response.message !== "string" || (response.ok && exitCode !== 0)
                    || (response.available === true && (!validEffective(response.effective)
                        || !response.capabilities || !Array.isArray(response.devices)
                        || typeof response.fingerprint !== "string" || !response.pending
                        || typeof response.pending.state !== "string" || typeof response.pending.token !== "string"))
                    || (response.state === "applied-verified" && (response.ok !== true || response.persisted !== true)))
                throw new Error("Invalid receipt");
        } catch (_) {
            transportFailed(id,"Input controller returned invalid data. Refresh before retrying; an active safety preview still expires automatically.");
            return false;
        }
        busy=false;
        const previousPending=pendingToken;
        if (response.available === true) {
            effective=response.effective; rawOptions=response.rawOptions || {}; capabilities=response.capabilities; devices=response.devices;
            layouts=response.layouts || []; variants=response.variants || {};
            fingerprint=response.fingerprint; saved=response.saved || {};
            persistence=response.persistence || "not-saved"; firstRun=response.firstRun === true; persistenceReady=response.persistenceReady === true;
            externalConflict=response.externalConflict === true; pending=response.pending;
            if (operation !== "get" || !dirty) resetDraft();
            else staleDraft=draftFingerprint !== fingerprint;
        }
        available=response.available === true;
        if (!available) {
            if (pendingToken) pending={state:"unknown",token:pending.token};
            state=response.state; message=response.message;
        } else if (operation !== "get") { state=response.state; message=response.message; }
        else if (previousPending && !pendingToken) {
            state=pending.state;
            message=pending.state === "rolled-back" ? "Preview ended; previous compositor values restored. Nothing was saved."
                : "Preview ended or configuration changed. Review current values before retrying.";
        } else if (response.message) message=response.message;
        else if (state === "unavailable" || state === "transport-failed") { state="observed"; message="Current global compositor values read. Device overrides and physical effects are not verified."; }
        if (pendingToken && (pending.deviceChanged === true || revertAfterApply || !active)) {
            revertAfterApply=false; revert();
        }
        return true;
    }
    onActiveChanged: {
        if (active) refresh();
        else if (busy && operation === "apply") revertAfterApply=true;
        else if (pendingToken) revert();
    }
}
