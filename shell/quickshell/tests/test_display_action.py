"""Behavioural regression tests. No real compositor commands or user files."""
from copy import deepcopy
import importlib.util
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

path=Path(__file__).parents[1]/'scripts/display_core.py'
spec=importlib.util.spec_from_file_location('display_core_test',path)
core=importlib.util.module_from_spec(spec);spec.loader.exec_module(core)

class Displays(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.addCleanup(patch.stopall)
        patch.dict(os.environ,{'XDG_CONFIG_HOME':self.tmp.name+'/config','XDG_STATE_HOME':self.tmp.name+'/state','XDG_RUNTIME_DIR':self.tmp.name+'/run','HYPRLAND_INSTANCE_SIGNATURE':'audit-instance'}).start()
        self.raw=[dict(id=i,name=n,make='Fixture',model=n,serial=n,physicalWidth=500,physicalHeight=300,width=1920,height=1080,refreshRate=60,x=i*1920,y=0,scale=1,transform=0,disabled=False,dpmsStatus=True,mirrorOf='none',availableModes=['1920x1080@60.00Hz','1280x720@60.00Hz'],activeWorkspace={'id':i+1}) for i,n in enumerate(['AUDIT-A','AUDIT-B','AUDIT-C'])]
        self.ws=[dict(id=i+1,name=str(i+1),monitor=m['name'],windows=0,ispersistent=False) for i,m in enumerate(self.raw)]
        self.clients=[];self.calls=[];self.rules={}
        patch.object(core.subprocess,'run',side_effect=AssertionError('Real subprocess forbidden in model test')).start()
        patch.object(core,'query',side_effect=self.query).start()
        patch.object(core,'apply_output',side_effect=self.apply_output).start()
        patch.object(core,'dispatch',side_effect=self.dispatch).start()
        patch.object(core,'evaluate',side_effect=self.evaluate).start()
        patch.object(core,'arm_watchdog',side_effect=lambda token:self.calls.append(('armed',token))).start()
    def query(self,*args):
        if args[0]=='status':return {'configProvider':'lua'}
        if args[0]=='monitors':return deepcopy(self.raw)
        if args[0]=='workspaces':return deepcopy(self.ws)
        if args[0]=='clients':return deepcopy(self.clients)
        if args[0]=='workspacerules':return list(self.rules.values())
        raise AssertionError(args)
    def evaluate(self,code):
        self.calls.append(('lua',code))
        m=re.search(r'workspace="(\d+)".*monitor="([^"]+)".*persistent=(true|false)',code)
        if m:self.rules[m[1]]=dict(workspaceString=m[1],monitor=m[2],persistent=m[3]=='true',enabled=True)
    def apply_output(self,out):
        self.calls.append(('output',deepcopy(out)))
        item=next(m for m in self.raw if m['name']==out['name'])
        if out['enabled']:
            w,h,hz=core.mode_parts(out['mode']);item.update(width=w,height=h,refreshRate=hz,scale=out['scale'],transform=out['transform'],x=out['x'],y=out['y'],disabled=False,mirrorOf=out.get('mirrorOf') or 'none',dpmsStatus=True)
        else:item['disabled']=True
    def dispatch(self,kind,values):
        self.calls.append((kind,deepcopy(values)))
        if kind=='workspace.move':
            next(w for w in self.ws if w['id']==values['workspace'])['monitor']=values['monitor']
        elif kind=='focus' and 'workspace' in values:
            wid=values['workspace'];ws=next((w for w in self.ws if w['id']==wid),None)
            if ws is None:
                target=next(m for m in self.raw if m.get('focused'))
                ws=dict(id=wid,name=str(wid),monitor=target['name'],windows=0);self.ws.append(ws)
            next(m for m in self.raw if m['name']==ws['monitor'])['activeWorkspace']={'id':wid}
        elif kind=='focus' and 'monitor' in values:
            for m in self.raw:m['focused']=m['name']==values['monitor']
        elif kind=='window.move':
            address=values['window'].removeprefix('address:');next(c for c in self.clients if c['address']==address)['workspace']={'id':values['workspace']}
        elif kind=='workspace.rename':next(w for w in self.ws if w['id']==values['workspace'])['name']=values['name']
    def request(self):
        snap=core.snapshot();return dict(baseDigest=snap['digest'],outputs=[core.configuration(m) for m in snap['displays']],primary='')
    def recovery_fixture(self):
        self.raw[2].update(width=1920,height=1080,refreshRate=60)
        core.save_current();core.recovery_config({'enabled':True})
        self.raw[2].update(width=640,height=480,refreshRate=75)
        self.calls=[]
    def settle_recovery(self):
        result=core.auto_recover();self.assertEqual(result['state'],'recovery-observing')
        p=core.runtime_dir()/'display-auto-recovery.json';log=core.read_json(p)
        log['firstSeen']=core.boottime()-3;core.atomic_json(p,log)
    def test_fallback_health_recognizes_saved_setup_and_exposes_diagnostics(self):
        self.recovery_fixture();health=core.snapshot()['recovery']
        self.assertTrue(health['needed']);self.assertTrue(health['canAttempt']);self.assertEqual(health['outputs'],['AUDIT-C'])
        self.assertFalse(self.calls)
    def test_auto_recovery_requires_opt_in_and_never_creates_a_saved_layout(self):
        self.raw[2].update(width=640,height=480)
        self.assertEqual(core.auto_recover()['state'],'disabled');self.assertFalse(self.calls)
        core.recovery_config({'enabled':True})
        self.assertEqual(core.auto_recover()['state'],'setup-unmatched');self.assertNotIn('lastKnownGood',core.store())
    def test_automatic_recovery_waits_for_stable_fallback_then_restores_confirmed_layout(self):
        self.recovery_fixture();saved=deepcopy(core.store()['lastKnownGood'])
        self.settle_recovery();self.assertFalse(self.calls)
        self.assertEqual(core.auto_recover()['state'],'auto-recovered')
        self.assertEqual((self.raw[2]['width'],self.raw[2]['height']),(1920,1080))
        self.assertEqual(core.store()['lastKnownGood'],saved)
        self.assertEqual(core.public_state()['state'],'committed')
        self.assertEqual(self.calls[0][0],'armed')
    def test_changed_fallback_restarts_stability_observation(self):
        self.recovery_fixture();self.settle_recovery();self.raw[2]['x']+=20
        self.assertEqual(core.auto_recover()['state'],'recovery-observing');self.assertFalse(self.calls)
    def test_late_docking_recovers_after_startup_setup_was_absent(self):
        self.recovery_fixture();removed=self.raw.pop()
        self.assertEqual(core.auto_recover()['state'],'setup-unmatched');self.assertFalse(self.calls)
        self.raw.append(removed);self.settle_recovery()
        self.assertEqual(core.auto_recover()['state'],'auto-recovered')
    def test_other_monitor_identity_does_not_trigger_automatic_layout(self):
        self.recovery_fixture();self.raw[2]['serial']='another-device'
        self.assertEqual(core.auto_recover()['state'],'setup-unmatched');self.assertFalse(self.calls)
    def test_projection_disable_mirror_and_sleep_are_not_counteracted(self):
        for patch_value in ({'disabled':True},{'mirrorOf':'AUDIT-A'},{'dpmsStatus':False}):
            with self.subTest(patch_value=patch_value):
                self.recovery_fixture();self.raw[1].update(patch_value)
                self.assertEqual(core.auto_recover()['state'],'projection-changed');self.assertFalse(self.calls)
                self.raw[1].update(disabled=False,mirrorOf='none',dpmsStatus=True)
    def test_deliberately_confirmed_low_mode_is_not_automatically_replaced(self):
        self.recovery_fixture();self.raw[2]['availableModes'].append('640x480@75.00Hz')
        core.save_current();self.calls=[]
        self.assertEqual(core.auto_recover()['state'],'healthy');self.assertFalse(self.calls)
    def test_user_preview_suspends_automatic_recovery(self):
        core.save_current();core.recovery_config({'enabled':True});core.begin(self.request())
        self.raw[2].update(width=640,height=480,refreshRate=75);self.calls=[]
        self.assertEqual(core.auto_recover()['state'],'preview-active');self.assertFalse(self.calls)
    def test_failed_recovery_arming_records_failure_without_mode_writes_and_backs_off(self):
        self.recovery_fixture();self.settle_recovery()
        with patch.object(core,'arm_watchdog',side_effect=ValueError('Fixture recovery unavailable')):
            result=core.auto_recover()
        self.assertFalse(result['ok']);self.assertFalse(any(c[0]=='output' for c in self.calls))
        self.calls=[];self.assertEqual(core.auto_recover()['state'],'cooldown');self.assertFalse(self.calls)
    def test_repeated_fallback_after_success_has_a_cooldown(self):
        self.recovery_fixture();self.settle_recovery();core.auto_recover()
        self.raw[2].update(width=640,height=480,refreshRate=75);self.calls=[]
        self.assertEqual(core.auto_recover()['state'],'cooldown');self.assertFalse(self.calls)
    def test_auto_recovery_limits_three_attempts_in_ten_minutes(self):
        self.recovery_fixture();self.settle_recovery()
        path=core.runtime_dir()/'display-auto-recovery.json';log=core.read_json(path);now=core.boottime()
        log.update(attempts=[now-61,now-122,now-183],lastAttempt=now-61);core.atomic_json(path,log)
        result=core.auto_recover();self.assertEqual(result['state'],'cooldown');self.assertFalse(self.calls)
    def test_coordinated_retry_failure_never_saves_requested_mode(self):
        core.save_current();core.recovery_config({'enabled':True});saved=deepcopy(core.store()['lastKnownGood'])
        req=self.request();req['outputs'][2]['mode']='1280x720@60.00Hz';count=[];original=core.verify
        def rejected(outputs,timeout=3):
            if any(o['mode'].startswith('1280') for o in outputs):raise ValueError('Fixture hardware rejected mode')
            return original(outputs,timeout)
        with patch.object(core,'verify',side_effect=rejected),patch.object(core,'pin_layout',side_effect=lambda outputs:count.append(outputs)):
            with self.assertRaisesRegex(ValueError,'previous layout restored'):core.begin(req)
        self.assertEqual(len(count),2);self.assertEqual(core.store()['lastKnownGood'],saved)
        self.assertEqual(self.raw[2]['width'],1920)

    def test_automatic_recovery_refuses_missing_compositor_instance(self):
        with patch.dict(os.environ,{'HYPRLAND_INSTANCE_SIGNATURE':''}):
            with self.assertRaisesRegex(ValueError,'explicit compositor'):core.auto_recover()
        self.assertFalse(self.calls)
    def test_changing_recovery_policy_has_no_display_side_effect(self):
        core.recovery_config({'enabled':True});self.assertTrue(core.store()['autoRecovery']);self.assertFalse(self.calls)
        core.recovery_config({'enabled':False});self.assertFalse(core.store()['autoRecovery']);self.assertFalse(self.calls)
        with self.assertRaises(ValueError):core.recovery_config({'enabled':'yes'})
    def test_bad_starting_fallback_uses_confirmed_geometry_for_rollback(self):
        self.recovery_fixture();req=self.request();req['outputs'][2].update(mode='1920x1080@60.00Hz',y=1080)
        original=self.apply_output
        def reject(out):
            if out['name']=='AUDIT-C' and out['y']==1080:raise ValueError('Rejected fixture mode')
            original(out)
        with patch.object(core,'apply_output',side_effect=reject),patch.object(core,'pin_layout',side_effect=lambda outputs:None):
            with self.assertRaisesRegex(ValueError,'confirmed working layout restored'):core.begin(req)
        self.assertEqual((self.raw[2]['width'],self.raw[2]['height'],self.raw[2]['y']),(1920,1080,0))
        state=core.read_json(core.state_path());self.assertEqual(state['observedBefore'][2]['mode'],'640x480@75.00000');self.assertTrue(state['safeRecovery'])
    def test_valid_mode_retries_once_as_complete_topology_after_rejected_sequential_write(self):
        core.recovery_config({'enabled':True});req=self.request();req['outputs'][2]['mode']='1280x720@60.00Hz'
        original=self.apply_output;calls=[]
        def individual(out):
            if out['mode'].startswith('1280'):raise ValueError('Transient fixture allocation')
            original(out)
        def batch(outputs):
            calls.append(deepcopy(outputs))
            for out in outputs:original(out)
        with patch.object(core,'apply_output',side_effect=individual),patch.object(core,'pin_layout',side_effect=batch):
            result=core.begin(req)
        self.assertEqual(result['state'],'preview');self.assertEqual(len(calls),2)
        self.assertTrue(core.read_json(core.state_path())['coordinatedRetry']);self.assertEqual(self.raw[2]['width'],1280)
    def test_unsupported_mode_is_rejected_before_arming_even_when_recovery_enabled(self):
        core.recovery_config({'enabled':True});req=self.request();req['outputs'][2]['mode']='9999x9999@60'
        self.calls=[]
        with self.assertRaisesRegex(ValueError,'not reported'):core.begin(req)
        self.assertFalse(self.calls)
    def test_whole_topology_retry_is_not_used_for_output_retirement(self):
        core.recovery_config({'enabled':True});req=self.request();req['outputs'][2]['enabled']=False
        original=core.verify;count=[]
        def readback(outputs,timeout=3):
            if len(outputs)==3 and any(not o['enabled'] for o in outputs):raise ValueError('Fixture rejected retirement')
            return original(outputs,timeout)
        with patch.object(core,'verify',side_effect=readback),patch.object(core,'pin_layout',side_effect=lambda outputs:count.append(outputs)):
            with self.assertRaises(ValueError):core.begin(req)
        self.assertEqual(len(count),1)

    def test_centred_three_monitor_layout_survives_keep_and_readback(self):
        req=self.request();req['outputs'][2].update(x=960,y=1080)
        r=core.begin(req);self.assertEqual(self.calls[0][0],'armed');core.confirm(r['token'])
        self.assertEqual((self.raw[2]['x'],self.raw[2]['y']),(960,1080))
        self.assertEqual(core.store()['lastKnownGood'][2]['y'],1080)
        self.assertEqual(core.public_state()['state'],'committed')
    def test_negative_positions_and_gaps_are_preserved(self):
        req=self.request();req['outputs'][0].update(x=-2300,y=-1200)
        r=core.begin(req);core.confirm(r['token']);self.assertEqual(self.raw[0]['x'],-2300)
    def test_overlap_refused_without_any_mutation(self):
        req=self.request();req['outputs'][1]['x']=100
        with self.assertRaisesRegex(ValueError,'overlap'):core.begin(req)
        self.assertEqual(self.calls,[])
    def test_stale_draft_refused(self):
        req=self.request();self.raw[0]['x']=-2000
        with self.assertRaisesRegex(ValueError,'changed outside'):core.begin(req)
        self.assertEqual(self.calls,[])
    def test_equal_snapshot_does_not_invalidate_request(self):
        req=self.request();core.snapshot();core.snapshot();core.begin(req)
    def test_arming_failure_makes_zero_output_writes(self):
        req=self.request()
        with patch.object(core,'arm_watchdog',side_effect=ValueError('fixture failed')):
            with self.assertRaises(ValueError):core.begin(req)
        self.assertEqual(self.calls,[]);self.assertEqual(core.public_state()['state'],'failed')
    def test_rejected_apply_rolls_back(self):
        req=self.request();req['outputs'][2]['y']=1080
        original=self.apply_output
        def fail_once(out):
            if out['y']==1080:raise ValueError('fixture rejected')
            original(out)
        with patch.object(core,'apply_output',side_effect=fail_once):
            with self.assertRaisesRegex(ValueError,'previous layout restored'):core.begin(req)
        self.assertEqual(core.public_state()['state'],'reverted')
        self.assertEqual(self.raw[2]['y'],0)
    def test_preview_expiry_reverts_instead_of_committing(self):
        req=self.request();req['outputs'][2]['y']=1080;r=core.begin(req)
        state=core.read_json(core.state_path());state['bootDeadline']=0;core.atomic_json(core.state_path(),state)
        with self.assertRaisesRegex(ValueError,'expired'):core.confirm(r['token'])
        self.assertEqual(self.raw[2]['y'],0)
    def test_keep_then_next_apply_and_idempotent_revert(self):
        r=core.begin(self.request());core.confirm(r['token']);r=core.begin(self.request())
        core.revert(r['token']);core.revert(r['token']);self.assertEqual(core.public_state()['state'],'reverted')
    def test_final_physical_output_cannot_be_disabled(self):
        req=self.request()
        for out in req['outputs']:out['enabled']=False
        with self.assertRaisesRegex(ValueError,'final independent'):core.begin(req)
    def test_retiring_sources_waits_for_verified_recovery_destination(self):
        self.raw[1]['disabled']=True
        req=self.request()
        for out in req['outputs']:out['enabled']=out['name']=='AUDIT-B'
        original=core.verify
        def fail_destination(outputs,timeout=3):
            if len(outputs)==1 and outputs[0]['name']=='AUDIT-B' and outputs[0]['enabled']:raise ValueError('fixture target not usable')
            return original(outputs,timeout)
        with patch.object(core,'verify',side_effect=fail_destination):
            with self.assertRaises(ValueError):core.begin(req)
        self.assertFalse(any(kind=='output' and value['name'] in ('AUDIT-A','AUDIT-C') and not value['enabled'] for kind,value in self.calls))
    def test_mirror_cycles_refused(self):
        req=self.request();req['outputs'][0]['mirrorOf']='AUDIT-B';req['outputs'][1]['mirrorOf']='AUDIT-A'
        with self.assertRaisesRegex(ValueError,'Mirror source'):core.begin(req)
    def test_only_display_moves_native_workspace_groups_before_disable(self):
        req=self.request()
        for out in req['outputs']:out['enabled']=out['name']=='AUDIT-A'
        core.begin(req)
        self.assertTrue(all(w['monitor']=='AUDIT-A' for w in self.ws))
    def test_rollback_restores_workspace_groups(self):
        req=self.request()
        for out in req['outputs']:out['enabled']=out['name']=='AUDIT-A'
        result=core.begin(req);core.revert(result['token'])
        self.assertEqual([w['monitor'] for w in self.ws],['AUDIT-A','AUDIT-B','AUDIT-C'])
    def test_profile_crud_and_identity_matching(self):
        core.profile_operation('profile-save',{'name':'Desk'})
        pid=next(iter(core.store()['profiles']))
        core.profile_operation('profile-rename',{'id':pid,'name':'Work'})
        self.assertEqual(core.store()['profiles'][pid]['name'],'Work')
        self.raw[1]['name']='AUDIT-NEW'
        self.ws[1]['monitor']='AUDIT-NEW'
        result=core.profile_operation('profile-apply',{'id':pid});core.revert(result['token'])
        core.profile_operation('profile-delete',{'id':pid});self.assertFalse(core.store()['profiles'])
    def test_profile_missing_output_refuses_mutation(self):
        core.profile_operation('profile-save',{'name':'Desk'});pid=next(iter(core.store()['profiles']));self.raw.pop()
        with self.assertRaisesRegex(ValueError,'disconnected'):core.profile_operation('profile-apply',{'id':pid})
        self.assertEqual(self.calls,[])
    def test_independent_labels_have_distinct_real_workspace_ids(self):
        self.ws[1]['windows']=1
        core.workspace_operation({'action':'mode','mode':'independent'})
        data=core.store();self.assertEqual(data['workspaceMode'],'independent')
        self.assertEqual(data['workspaces']['1']['slot'],1);self.assertEqual(data['workspaces']['2']['slot'],1)
        core.workspace_operation({'action':'switch','id':1})
        self.assertEqual(self.raw[1]['activeWorkspace']['id'],2)
    def test_workspace_move_preserves_id_and_windows(self):
        self.ws[0]['windows']=2
        core.workspace_operation({'action':'move','id':1,'monitor':'AUDIT-B'})
        self.assertEqual(self.ws[0]['id'],1);self.assertEqual(self.ws[0]['windows'],2);self.assertEqual(self.ws[0]['monitor'],'AUDIT-B')
    def test_populated_workspace_cannot_be_removed(self):
        self.ws[0]['windows']=1
        with self.assertRaisesRegex(ValueError,'windows'):core.workspace_operation({'action':'remove','id':1})
    def test_closed_window_is_never_moved(self):
        with self.assertRaisesRegex(ValueError,'Window closed'):core.workspace_operation({'action':'window-move','id':2,'address':'0x123','pid':1,'sourceWorkspace':1})
    def test_window_move_uses_native_identity_and_destination(self):
        self.clients=[dict(address='0x123',pid=1,workspace={'id':1})]
        core.workspace_operation({'action':'window-move','id':2,'address':'0x123','pid':1,'sourceWorkspace':1})
        self.assertEqual(self.clients[0]['workspace']['id'],2)
    def test_diagnostics_do_not_export_serial_or_titles(self):
        self.clients=[dict(address='0x123',pid=1,title='PRIVATE',workspace={'id':1})]
        s=json.dumps(core.snapshot());self.assertNotIn('PRIVATE',s);self.assertNotIn('serial',s)
    def test_lua_encoder_prevents_executable_interpolation(self):
        value='a";os.execute("bad")\n💙'
        encoded=core.lua(value);self.assertNotIn('"bad"',encoded);self.assertIn('\\034',encoded);self.assertIn('\\010',encoded)
    def test_native_mirror_source_id_zero_is_resolved_to_connector(self):
        self.raw[2]['mirrorOf']='0'
        snap=core.snapshot()
        self.assertEqual(snap['displays'][2]['mirrorOf'],'AUDIT-A')
        out=core.configuration(snap['displays'][2]);core.verify([out])
    def test_new_session_does_not_replay_stale_preview(self):
        result=core.begin(self.request())
        state=core.read_json(core.state_path());state['instance']='old-session';core.atomic_json(core.state_path(),state)
        self.calls=[]
        with self.assertRaisesRegex(ValueError,'session changed'):core.confirm(result['token'])
        self.assertEqual(self.calls,[])
        self.assertEqual(core.public_state()['state'],'abandoned')
    def test_invalid_modes_scales_rotation_and_positions_never_write(self):
        for patch_value in ({'mode':'9999x9999@60Hz'},{'scale':True},{'scale':0},{'scale':1.3},{'transform':8},{'x':0.5},{'x':100000}):
            req=self.request();req['outputs'][0].update(patch_value)
            with self.assertRaises(ValueError):core.begin(req)
        self.assertEqual(self.calls,[])
    def test_dynamic_workspace_creation_uses_unused_native_id(self):
        core.workspace_operation({'action':'create','monitor':'AUDIT-B'})
        ids=[w['id'] for w in self.ws];self.assertEqual(len(ids),len(set(ids)))
        self.assertEqual(self.ws[-1]['monitor'],'AUDIT-B');self.assertFalse(core.store()['workspaces'][str(self.ws[-1]['id'])]['persistent'])
    def test_profile_restores_saved_native_workspace_distribution(self):
        core.profile_operation('profile-save',{'name':'Desk'});pid=next(iter(core.store()['profiles']))
        self.ws[0]['monitor']='AUDIT-C'
        result=core.profile_operation('profile-apply',{'id':pid});core.confirm(result['token'])
        self.assertEqual(self.ws[0]['monitor'],'AUDIT-A')
    def test_keyboard_monitor_local_slots_do_not_alias_ids(self):
        core.workspace_operation({'action':'mode','mode':'independent'})
        for item in self.raw:item['focused']=item['name']=='AUDIT-A'
        core.shortcut(2,'switch');new_id=self.raw[0]['activeWorkspace']['id']
        self.assertNotEqual(new_id,2);self.assertEqual(self.raw[1]['activeWorkspace']['id'],2)
        self.assertEqual(core.store()['workspaces'][str(new_id)]['slot'],2)
    def test_hotplug_guest_keeps_home_and_manual_reconnect_restores_group(self):
        core.workspace_operation({'action':'mode','mode':'independent'});home=core.store()['workspaces']['2']['home']
        removed=self.raw.pop(1);self.ws[1]['monitor']='AUDIT-A'
        core.snapshot();self.assertEqual(core.store()['workspaces']['2']['home'],home)
        self.raw.append(removed)
        core.workspace_operation({'action':'restore-home'})
        self.assertEqual(self.ws[1]['monitor'],'AUDIT-B')
    def test_legacy_defaults_import_is_review_only_and_original_untouched(self):
        legacy=core.config_dir()/'displays.json';legacy.parent.mkdir(parents=True)
        text=json.dumps({'schemaVersion':1,'displays':{'AUDIT-A':{'mode':'1280x720@60.00Hz','scale':1,'transform':0,'x':0,'y':0}}});legacy.write_text(text)
        core.snapshot();self.assertTrue(core.store()['legacyDefaults'])
        core.profile_operation('profile-import-legacy',{})
        self.assertTrue(core.store()['profiles']);self.assertEqual(legacy.read_text(),text);self.assertEqual(self.calls,[])
    def test_watchdog_rechecks_updated_deadline_under_lock(self):
        result=core.begin(self.request());self.calls=[]
        status=core.revert(result['token'],expired_only=True)
        self.assertTrue(status['waiting']);self.assertEqual(self.calls,[])
    def test_commit_write_failure_keeps_journal_for_recovery(self):
        result=core.begin(self.request());original=core.atomic_json
        def write(path,data):
            if path==core.store_path():raise OSError('fixture disk full')
            original(path,data)
        with patch.object(core,'atomic_json',side_effect=write):
            with self.assertRaises(OSError):core.confirm(result['token'])
        self.assertEqual(core.public_state()['state'],'committing')
        self.assertIn('commitStoreBefore',core.read_json(core.state_path()))
        core.revert(result['token']);self.assertEqual(core.public_state()['state'],'reverted')
    def test_actual_mode_matched_with_advertised_precision(self):
        self.raw[0]['refreshRate']=59.997
        core.begin(self.request())
    def test_interrupted_recovery_can_be_retried(self):
        result=core.begin(self.request());state=core.read_json(core.state_path())
        state['state']='reverting';core.atomic_json(core.state_path(),state)
        core.revert(result['token']);self.assertEqual(core.public_state()['state'],'reverted')
    def test_early_rollback_failure_retains_retryable_state(self):
        req=self.request();req['outputs'][2]['y']=1080
        with patch.object(core,'apply_output',side_effect=ValueError('fixture apply failed')),patch.object(core,'rollback',side_effect=ValueError('fixture query failed')):
            with self.assertRaisesRegex(ValueError,'recovery:'):core.begin(req)
        self.assertEqual(core.public_state()['state'],'recovery-failed')
    def test_profiles_cannot_mutate_during_pending_recovery(self):
        result=core.begin(self.request())
        for operation in ('profile-save','profile-delete','profile-rename','profile-import-legacy'):
            with self.assertRaisesRegex(ValueError,'preview'):core.profile_operation(operation,{'name':'Desk','id':'none'})
        core.revert(result['token'])
    def test_policy_reload_reinstalls_owned_shortcuts_without_output_changes(self):
        core.workspace_operation({'action':'mode','mode':'independent'});self.calls=[]
        self.assertEqual(core.restore_policy()['state'],'policy-restored')
        self.assertTrue(any(k=='lua' and 'hl.bind(' in v for k,v in self.calls))
        self.assertFalse(any(k in ('output','workspace.move','focus') for k,v in self.calls))
    def test_policy_reload_defers_during_preview(self):
        core.begin(self.request());self.calls=[]
        self.assertEqual(core.restore_policy()['state'],'policy-deferred');self.assertEqual(self.calls,[])
    def test_old_session_journal_does_not_block_current_policy_or_profiles(self):
        core.begin(self.request());state=core.read_json(core.state_path());state['instance']='previous-session';core.atomic_json(core.state_path(),state)
        self.calls=[];self.assertEqual(core.restore_policy()['state'],'policy-restored')
        core.profile_operation('profile-save',{'name':'Current desk'})
        core.workspace_operation({'action':'mode','mode':'independent'})
        self.assertFalse(any(k=='output' for k,v in self.calls))
    def test_apply_pins_full_topology_then_changes_only_requested_output(self):
        req=self.request();req['outputs'][2]['y']=1080
        result=core.begin(req)
        self.assertEqual([v['name'] for k,v in self.calls if k=='output'],['AUDIT-C'])
        core.revert(result['token'])
        self.assertEqual([v['name'] for k,v in self.calls if k=='output'],['AUDIT-C','AUDIT-A','AUDIT-B','AUDIT-C'])
        pin=next(v for k,v in self.calls if k=='lua' and 'hl.monitor(' in v)
        self.assertEqual(pin.count('hl.monitor('),3)
    def test_noop_preview_does_not_write_any_output_rules(self):
        result=core.begin(self.request());core.confirm(result['token'])
        self.assertFalse(any(k=='output' for k,v in self.calls))
    def shared_link(self):
        """The driver releases an old allocation only after readback settles."""
        limit=sum(m['width']*m['height']*m['refreshRate'] for m in self.raw)
        pending={}
        apply=self.apply_output
        verify=core.verify
        def program(out):
            current=next(m for m in self.raw if m['name']==out['name'])
            if core.reduces_mode_load(out,current):
                pending[out['name']]=deepcopy(out)
                return
            demand=sum(m['width']*m['height']*m['refreshRate'] for m in self.raw if m['name']!=out['name'])+core.mode_load(out)
            if demand>limit+1:raise ValueError('Fixture shared payload exhausted')
            apply(out)
        def readback(outputs,timeout=3):
            for out in outputs:
                if out['name'] in pending:apply(pending.pop(out['name']))
            return verify(outputs,timeout)
        return patch.object(core,'apply_output',side_effect=program),patch.object(core,'verify',side_effect=readback)
    def test_apply_releases_shared_payload_before_increasing_another_output(self):
        self.raw[0].update(width=1280,height=720)
        req=self.request()
        req['outputs'][0]['mode']='1920x1080@60.00Hz'
        req['outputs'][1]['mode']='1280x720@60.00Hz'
        program,readback=self.shared_link()
        with program,readback:result=core.begin(req)
        self.assertEqual(result['state'],'preview')
        self.assertEqual([v['name'] for k,v in self.calls if k=='output'],['AUDIT-B','AUDIT-A'])
    def test_rollback_releases_shared_payload_before_restoring_a_larger_mode(self):
        self.raw[1].update(width=1280,height=720)
        req=self.request()
        req['outputs'][0]['mode']='1280x720@60.00Hz'
        req['outputs'][1]['mode']='1920x1080@60.00Hz'
        result=core.begin(req)
        self.calls=[]
        program,readback=self.shared_link()
        with program,readback:restored=core.revert(result['token'])
        self.assertEqual(restored['state'],'reverted')
        self.assertEqual([v['name'] for k,v in self.calls if k=='output'][:2],['AUDIT-B','AUDIT-A'])
    def test_rejected_mode_rule_is_restored_even_if_actual_mode_did_not_change(self):
        req=self.request();req['outputs'][2]['mode']='1280x720@60.00Hz'
        original=self.apply_output
        def reject(out):
            if out['mode'].startswith('1280'):self.calls.append(('rejected',out));return
            original(out)
        with patch.object(core,'apply_output',side_effect=reject),patch.object(core,'verify',side_effect=[None,ValueError('fixture rejected mode'),None]):
            with self.assertRaisesRegex(ValueError,'previous layout restored'):core.begin(req)
        self.assertEqual([v['name'] for k,v in self.calls if k=='output'],['AUDIT-A','AUDIT-B','AUDIT-C'])
    def test_main_home_selection_does_not_allocate_or_move_workspaces(self):
        before=deepcopy(self.ws)
        core.workspace_operation({'action':'default-home','monitor':'AUDIT-A'})
        core.restore_policy(startup=True)
        self.assertEqual(self.ws,before)
        self.assertFalse(any(k in ('focus','output','workspace.move') for k,v in self.calls))
    def test_default_independent_model_has_no_eager_pins(self):
        self.assertEqual(core.store()['workspaceMode'],'independent')
        core.restore_policy(startup=True)
        self.assertFalse(self.rules)
        self.assertEqual(len(self.ws),3)
    def test_empty_external_initial_workspaces_are_real_but_quiet(self):
        snap=core.snapshot()
        self.assertEqual([w['id'] for w in snap['workspaces'] if w['indicatorVisible']],[1])
        self.assertEqual(len(snap['workspaces']),3)
        self.assertEqual(self.calls,[])
    def test_first_used_external_slot_is_one_and_has_independent_native_id(self):
        core.snapshot()
        core.workspace_operation({'action':'create','monitor':'AUDIT-B'})
        new=core.snapshot()['workspaces'][-1]
        self.assertNotEqual(new['id'],1)
        self.assertEqual(new['displayLabel'],'1')
        self.assertTrue(new['indicatorVisible'])
    def test_occupied_external_is_never_hidden_and_gets_local_one(self):
        core.snapshot();self.ws[1]['windows']=2
        new=core.snapshot()['workspaces'][1]
        self.assertEqual(new['displayLabel'],'1');self.assertTrue(new['indicatorVisible']);self.assertTrue(new['occupied'])
    def test_empty_external_retires_when_focus_returns_to_another_monitor(self):
        core.workspace_operation({'action':'create','monitor':'AUDIT-B'})
        wid=self.raw[1]['activeWorkspace']['id']
        self.assertTrue(next(w for w in core.snapshot()['workspaces'] if w['id']==wid)['indicatorVisible'])
        core.dispatch('focus',{'monitor':'AUDIT-A'});self.calls=[]
        snap=core.snapshot();record=core.store()['workspaces'][str(wid)]
        self.assertFalse(next(w for w in snap['workspaces'] if w['id']==wid)['indicatorVisible'])
        self.assertEqual(record['slot'],0);self.assertFalse(record['used']);self.assertFalse(self.calls)
        self.assertTrue(any(w['id']==wid for w in self.ws))
        core.workspace_operation({'action':'switch','id':wid})
        shown=next(w for w in core.snapshot()['workspaces'] if w['id']==wid)
        self.assertTrue(shown['indicatorVisible']);self.assertEqual(shown['displayLabel'],'1')
    def test_closing_last_window_on_unfocused_external_retires_indicator(self):
        self.ws[1]['windows']=1;core.snapshot()
        core.dispatch('focus',{'monitor':'AUDIT-A'});self.ws[1]['windows']=0;self.calls=[]
        snap=core.snapshot();self.assertFalse(snap['workspaces'][1]['indicatorVisible']);self.assertFalse(self.calls)
    def test_occupied_or_explicitly_pinned_external_stays_visible_after_focus_leaves(self):
        self.ws[1]['windows']=1;self.ws[2]['ispersistent']=True
        core.dispatch('focus',{'monitor':'AUDIT-A'})
        snap=core.snapshot();self.assertTrue(snap['workspaces'][1]['indicatorVisible']);self.assertTrue(snap['workspaces'][2]['indicatorVisible'])
    def test_retired_empty_external_slot_can_be_reused_without_aliasing_native_ids(self):
        core.workspace_operation({'action':'create','monitor':'AUDIT-B'})
        old=self.raw[1]['activeWorkspace']['id'];core.dispatch('focus',{'monitor':'AUDIT-A'});core.snapshot()
        core.workspace_operation({'action':'create','monitor':'AUDIT-B'})
        new=self.raw[1]['activeWorkspace']['id'];self.assertNotEqual(new,old)
        snap=core.snapshot();record=next(w for w in snap['workspaces'] if w['id']==new)
        self.assertEqual(record['displayLabel'],'1');self.assertTrue(record['indicatorVisible'])
    def test_destroyed_dynamic_workspace_leaves_no_ghost_metadata(self):
        core.workspace_operation({'action':'create','monitor':'AUDIT-B'})
        wid=self.ws.pop()['id'];core.snapshot()
        self.assertNotIn(str(wid),core.store()['workspaces'])
    def test_optional_external_visibility_does_not_create_any_workspaces(self):
        before=deepcopy(self.ws)
        core.workspace_operation({'action':'external-indicators','visible':True})
        self.assertEqual(self.ws,before)
        self.assertTrue(all(w['indicatorVisible'] for w in core.snapshot()['workspaces']))
    def test_old_session_dynamic_ids_are_not_adopted_by_unrelated_outputs(self):
        core.snapshot();data=core.store();data['workspaceSession']='old-session';data['workspaces']['2']['home']='unrelated';core.atomic_json(core.store_path(),data)
        snap=core.snapshot();self.assertFalse(snap['workspaces'][1]['guest'])
    def test_migration_unpins_generated_defaults_without_moving_windows(self):
        snap=core.snapshot();data=core.store();data.pop('workspaceLifecycleVersion');data['workspaceMode']='global'
        home=snap['displays'][0]['key'];data['workspaceDefaultHome']=home
        data['workspaces']['1'].update(persistent=True,home=home)
        core.atomic_json(core.store_path(),data);self.ws[0]['windows']=2;before=deepcopy(self.ws)
        core.workspace_operation({'action':'dynamic-defaults'})
        self.assertEqual(self.ws,before);self.assertEqual(core.store()['workspaceMode'],'independent')
        self.assertFalse(core.store()['workspaces']['1']['persistent'])
    def projection_fixture(self):
        self.raw[0]['name']='eDP-FIXTURE';self.ws[0]['monitor']='eDP-FIXTURE'
    def test_projection_planning_never_changes_devices(self):
        self.projection_fixture()
        for mode in ('pc-only','duplicate','extend','external-only','custom'):
            result=core.projection_plan({'mode':mode})
            self.assertEqual(result['state'],'projection-plan')
        self.assertEqual(self.calls,[])
    def test_projection_pc_only_keeps_windows_and_extend_restores_native_groups(self):
        self.projection_fixture();self.ws[1]['windows']=3
        req=core.projection_plan({'mode':'pc-only'});res=core.begin(req);core.confirm(res['token'])
        self.assertTrue(all(w['monitor']=='eDP-FIXTURE' for w in self.ws))
        self.assertEqual(self.ws[1]['windows'],3)
        req=core.projection_plan({'mode':'extend'});res=core.begin(req);core.confirm(res['token'])
        self.assertEqual(self.ws[1]['monitor'],'AUDIT-B')
    def test_projection_external_group_excludes_unselected_monitors(self):
        self.projection_fixture()
        req=core.projection_plan({'mode':'external-only','externals':['AUDIT-C']})
        self.assertEqual([o['name'] for o in req['outputs'] if o['enabled']],['AUDIT-C'])
    def test_projection_pc_only_unavailable_without_internal_output(self):
        with self.assertRaisesRegex(ValueError,'built-in'):core.projection_plan({'mode':'pc-only'})
        self.assertFalse(self.calls)
    def test_projection_duplicate_is_native_mirroring_with_single_source(self):
        req=core.projection_plan({'mode':'duplicate','source':'AUDIT-B'})
        self.assertEqual([o['mirrorOf'] for o in req['outputs']],['AUDIT-B','','AUDIT-B'])
        res=core.begin(req);core.confirm(res['token'])
        self.assertTrue(all(w['monitor']=='AUDIT-B' for w in self.ws))
    def test_startup_restores_confirmed_layout_without_expiring_back_to_defaults(self):
        req=self.request();req['outputs'][2]['y']=1080
        result=core.begin(req);core.confirm(result['token'])
        self.raw[2]['y']=0
        result=core.restore()
        self.assertEqual(result['state'],'committed');self.assertEqual(self.raw[2]['y'],1080)
    def startup_clock(self):
        clock=[0.0]
        patch.object(core.time,'monotonic',side_effect=lambda:clock[0]).start()
        patch.object(core.time,'sleep',side_effect=lambda seconds:clock.__setitem__(0,clock[0]+seconds)).start()
        return clock
    def test_startup_waits_for_late_mst_connectors_then_restores_once(self):
        core.save_current();self.raw[2]['y']=1080
        original=core.snapshot;observations=[]
        def delayed(*args):
            snap=original(*args);observations.append(True)
            if len(observations)==1:snap['displays']=snap['displays'][:1]
            return snap
        self.startup_clock()
        with patch.object(core,'snapshot',side_effect=delayed):result=core.restore_startup(2,.2)
        self.assertEqual(result['state'],'committed');self.assertEqual(self.raw[2]['y'],0)
        self.assertGreater(len(observations),2)
        calls=len(self.calls);self.assertEqual(core.restore_startup(),result);self.assertEqual(len(self.calls),calls)
        self.assertEqual(json.loads((Path(self.tmp.name)/'state/senomyos/display-startup.json').read_text()),result)
    def test_startup_absent_setup_times_out_without_any_device_mutation(self):
        core.save_current();self.raw.pop();self.calls=[];self.startup_clock()
        result=core.restore_startup(.4,.2)
        self.assertEqual(result['state'],'startup-unavailable');self.assertFalse(result['ok']);self.assertFalse(self.calls)
        self.assertEqual(len(core.store()['lastKnownGood']),3)
    def test_startup_matching_layout_does_not_arm_or_write_outputs(self):
        core.save_current();self.calls=[]
        result=core.restore_startup(0,0)
        self.assertEqual(result['state'],'matching')
        self.assertFalse(any(c[0] in ('armed','output') for c in self.calls))
    def test_startup_never_overrides_a_user_preview_or_completed_action(self):
        core.save_current()
        core.atomic_json(core.state_path(),dict(instance=core.instance(),state='reverted'))
        self.calls=[]
        result=core.restore_startup(0,0)
        self.assertEqual(result['state'],'startup-skipped');self.assertFalse(self.calls)
    def test_startup_checks_user_ownership_again_under_the_apply_lock(self):
        core.save_current();self.raw[2]['y']=1080;self.calls=[]
        original=core.begin
        def intervening(request):
            core.atomic_json(core.state_path(),dict(instance=core.instance(),state='committed'))
            return original(request)
        with patch.object(core,'begin',side_effect=intervening):result=core.restore_startup(0,0)
        self.assertEqual(result['state'],'startup-failed')
        self.assertIn('yielded',result['message']);self.assertEqual(self.raw[2]['y'],1080)
        self.assertFalse(any(c[0] in ('armed','output') for c in self.calls))
    def test_startup_without_explicit_instance_fails_before_compositor_access(self):
        with patch.dict(os.environ,{'HYPRLAND_INSTANCE_SIGNATURE':''}):
            with self.assertRaisesRegex(ValueError,'explicit compositor'):core.restore_startup()
        self.assertFalse(self.calls)
    def test_startup_guard_failure_is_recorded_without_unprotected_retry(self):
        core.save_current();self.raw[2]['y']=1080
        with patch.object(core,'arm_watchdog',side_effect=ValueError('Fixture recovery unavailable')):
            result=core.restore_startup(0,0)
        self.assertEqual(result['state'],'startup-failed');self.assertFalse(result['ok'])
        self.assertFalse(any(c[0]=='output' for c in self.calls))
    def test_projection_restore_does_not_reuse_native_ids_in_a_new_session(self):
        self.projection_fixture();self.ws[1]['windows']=1
        result=core.begin(core.projection_plan({'mode':'pc-only'}));core.confirm(result['token'])
        data=core.store();data['projectionReturn']['instance']='older-session';core.atomic_json(core.store_path(),data)
        self.assertEqual(core.projection_plan({'mode':'extend'})['workspaceTargets'],{})
    def test_invalid_workspace_restore_target_never_arms_or_changes_devices(self):
        req=self.request();req['workspaceTargets']={'1':'missing-display'}
        with self.assertRaisesRegex(ValueError,'targets'):core.begin(req)
        self.assertEqual(self.calls,[])
    def test_disabled_output_uses_its_last_confirmed_mode(self):
        core.save_current();self.raw[1].update(width=0,height=0,refreshRate=0,disabled=True)
        item=core.snapshot(False)['displays'][1]
        self.assertEqual(core.configuration(item)['mode'],'1920x1080@60.00000')
    def test_editor_draft_survives_reboot_with_mandatory_review(self):
        value=dict(edits={'fixture':{'x':-10}},baseline=[])
        core.save_editor_draft(value);self.assertEqual(core.saved_editor_draft(),value)
        (core.runtime_dir()/'display-editor-draft.json').unlink()
        with patch.dict(os.environ,{'HYPRLAND_INSTANCE_SIGNATURE':'new-session'}):
            self.assertEqual(core.saved_editor_draft(),dict(value,requiresReview=True))
        core.save_editor_draft(dict(edits={},baseline=[]))
        self.assertIsNone(core.saved_editor_draft())
        self.assertEqual(self.calls,[])
    def test_discarding_editor_draft_clears_private_recovery_file(self):
        core.save_editor_draft(dict(edits={'fixture':{'x':-10}},baseline=[]))
        core.save_editor_draft(dict(edits={},baseline=[]))
        self.assertIsNone(core.saved_editor_draft())
    def test_identical_external_edids_remain_two_detected_displays(self):
        for item in self.raw[1:]:item.update(make='Same',model='Same',serial='Same')
        snap=core.snapshot(False)
        self.assertEqual(len(snap['displays']),3)
        self.assertEqual(len({m['key'] for m in snap['displays']}),3)
        self.assertTrue(all(not m['identityStrong'] for m in snap['displays'][1:]))
    def test_reenabled_external_gets_a_quiet_native_landing_workspace(self):
        core.snapshot(False);self.raw[1]['disabled']=True;core.snapshot(False)
        self.raw[1].update(disabled=False,activeWorkspace={'id':21});self.ws[1].update(id=21,name='21')
        snap=core.snapshot(False)
        new=next(w for w in snap['workspaces'] if w['id']==21)
        self.assertFalse(new['indicatorVisible']);self.assertFalse(new['occupied'])
    def test_revert_restores_surviving_active_workspaces_and_focused_monitor(self):
        self.raw[0]['focused']=True
        req=self.request();req['outputs'][2]['y']=1080
        result=core.begin(req)
        self.raw[0]['focused']=False;self.raw[1]['focused']=True
        core.revert(result['token'])
        self.assertTrue(self.raw[0]['focused']);self.assertFalse(self.raw[1]['focused'])
        self.assertEqual([m['activeWorkspace']['id'] for m in self.raw],[1,2,3])
    def test_mode_error_identifies_requested_and_actual_mode(self):
        out=core.configuration(self.raw[2]);out['mode']='1280x720@60.00Hz'
        with patch.object(core,'boottime',side_effect=[0,4]):
            with self.assertRaisesRegex(ValueError,'AUDIT-C: requested 1280x720.*actual 1920x1080'):core.verify([out])
    def test_save_running_layout_persists_without_device_writes(self):
        self.assertEqual(core.snapshot()['savedLayout']['status'],'none')
        self.assertEqual(core.save_current()['state'],'saved')
        self.assertEqual(self.calls,[])
        self.assertEqual(core.snapshot()['savedLayout']['status'],'matching')
        self.assertEqual(len(core.store()['lastKnownGood']),3)
        self.raw[2]['y']=1080
        self.assertEqual(core.snapshot()['savedLayout']['status'],'changed')
    def test_save_running_refuses_pending_preview(self):
        core.begin(self.request())
        with self.assertRaisesRegex(ValueError,'preview'):core.save_current()
    def test_saved_status_matches_connector_churn_but_not_different_hardware(self):
        core.save_current();self.raw[2]['name']='AUDIT-NEW';self.ws[2]['monitor']='AUDIT-NEW'
        self.assertEqual(core.snapshot()['savedLayout']['status'],'matching')
        self.raw[2]['serial']='different-monitor'
        self.assertEqual(core.snapshot()['savedLayout']['status'],'different-setup')
    def test_visible_fallback_acknowledgement_writes_no_outputs_or_saved_layout(self):
        result=core.begin(self.request());state=core.read_json(core.state_path());state.update(state='recovery-failed',message='fixture original mode rejected');core.atomic_json(core.state_path(),state)
        self.calls=[];result=core.accept_recovery(result['token'])
        self.assertEqual(result['state'],'recovered-safe');self.assertEqual(self.calls,[])
        self.assertNotIn('lastKnownGood',core.store());self.assertFalse(core.transaction_active())
        self.assertEqual(core.read_json(core.state_path())['recoveryError'],'fixture original mode rejected')
    def test_visible_fallback_acknowledgement_cannot_bypass_preview(self):
        result=core.begin(self.request())
        with self.assertRaisesRegex(ValueError,'failed recovery'):core.accept_recovery(result['token'])
    def test_visible_fallback_acknowledgement_restores_precommit_store(self):
        result=core.begin(self.request());state=core.read_json(core.state_path());previous=core.store()
        state.update(state='recovery-failed',commitStoreBefore=previous);core.atomic_json(core.state_path(),state)
        altered=deepcopy(previous);altered['lastKnownGood']=[];core.atomic_json(core.store_path(),altered)
        core.accept_recovery(result['token']);self.assertEqual(core.store(),previous)
    def test_visible_fallback_acknowledgement_rejects_stale_session(self):
        result=core.begin(self.request());state=core.read_json(core.state_path());state.update(state='recovery-failed',instance='old-session');core.atomic_json(core.state_path(),state)
        with self.assertRaisesRegex(ValueError,'session changed'):core.accept_recovery(result['token'])
    def test_wrong_readback_is_not_success(self):
        with patch.object(core,'query',return_value=[]),patch.object(core,'boottime',side_effect=[0,5]):
            with self.assertRaisesRegex(ValueError,'readback'):core.verify([dict(name='missing',enabled=True)],timeout=1)

class Adapter(unittest.TestCase):
    def test_zero_exit_rejection_is_not_success(self):
        with patch.object(core,'command',return_value="keyword can't work with non-legacy parsers. Use eval."):
            with self.assertRaisesRegex(ValueError,'rejected'):core.evaluate('harmless fixture')
    def test_apply_uses_lua_and_preserves_other_rule_fields(self):
        out=dict(name='Fixture',mode='1920x1080@60Hz',enabled=True,x=-1920,y=0,scale=1,transform=0,mirrorOf='')
        with patch.object(core,'evaluate') as call:core.apply_output(out)
        code=call.call_args.args[0];self.assertIn('hl.monitor(',code);self.assertIn('position="-1920x0"',code);self.assertNotIn('keyword',code);self.assertNotIn('vrr',code)

if __name__=='__main__':unittest.main()
