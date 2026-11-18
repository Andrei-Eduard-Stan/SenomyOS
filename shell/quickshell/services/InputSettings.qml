import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root
    readonly property var preferences: inputPreferences
    property alias active: inputPreferences.active
    readonly property bool available: inputPreferences.available
    readonly property bool firstRun: inputPreferences.firstRun
    readonly property bool busy: inputPreferences.busy
    readonly property real sensitivity: inputPreferences.sensitivity
    readonly property bool naturalScroll: inputPreferences.naturalScroll
    readonly property bool tapToClick: inputPreferences.tapToClick
    readonly property string layout: inputPreferences.layout
    readonly property bool usFallback: inputPreferences.usFallback
    readonly property int repeatRate: inputPreferences.repeatRate
    readonly property int repeatDelay: inputPreferences.repeatDelay
    readonly property var layouts: inputPreferences.layouts
    readonly property string message: inputPreferences.message
    function refresh() { inputPreferences.refresh(); }
    function apply() {
        inputPreferences.message="Reload the input page before previewing changes.";
        return false;
    }
    signal releasePrimaryFocusRequested()
    readonly property var oskController: keyboardController
    readonly property var oskAdapter: keyboardAdapter
    readonly property var oskAutomatic: automaticKeyboard
    OskAutomatic { id: automaticKeyboard; controller: keyboardController }
    OskAdapter {
        id: keyboardAdapter
        onTextFocusEvent: active => automaticKeyboard.textFocusEvent(active)
        onGeometryChanged: { if (!geometryRefresh.running) geometryRefresh.start(); }
        onProviderStarted: serial => keyboardController.started(serial)
        onProviderFailed: serial => keyboardController.failed(serial)
        onProviderExited: (serial, successful) => keyboardController.exited(serial, successful)
    }
    OskController {
        id: keyboardController
        provider: keyboardAdapter
        capabilities: root.oskCapabilities
        onReleasePrimaryFocusRequested: root.releasePrimaryFocusRequested()
    }
    // Debounce geometry bursts; native monitor reservations include every layer.
    property var geometryRefresh: Timer { interval: 32; onTriggered: Hyprland.refreshMonitors() }
    Component.onCompleted: refreshOskCapabilities()
    property var oskCapabilities: ({ok:false,providerInstalled:false,protocolState:"unknown",integrated:false,message:"OSK capabilities have not been checked."})
    function consumeOskCapabilities(text) {
        try {
            const result = JSON.parse(text);
            if (result.ok !== true || typeof result.providerInstalled !== "boolean"
                    || typeof result.message !== "string"
                    || ["unknown", "incompatible", "advertised"].indexOf(result.protocolState) < 0
                    || (result.providerInstalled && ["wvkbd-mobintl", "wvkbd-deskintl"].indexOf(result.provider) < 0))
                throw new Error("Invalid capability schema");
            // This probe proves no completed provider integration or visibility.
            result.integrated = false;
            result.manualCandidate = result.manualCandidate === true
                && result.providerInstalled && result.protocolState === "advertised";
            oskCapabilities = result;
        } catch (error) {
            oskCapabilities = ({ok:false,providerInstalled:false,protocolState:"unknown",integrated:false,message:"OSK capability data is invalid."});
        }
    }
    function refreshOskCapabilities() {
        if (!oskQuery.running) oskQuery.running = true;
    }
    Process {
        id: oskQuery
        command: ["python3", Quickshell.shellDir + "/scripts/osk-capabilities.py", "detect"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.consumeOskCapabilities(text);
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.oskCapabilities = ({ok:false,providerInstalled:false,protocolState:"unknown",integrated:false,message:"OSK capability detection failed."});
        }
    }
    property bool editorAvailable: false
    property bool engineInstalled: false
    property bool nativeToolsBusy: false
    property string nativeToolsMessage: ""
    property string nativeToolsState: "idle"
    property string nativeInterpreter:"python3"
    property bool nativeQueryPending:false
    function refreshNativeTools() {
        if (!nativeQueryPending&&!toolsQuery.running){nativeQueryPending=true;toolsQuery.exec([nativeInterpreter,Quickshell.shellDir+"/scripts/native-input-tools.py","detect"]);}
    }
    function openInputMethodSettings() {
        if (nativeToolsBusy || !editorAvailable) return false;
        nativeToolsBusy = true;
        nativeToolsState = "running";
        nativeToolsMessage = "Starting Fcitx5 settings…";
        toolsLaunch.running = true;
        return true;
    }
    Process {
        id: toolsQuery
        stdout:StdioCollector {id:nativeQueryOutput}
        onExited:(code,status)=>{
            root.nativeQueryPending=false;
            try {
                const result=JSON.parse(nativeQueryOutput.text);
                root.editorAvailable=code===0&&result.ok===true&&result.editorAvailable===true;
                root.engineInstalled=code===0&&result.ok===true&&result.engineInstalled===true;
                if(code!==0||result.ok!==true)root.nativeToolsMessage="Input-tool detection failed. Refresh to retry.";
            }catch(_){root.editorAvailable=false;root.engineInstalled=false;root.nativeToolsMessage="Input-tool detection failed. Refresh to retry.";}
        }
    }
    Process {
        id: toolsLaunch
        command: [root.nativeInterpreter, Quickshell.shellDir + "/scripts/native-input-tools.py", "open-ime"]
        stdout: StdioCollector {id:nativeLaunchOutput}
        onExited: (code, status) => {
            root.nativeToolsBusy = false;
            try {
                const result = JSON.parse(nativeLaunchOutput.text);
                root.nativeToolsState = code===0&&result.ok===true?result.state||"unverified":result.ok===true?"unverified":result.state||"failed";
                root.nativeToolsMessage = code!==0&&result.ok===true?"Input-tool launch could not be verified. Check whether its window opened before retrying.":result.message || "Input-tool launch failed.";
                if (result.state === "unavailable") root.editorAvailable = false;
            } catch (error) {
                root.nativeToolsState = "failed"; root.nativeToolsMessage = "Input-tool launch returned invalid data.";
            }
            if (root.nativeToolsState === "running") {
                root.nativeToolsState = "failed";
                root.nativeToolsMessage = "Input-tool launch did not return a result.";
            }
        }
    }
    Timer {
        interval:200;running:root.nativeToolsBusy&&!toolsLaunch.running||root.nativeQueryPending&&!toolsQuery.running
        onTriggered:{
            if(root.nativeToolsBusy&&!toolsLaunch.running){root.nativeToolsBusy=false;root.nativeToolsState="failed";root.nativeToolsMessage="Input-tool helper could not start. No application request was submitted; check Python and retry.";}
            if(root.nativeQueryPending&&!toolsQuery.running){root.nativeQueryPending=false;root.editorAvailable=false;root.engineInstalled=false;root.nativeToolsMessage="Input-tool detection helper could not start. Check Python and refresh.";}
        }
    }
    function cancelOskReviews() {
        keyboardController.cancelStart(); keyboardController.cancelStop();
    }
    onActiveChanged: {
        if (active) { refreshNativeTools(); refreshOskCapabilities(); }
        else cancelOskReviews();
    }
    InputPreferences {
        id: inputPreferences
        onDispatch: (verb, payload, serial) => {
            root.workerSerial=serial; root.workerStarted=false;
            worker.exec(["python3","-B",Quickshell.shellDir+"/scripts/input-settings.py",verb,
                verb === "get" ? String(serial) : payload]);
        }
    }
    property int workerSerial: 0
    property bool workerStarted: false
    Timer {
        interval: 150
        running: inputPreferences.busy && !root.workerStarted && !worker.running
        onTriggered: inputPreferences.transportFailed(root.workerSerial,"Input controller could not start. Check Python and its installation.")
    }
    Timer {
        interval: 35000
        running: inputPreferences.busy && root.workerStarted
        onTriggered: {
            inputPreferences.transportFailed(root.workerSerial,"Input controller timed out. Refresh before retrying; the compositor safety preview remains independent.");
            worker.running=false;
        }
    }
    Timer {
        interval: 5000
        running: (root.active || inputPreferences.pendingToken.length > 0) && !inputPreferences.busy
        repeat: true
        onTriggered: inputPreferences.refresh()
    }
    Process {
        id: worker
        onStarted: root.workerStarted=true
        stdout: StdioCollector { id: receipt }
        onExited: (code,status) => inputPreferences.consume(receipt.text,code,root.workerSerial)
    }
}
