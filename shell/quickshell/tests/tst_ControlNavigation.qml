import QtQuick
import QtTest
import "../services"
import "../services/ScreenLifecycle.js" as Screens
import "../components/ControlDirectory.js" as Directory

TestCase {
    name: "ControlNavigationState"
    ShellState {
        id: state
    }
    function init() {
        state.deferredPrimary = null;
        state.pageModalActive = false;
        state.availableScreens = null;
        state.confirmationSources = [];
        state.externalModalActive = false;
        state.closePopups();
        state.controlHistory = [];
        state.controlHistoryIndex = -1;
        state.controlDraftDirty = false;
        state.deferredPrimary = null;
        state.closePrimary();
        state.controlSection = "overview";
        state.controlPath = "";
    }
    function test_section_and_subroute() {
        state.showPrimary("control", "screen", "audio");
        state.controlPath = "audio/mixer/recording";
        state.showPrimary("control", "screen", "audio");
        compare(state.controlPath, "");
        state.showPrimary("control", "screen", "audio/devices");
        compare(state.controlSection, "audio");
        compare(state.controlPath, "audio/devices");
        state.controlSection = "network";
        compare(state.controlPath, "");
        compare(state.activePrimary, "control");
    }
    function test_dirty_guard() {
        state.showPrimary("control", "screen", "appearance");
        state.controlDraftDirty = true;
        verify(!state.showPrimary("performance", "screen", "cpu"));
        compare(state.activePrimary, "control");
        compare(state.deferredPrimary.kind, "performance");
        verify(!state.closePrimary());
        compare(state.deferredPrimary.kind,"performance");
        state.deferredPrimary=null;
        verify(!state.closePrimary());
        verify(state.deferredPrimary.closing);
        verify(state.completeDeferredPrimary());
        compare(state.activePrimary, "");
    }
    function test_calendar_draft_guard() {
        state.showPrimary("control", "screen", "calendar/month");
        state.controlDraftDirty = true;
        verify(!state.showPrimary("control", "screen", "calendar/accounts"));
        compare(state.controlPath, "calendar/month");
        compare(state.deferredPrimary.section, "calendar/accounts");
        verify(!state.showPrimary("insights", "screen", "briefing"));
        compare(state.activePrimary, "control");
        verify(state.completeDeferredPrimary());
        compare(state.controlPath,"calendar/accounts");
        compare(state.activePrimary,"control");
    }
    function test_clean_switch_exclusive() {
        state.showPrimary("control", "screen", "settings");
        state.showPrimary("insights", "screen", "briefing");
        compare(state.activePrimary, "insights");
        compare(state.primaryScreen, "screen");
    }
    function test_search_synonyms_and_ranking() {
        const nodes = Directory.build({});
        const mic = Directory.rows(nodes, {}, "mic");
        verify(mic.some(n => n.id === "audio/overview/microphone"));
        const wallpaper = Directory.rows(nodes, {}, "wallpaper");
        verify(wallpaper.some(n => n.id === "appearance/backgrounds"));
        const lock = Directory.rows(nodes, {}, "lock");
        compare(lock[0].id, "settings/idle/lock");
        compare(Directory.rows(nodes, {}, "nevermatches").length, 0);
        compare(Directory.rows(nodes, {}, "AUDIO")[0].id, "audio");
    }
    function test_task_search_destinations() {
        const nodes=Directory.build({});
        const cases=[['my microphone is too quiet','audio/overview/microphone'],['how do I change my login picture','accounts'],['stop sleeping when docked','settings/idle'],['change default browser','apps/defaults'],['reduce animations','appearance/motion']];
        for(const item of cases)compare(Directory.rows(nodes,{},item[0])[0].id,item[1]);
        compare(Directory.rows(nodes,{},'$(touch /tmp/not-a-command)').length,0);
    }
    function test_dynamic_identity_and_removal() {
        const nodes = Directory.build({
            outputs: [
                {
                    name: "out:safe/$()",
                    description: "Headphones"
                }
            ]
        });
        const match = Directory.rows(nodes, {}, "headphones")[0];
        compare(match.deviceKey, "out:safe/$()");
        compare(match.route, "audio");
        verify(Directory.resolve(nodes, match.id));
        compare(Directory.resolve(Directory.build({}), match.id), null);
        compare(Directory.rows(nodes, {}, "speaker")[0].id, match.id);
    }
    function test_settings_modes_share_primary() {
        verify(state.showSettings("screen","network/wifi"));
        compare(state.controlMode,"full");compare(state.activePrimary,"control");
        compare(state.controlPath,"network/wifi");
        verify(state.showPrimary("control","screen","audio"));
        compare(state.controlMode,"compact");compare(state.activePrimary,"control");
        compare(state.controlSection,"audio");
    }
    function test_popups_preserve_primary_and_replace_each_other() {
        verify(state.showSettings("screen","audio"));
        verify(state.togglePopup("network","screen"));
        compare(state.activePrimary,"control");compare(state.activePopup,"network:screen");
        verify(state.togglePopup("battery","other"));compare(state.activePopup,"battery:other");
        verify(state.showSettings("other","power"));compare(state.activePopup,"");
    }
    function test_dirty_settings_survives_popup_and_blocks_mode_change() {
        verify(state.showSettings("screen","appearance"));state.controlDraftDirty=true;
        verify(state.togglePopup("network","screen"));
        compare(state.controlMode,"full");compare(state.activePopup,"network:screen");verify(state.controlDraftDirty);
        verify(!state.showSettings("screen","audio"));compare(state.activePopup,"");compare(state.controlSection,"appearance");
        verify(state.completeDeferredPrimary());compare(state.controlSection,"audio");
        state.controlDraftDirty=true;
        verify(!state.showPrimary("control","screen","overview"));compare(state.controlMode,"full");
        verify(state.completeDeferredPrimary());compare(state.controlMode,"compact");
    }
    function test_all_popup_pairs_and_stale_dismissals() {
        for (const from of state.popupSurfaces) for (const to of state.popupSurfaces) {
            state.closePopups();verify(state.togglePopup(from,"left"));
            const lease=state.popupGeneration;
            verify(state.togglePopup(to,"right"));compare(state.activePopup,to+":right");
            verify(!state.closePopups(from+":left",lease));compare(state.activePopup,to+":right");
            verify(state.togglePopup(to,"right"));compare(state.activePopup,"");
        }
    }
    function test_reopen_same_token_ignores_old_lease() {
        state.togglePopup("network","left");const lease=state.popupGeneration;
        state.togglePopup("network","left");state.togglePopup("network","left");
        verify(!state.closePopups("network:left",lease));compare(state.activePopup,"network:left");
    }
    function test_modal_preserves_owner_and_escape_requests_cancel() {
        state.togglePopup("power","left");state.externalModalActive=true;
        verify(!state.togglePopup("network","right"));verify(!state.showSettings("right","accounts"));
        verify(!state.closePopups());compare(state.activePopup,"power:left");compare(state.escapeOverlay(),"modal");
        state.externalModalActive=false;verify(state.closePopups());
    }
    function test_history_preserves_forward_until_new_navigation() {
        state.showSettings("left","network");state.navigateControl("audio");state.navigateControl("power");
        verify(state.travelControl(-1));compare(state.controlSection,"audio");
        verify(state.travelControl(-1));compare(state.controlSection,"network");
        verify(state.travelControl(1));compare(state.controlSection,"audio");
        state.navigateControl("accounts");verify(!state.canGoForward);
    }
    function test_escape_dismisses_only_topmost() {
        state.showSettings("left","network");state.togglePopup("volume","left");
        compare(state.dismissTransient(),"popup");compare(state.activePrimary,"control");
    }
    function test_capture_pause_preserves_dirty_workspace_and_has_token_ownership() {
        verify(state.showSettings("screen","appearance"));state.controlDraftDirty=true;
        verify(state.pauseCapture("a".repeat(32)));compare(state.activePrimary,"control");verify(state.controlDraftDirty);
        verify(!state.resumeCapture("b".repeat(32)));verify(state.capturePaused);
        verify(state.resumeCapture("a".repeat(32)));verify(!state.capturePaused);verify(state.controlDraftDirty);
    }
    function test_invalid_deep_link_rejected_without_state_change() {
        verify(state.showSettings("screen","audio"));verify(!state.showSettings("screen","network/not-a-route"));compare(state.controlSection,"audio");
    }
    function test_hotplug_dismisses_transient_even_when_modal_and_relocates_dirty_settings() {
        state.showSettings("removed","appearance");state.controlDraftDirty=true;
        state.togglePopup("network","removed");state.externalModalActive=true;
        Screens.reconcile(state,["survivor"]);
        compare(state.activePopup,"");compare(state.primaryScreen,"survivor");
        compare(state.activePrimary,"control");verify(state.controlDraftDirty);
    }
    function test_dirty_history_review_keeps_existing_history() {
        state.showSettings("left","audio");state.navigateControl("appearance");state.controlDraftDirty=true;
        const history=state.controlHistory.join("|");verify(!state.travelControl(-1));
        verify(state.completeDeferredPrimary());compare(state.controlSection,"audio");
        compare(state.controlHistory.join("|"),history);verify(state.canGoForward);
    }
    function test_unknown_output_rejected_without_ghost_state() {
        state.availableScreens=["left"];
        verify(!state.togglePopup("network","missing"));compare(state.activePopup,"");
        verify(!state.showSettings("missing","network"));compare(state.activePrimary,"");
        verify(state.showSettings("left","network"));
    }
    function test_external_escape_defers_to_local_nested_menu_and_never_closes_persistent_primary() {
        state.showSettings("left","audio");state.togglePopup("tray","left");
        compare(state.dismissExternal(true),"owned");compare(state.activePopup,"tray:left");
        // Local Escape may cancel a submenu while the popup stays open.
        compare(state.dismissExternal(true),"owned");compare(state.activePopup,"tray:left");
        state.closePopups();compare(state.dismissExternal(false),"none");compare(state.activePrimary,"control");
        state.togglePopup("network","left");compare(state.dismissExternal(false),"popup");compare(state.activePrimary,"control");
        state.externalModalActive=true;compare(state.dismissExternal(false),"modal");compare(state.activePrimary,"control");
    }
    function test_expansion_context() {
        const nodes = Directory.build({});
        compare(Directory.rows(nodes, {}, "").length, 11);
        const parents = Directory.parentIds(nodes, "audio/mixer/recording");
        compare(parents.join('/'), "audio/audio/mixer");
        verify(Directory.rows(nodes, {
            audio: true,
            'audio/mixer': true
        }, "").some(n => n.id === "audio/mixer/recording"));
    }
}
