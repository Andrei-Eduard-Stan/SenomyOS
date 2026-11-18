.pragma library

function reconcile(state,names) {
    function exists(name) { return !!name && names.indexOf(name)>=0; }
    if(state.primaryScreen && !exists(state.primaryScreen)) {
        if(state.activePrimary === "control" && names.length)
            state.primaryScreen=names[0];
        else {state.activePrimary="";state.primaryScreen="";}
    }
    if(state.activePopup) {
        const separator=state.activePopup.indexOf(":");
        const owner=separator>=0 ? state.activePopup.slice(separator+1) : "";
        if(!exists(owner)) {
            if(state.modalCancelRequested)state.modalCancelRequested();
            state.closePopups(undefined,undefined,true);
        }
    }
}

// Hyprland's workspace fullscreen flag also covers maximised clients. Only
// internal fullscreen bit 2 should yield the Rail; maximise keeps its reserve.
function trueFullscreen(workspace) {
    if(!workspace || !workspace.hasFullscreen)return false;
    const windows=workspace.toplevels ? workspace.toplevels.values : [];
    const modes=windows.map(w=>w.lastIpcObject ? w.lastIpcObject.fullscreen : undefined).filter(mode=>Number.isInteger(mode));
    return modes.some(mode=>(mode & 2)!==0);
}


// One output owns its Rail. The shared inventory already refreshes on native
// fullscreen, window movement, workspace and output lifecycle events.
function monitorFullscreen(monitor,windows) {
    if(!monitor)return false;
    if(!Array.isArray(windows))return trueFullscreen(monitor.activeWorkspace);
    const ids=[];
    if(monitor.activeWorkspace && Number.isInteger(monitor.activeWorkspace.id))ids.push(monitor.activeWorkspace.id);
    const special=monitor.lastIpcObject && monitor.lastIpcObject.specialWorkspace;
    if(special && Number.isInteger(special.id) && special.id!==0)ids.push(special.id);
    return windows.some(window=>window && window.workspace && ids.indexOf(window.workspace.id)>=0
        && window.monitor===monitor.id && Number.isInteger(window.fullscreen) && (window.fullscreen & 2)!==0);
}
