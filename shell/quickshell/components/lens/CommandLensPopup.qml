import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../interaction" as Interaction
import "../../config" as Config
import "LensSearch.js" as Search
import "../../services" as Services

Interaction.QuickPopoverWindow {
    id: root
    readonly property string mode: coordinator ? coordinator.lensMode : "apps"
    property var applicationRows: DesktopEntries.applications.values.filter(a=>!a.noDisplay).map(a=>({
        kind:"apps",id:"apps:"+a.id,label:a.name,detail:a.genericName || "",
        keywords:[(a.keywords || []).join(" "),a.comment || ""].join(" "),icon:a.icon,object:a}))
    property var windowRows: Hyprland.toplevels.values.map(w=>{
        const ipc=w.lastIpcObject || {}, cls=String((w.wayland && w.wayland.appId) || ipc.class || ipc.initialClass || "");
        const entry=cls ? DesktopEntries.byId(cls) || DesktopEntries.heuristicLookup(cls) : null;
        const workspace=ipc.workspace || {};
        return {kind:"windows",id:"windows:"+w.address,label:w.title || cls || "Window",
            detail:[entry?entry.name:cls,workspace.name?"Workspace "+workspace.name:"",w.wayland && w.wayland.activated?"Focused":""].filter(Boolean).join(" · "),
            icon:entry?entry.icon:cls,focused:!!(w.wayland && w.wayland.activated),address:w.address,object:{activate:()=>{const request=Search.focusRequest(w.address,Hyprland.usingLua);if(request)Hyprland.dispatch(request);}}};
    })
    property var applicationLauncher:applicationLaunch
    property alias filesProvider: files
    property alias actionsProvider: actions
    property alias content: content
    property int session: 0
    property int inputRevision: 0
    property string providerError: ""
    readonly property bool loading: (mode==="all" || mode==="files") && files.loading || (mode==="all" || mode==="actions") && actions.loading
    readonly property bool activating: activation.running || applicationLauncher.busy
    // Do not parse/rank provider output while the native window acquires focus.
    // Offscreen provider fixtures override this binding because they never map.
    property bool providersReady: requestedOpen && cardShown && ownsEscape
    AppUsage {id:usage}
    readonly property bool hasAppUsage:applicationRows.some(row=>!!usage.apps[row.id.replace(/^apps:/,"")])
    readonly property var results: Search.search(applicationRows.concat(windowRows,files.rows,actions.rows),content.searchText,mode,mode!=="all",usage.apps,content.applicationSort)
    readonly property string statusText: providerError || (mode==="apps" && usage.error) || ((mode==="all" || mode==="files") && (files.error || files.notice)) || ((mode==="all" || mode==="actions") && (actions.error || actions.notice)) || (loading?"Updating local sources…":"")
    implicitWidth: Math.min(Config.DirectoryStyle.touchMode?680:640,Math.max(1,(targetScreen?targetScreen.width:800)-2*Config.Theme.screenInset))
    // Geometry depends only on the owning work area and input profile. Query,
    // provider status and scope changes update the list without moving the input.
    implicitHeight: Math.min(Config.DirectoryStyle.touchMode?600:560,Math.max(1,(targetScreen?targetScreen.height:800)-Config.Theme.railHeight-2*Config.Theme.screenInset))
    color:"transparent"
    anchor.item:anchorItem
    anchor.edges:Edges.Top
    anchor.gravity:Edges.Top
    anchor.rect.x:anchorItem?anchorItem.width/2:0
    anchor.rect.y:-12
    anchor.rect.width:0
    anchor.rect.height:0
    openDuration:Config.Motion.lensMs
    keyboardPriority:true
    waitForFirstFrame:true
    focusTarget:content.searchInput
    function setMode(value) {if(coordinator && ["all","apps","files","windows","actions"].includes(value))coordinator.lensMode=value;}
    function matches(text,query) {return Search.score({label:text,detail:""},query)>=0;}
    function parseRows(text) {return Search.parse(text,mode,Quickshell.env("HOME"));}
    function activate(index,reveal) {
        const row=results[index];
        if(!row || root.activating || (coordinator && !coordinator.allowInteraction()))return;
        providerError="";
        if(row.kind==="apps") {
            applicationLauncher.heldSession=session;applicationLauncher.heldRevision=inputRevision;
            applicationLauncher.heldGeneration=coordinator?coordinator.popupGeneration:0;
            // Quickshell 0.3.1 IDs omit the filename suffix; GIO IDs include it.
            applicationLauncher.request("desktop",String(row.object.id)+".desktop",[]);return;
        }
        if(row.kind==="windows") {
            if(row.kind==="windows" && row.address && !Hyprland.toplevels.values.some(w=>w.address===row.address)) {providerError="This window has closed. Choose another result.";return;}
            if(!dismiss())return;
            try {row.object.activate();}
            catch(error){console.warn("Command Lens activation failed: "+error);}
            return;
        }
        if(row.info==="__senomy_refresh__") {files.refreshIndex(true);return;}
        activation.heldSession=session;
        activation.heldRevision=inputRevision;
        activation.heldGeneration=coordinator?coordinator.popupGeneration:0;
        activation.output="";
        activation.command=["/usr/bin/env","ROFI_RETV="+(reveal && row.kind==="files"?"10":"1"),"ROFI_INFO="+row.info,row.kind==="files"?files.helper:actions.helper];
        activation.running=true;
    }
    Services.ApplicationLaunch {
        id:applicationLaunch
        property int heldSession:-1
        property int heldRevision:-1
        property int heldGeneration:-1
        onFinished:(accepted,detail)=>{
            if(!root.requestedOpen || heldSession!==root.session || heldRevision!==root.inputRevision || (root.coordinator && heldGeneration!==root.coordinator.popupGeneration))return;
            if(accepted)root.dismiss();else root.providerError=detail;
        }
    }
    LensProvider {id:files;kind:"files";wanted:root.providersReady && (root.mode==="all" || root.mode==="files");generation:root.session}
    LensProvider {id:actions;kind:"actions";wanted:root.providersReady && (root.mode==="all" || root.mode==="actions");generation:root.session}
    Process {
        id:activation
        property int heldSession:-1
        property int heldRevision:-1
        property int heldGeneration:-1
        property string output:""
        stdout:StdioCollector {onStreamFinished:activation.output=text}
        onExited:(code,status)=>{
            if(!root.requestedOpen || heldRevision!==root.inputRevision || heldSession!==root.session || (root.coordinator && heldGeneration!==root.coordinator.popupGeneration))return;
            if(code===0 && !output.trim())root.dismiss();
            else {root.providerError=Search.message(output) || "The selected item could not be opened. Try again.";console.warn("Command Lens activation exit "+code);}
        }
    }
    onModeChanged:{inputRevision++;content.resetSelection();providerError="";}
    onRequestedOpenChanged:{
        if(requestedOpen){usage.refresh();content.applicationSort="frequent";session++;content.searchText="";content.resetSelection();providerError="";}
    }
    LensContent {id:content;anchors.fill:parent;lens:root}
}
