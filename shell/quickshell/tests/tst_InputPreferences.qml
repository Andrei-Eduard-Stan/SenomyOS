import QtQuick
import QtTest
import "../services"

TestCase {
    id:test
    name:"InputPreferences"
    property int calls:0
    property string verb:""
    property var payload:({})
    InputPreferences {
        id:model
        onDispatch:(operation,text,serial)=>{test.calls++;test.verb=operation;test.payload=JSON.parse(text);}
    }
    function values() { return {sensitivity:0,naturalScroll:false,tapToClick:true,layout:"gb",variant:"",usFallback:true,repeatRate:25,repeatDelay:600,mouseNaturalScroll:false,mouseScrollFactor:1,touchpadScrollFactor:1,disableWhileTyping:true,leftHanded:false}; }
    function receipt(state,ok,extra) {
        let data={schemaVersion:2,ok:ok,state:state,message:state === "rejected" ? "Hyprland rejected the change. No preference was saved." : "Fixture "+state,
            available:true,effective:values(),capabilities:{},devices:[{name:"fixture-keyboard"}],fingerprint:"current",firstRun:false,layouts:["gb","us"],variants:{gb:["","intl"],us:[""]},saved:{},persistence:"not-saved",pending:{state:"none",token:""},requestId:String(model.serial)};
        Object.keys(data.effective).forEach(k=>data.capabilities[k]=true);
        return Object.assign(data,extra || {});
    }
    function reply(state,ok,extra,code) { return model.consume(JSON.stringify(receipt(state,ok,extra)),code === undefined ? (ok ? 0 : 1) : code,model.serial); }
    function init() {
        model.active=false;model.busy=false;model.pending={state:"none",token:""};model.dirty=false;model.revertAfterApply=false;model.state="unavailable";
        model.active=true;
        if (!model.busy) model.refresh();
        reply("observed",true);
        calls=0;verb="";payload={};
    }
    function test_initial_values_from_effective_not_saved() {
        compare(model.layout,"gb");compare(model.repeatRate,25);compare(model.draft.sensitivity,0);verify(model.available);
    }
    function test_draft_edits_do_not_submit_and_are_coalesced() {
        for(let n=1;n<=8;n++) verify(model.edit("sensitivity",n/10));
        compare(calls,0);compare(model.sensitivity,0);verify(model.dirty);
        verify(model.applyDraft("pointer"));compare(calls,1);compare(payload.changes.sensitivity,0.8);
        verify(!model.applyDraft("pointer"));verify(!model.edit("tapToClick",false));
    }
    function test_rejection_uses_actual_values_and_no_saved_success() {
        model.edit("sensitivity",0.5);model.applyDraft("pointer");
        reply("rejected",false);compare(model.state,"rejected");compare(model.sensitivity,0);compare(model.draft.sensitivity,0);
        verify(model.message.indexOf("rejected")>=0);verify(model.message.indexOf("saved and active")<0);compare(Object.keys(model.saved).length,0);verify(!model.dirty);
    }
    function test_preview_is_pending_not_saved_success() {
        model.edit("sensitivity",0.5);model.applyDraft("pointer");let next=values();next.sensitivity=0.5;
        reply("preview",true,{effective:next,pending:{state:"preview",token:"abc",requested:{sensitivity:0.5}},persisted:false});
        compare(model.pendingToken,"abc");verify(model.locked);verify(!model.applyDraft("pointer"));compare(model.persistence,"not-saved");
    }
    function test_confirm_requires_matching_pending_and_persisted_receipt() {
        model.pending={state:"preview",token:"abc"};verify(model.confirm());compare(verb,"confirm");compare(payload.token,"abc");
        verify(reply("applied-verified",true,{persisted:true,persistence:"saved",saved:{sensitivity:0}}));compare(model.state,"applied-verified");
    }
    function test_success_without_persistence_is_invalid() {
        model.refresh();verify(!reply("applied-verified",true,{persisted:false}));verify(!model.available);compare(model.state,"transport-failed");
    }
    function test_persistence_failure_is_not_success() {
        model.edit("sensitivity",0.5);model.applyDraft("pointer");reply("applied-persistence-failed",false);
        compare(model.state,"applied-persistence-failed");compare(model.persistence,"not-saved");
    }
    function test_stale_response_cannot_overwrite_new_request() {
        model.refresh();let old=model.serial-1;let oldResult=receipt("observed",true);oldResult.requestId=String(old);oldResult.effective.sensitivity=0.9;
        verify(!model.consume(JSON.stringify(oldResult),0,old));verify(model.busy);compare(model.sensitivity,0);reply("observed",true);
    }
    function test_external_change_preserves_and_invalidates_dirty_draft() {
        model.edit("sensitivity",0.5);model.refresh();let next=values();next.sensitivity=0.2;
        reply("observed",true,{effective:next,fingerprint:"changed"});verify(model.staleDraft);compare(model.draft.sensitivity,0.5);compare(model.sensitivity,0.2);
        verify(!model.applyDraft("pointer"));model.resetDraft();verify(!model.staleDraft);compare(model.draft.sensitivity,0.2);
    }
    function test_device_removal_during_preview_requests_revert() {
        model.pending={state:"preview",token:"abc"};model.refresh();calls=0;
        reply("observed",true,{pending:{state:"preview",token:"abc",deviceChanged:true}});compare(verb,"revert");compare(calls,1);
    }
    function test_page_close_reverts_pending_preview() {
        model.pending={state:"preview",token:"abc"};model.active=false;compare(verb,"revert");compare(calls,1);
    }
    function test_page_close_during_apply_reverts_after_receipt() {
        model.edit("sensitivity",0.5);model.applyDraft("pointer");model.active=false;
        reply("preview",true,{pending:{state:"preview",token:"abc"}});compare(verb,"revert");
    }
    function test_close_while_reading_does_not_cancel_future_preview() {
        model.refresh();model.active=false;reply("observed",true);verify(!model.revertAfterApply);
        model.active=true;reply("observed",true);model.edit("sensitivity",0.5);model.applyDraft("pointer");
        reply("preview",true,{pending:{state:"preview",token:"abc"}});compare(verb,"apply");
    }
    function test_open_close_open_has_one_request_no_duplicate_handlers() {
        model.active=false;model.active=true;compare(calls,1);reply("observed",true);
        model.active=false;model.active=true;compare(calls,2);
    }
    function test_start_failure_timeout_malformed_and_exit_mismatch() {
        model.refresh();model.transportFailed(model.serial,"Interpreter unavailable");verify(!model.busy);verify(!model.available);
        model.refresh();verify(!model.consume("bad",0,model.serial));verify(!model.busy);
        model.refresh();verify(!reply("observed",true,{},1));verify(!model.available);
    }
    function test_lost_preview_observation_becomes_unknown_without_inactive_polling() {
        model.pending={state:"preview",token:"abc"};model.refresh();
        reply("unavailable",false,{available:false,effective:{},capabilities:{}});
        compare(model.pendingToken,"");compare(model.pending.state,"unknown");compare(model.state,"unavailable");verify(!model.available);
        calls=0;model.active=false;compare(calls,0);model.active=true;compare(calls,1);
        reply("observed",true,{pending:{state:"rolled-back",token:"abc"}});verify(model.available);
        model.pending={state:"preview",token:"again"};model.refresh();model.transportFailed(model.serial,"Lost transport");
        compare(model.pendingToken,"");compare(model.pending.state,"unknown");verify(!model.available);
    }
    function test_unsupported_device_control_is_disabled() {
        model.capabilities={sensitivity:true};verify(!model.edit("tapToClick",false));verify(model.edit("sensitivity",0.2));
    }
    function test_layout_draft_resets_variant_and_sends_complete_group() {
        model.edit("variant","intl");model.edit("layout","us");compare(model.draft.variant,"");compare(model.draft.usFallback,false);
        model.applyDraft("keyboard");compare(payload.changes.layout,"us");compare(payload.changes.variant,"");compare(payload.changes.usFallback,false);
    }
    function test_automatic_expiry_reports_restored_not_saved() {
        model.pending={state:"preview",token:"abc"};model.refresh();reply("observed",true,{pending:{state:"rolled-back",token:"abc"}});
        compare(model.state,"rolled-back");verify(!model.locked);verify(model.message.indexOf("Nothing was saved")>=0);
    }
}
