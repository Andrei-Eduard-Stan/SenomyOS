import QtQuick
import QtTest
import "../services/ScreenLifecycle.js" as Screens

TestCase {
    name: "ScreenLifecycle"
    function state() {
        return {primaryScreen:"A",activePrimary:"control",activePopup:"volume:B",
            closePrimary:function(){this.primaryScreen="";this.activePrimary="";},closePopups:function(){this.activePopup="";}};
    }
    function test_unplug_primary_preserves_peer() { const s=state(); Screens.reconcile(s,["B"]); compare(s.activePrimary,"control"); compare(s.primaryScreen,"B"); compare(s.activePopup,"volume:B"); }
    function test_unplug_peer_clears_owned_surfaces() { const s=state(); Screens.reconcile(s,["A"]); compare(s.activePrimary,"control"); compare(s.activePopup,""); }
    function test_reconnect_does_not_reopen() { const s=state(); Screens.reconcile(s,[]); Screens.reconcile(s,["A","B"]); compare(s.activePrimary,""); compare(s.activePopup,""); }
    function test_full_settings_moves_to_survivor() {const s=state();s.controlMode="full";s.controlDraftDirty=true;Screens.reconcile(s,["B"]);compare(s.activePrimary,"control");compare(s.primaryScreen,"B");verify(s.controlDraftDirty);}
    function test_maximise_keeps_rail_but_true_fullscreen_yields_it() {
        verify(!Screens.trueFullscreen({hasFullscreen:true,toplevels:{values:[{lastIpcObject:{fullscreen:1}}]}}));
        verify(Screens.trueFullscreen({hasFullscreen:true,toplevels:{values:[{lastIpcObject:{fullscreen:2}}]}}));
        verify(Screens.trueFullscreen({hasFullscreen:true,toplevels:{values:[{lastIpcObject:{fullscreen:3}}]}}));
        verify(!Screens.trueFullscreen({hasFullscreen:false,toplevels:{values:[]}}));
        verify(!Screens.trueFullscreen({hasFullscreen:true,toplevels:{values:[]}}));
    }
    function test_malformed_popup_clears() { const s=state(); s.activePopup="volume"; Screens.reconcile(s,["A","B"]); compare(s.activePopup,""); }
    function test_monitor_owns_only_its_active_fullscreen_window() {
        const a={id:0,activeWorkspace:{id:1},lastIpcObject:{specialWorkspace:{id:0}}};
        const b={id:1,activeWorkspace:{id:3},lastIpcObject:{specialWorkspace:{id:0}}};
        const windows=[{monitor:0,workspace:{id:1},fullscreen:1},{monitor:1,workspace:{id:3},fullscreen:2}];
        verify(!Screens.monitorFullscreen(a,windows));verify(Screens.monitorFullscreen(b,windows));
        windows[0].fullscreen=2;verify(Screens.monitorFullscreen(a,windows));
        windows[1].fullscreen=0;verify(!Screens.monitorFullscreen(b,windows));
    }
    function test_current_inventory_overrides_stale_native_fullscreen_cache() {
        const monitor={id:5,activeWorkspace:{id:8,hasFullscreen:true,toplevels:{values:[{lastIpcObject:{fullscreen:2}}]}}};
        verify(!Screens.monitorFullscreen(monitor,[{monitor:5,workspace:{id:8},fullscreen:1}]));
        monitor.activeWorkspace.toplevels.values[0].lastIpcObject.fullscreen=0;
        verify(Screens.monitorFullscreen(monitor,[{monitor:5,workspace:{id:8},fullscreen:2}]));
        verify(!Screens.monitorFullscreen(monitor,[]));verify(!Screens.monitorFullscreen(null,[]));
    }
    function test_hidden_workspace_peer_output_client_only_and_special() {
        const monitor={id:0,activeWorkspace:{id:1},lastIpcObject:{specialWorkspace:{id:-99}}};
        verify(!Screens.monitorFullscreen(monitor,[{monitor:0,workspace:{id:2},fullscreen:2}]));
        verify(!Screens.monitorFullscreen(monitor,[{monitor:1,workspace:{id:1},fullscreen:2}]));
        verify(!Screens.monitorFullscreen(monitor,[{monitor:0,workspace:{id:1},fullscreen:0,fullscreenClient:2}]));
        verify(Screens.monitorFullscreen(monitor,[{monitor:0,workspace:{id:-99},fullscreen:2}]));
        verify(!Screens.monitorFullscreen(monitor,[{monitor:0,workspace:{id:-99},fullscreen:true}]));
    }
}
