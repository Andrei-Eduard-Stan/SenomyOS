"""All action and systemd boundaries are inert. No real session mutations."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from datetime import datetime,timezone
from zoneinfo import ZoneInfo
import subprocess
import os
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('session_scheduler',Path(__file__).resolve().parents[1]/'scripts/session-scheduler.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
Problem=module.Problem
class FakeRuntime:
    def __init__(self,root,persistent=None):
        self.root=Path(root);self.persistent_root=Path(persistent or self.root/'durable')
        self.clock=datetime(2026,11,1,12,tzinfo=timezone.utc).timestamp();self.boot=1000.;self.mono=1000.
        self.session={'session':'2','boot':'test-boot','signature':'test-desktop'}
        self.units=set();self.calls=[];self.fail_arm=False;self.fail_stop=False;self.fail_action=False;self.zone_changed=False;self.session_ended=False;self.manager=True
    def now(self):return self.clock
    def boottime(self):return self.boot
    def monotonic(self):return self.mono
    def advance(self,seconds,suspend=False):
        self.clock+=seconds;self.boot+=seconds
        if not suspend:self.mono+=seconds
    def identity(self,expected=None):
        if self.session_ended or expected and expected!=self.session:raise Problem('This login ended.')
        return dict(self.session)
    def zone(self):return ZoneInfo('Europe/London')
    def zone_id(self):return 'changed' if self.zone_changed else 'London'
    def available(self,action,identity):
        if action not in module.ACTIONS:raise Problem('Unavailable.')
    def timer_available(self):return self.manager
    def arm(self,record):
        if self.fail_arm:raise Problem('Worker unavailable.')
        self.units.add(record['unit']);self.calls.append(('arm',record['id']))
    def timer_active(self,record):return record['unit'] in self.units
    def stop(self,record):
        if self.fail_stop:raise Problem('Could not stop worker.')
        self.units.discard(record['unit']);self.calls.append(('stop',record['id']))
    def notify_failure(self,label,message):self.calls.append(('notice',label))
    def execute(self,action,identity):
        self.identity(identity)
        if self.fail_action:raise Problem('Action failed without force.')
        self.calls.append(('execute',action))

class SchedulerTest(unittest.TestCase):
    def setUp(self):self.temp=tempfile.TemporaryDirectory();self.rt=FakeRuntime(Path(self.temp.name)/'runtime');self.engine=module.Scheduler(self.rt)
    def tearDown(self):self.temp.cleanup()
    def prepare(self,**extra):
        form={'action':'reboot','mode':'delay','seconds':'1800'};form.update(extra);return self.engine.prepare(form)['review']
    def arm(self,**extra):return self.engine.commit(self.prepare(**extra)['id'])['schedule']
    def executions(self):return [c for c in self.rt.calls if c[0]=='execute']
    def just_before(self,plan):
        # Emulate an available worker's previous sample just before the deadline.
        self.rt.advance(self.engine.remaining(self.engine.state())-1)
        with self.engine.locked():
            record=self.engine.state();self.engine.heartbeat(record);self.engine.save(record)
    def test_selection_prepare_has_no_side_effect(self):
        review=self.prepare();self.assertEqual(review['dueEpoch'],self.rt.now()+1800);self.assertFalse(self.rt.calls);self.assertNotIn('identity',review)
    def test_review_confirm_is_required_and_once(self):
        r=self.prepare(mode='now');self.assertFalse(self.executions());self.engine.commit(r['id']);self.assertEqual(self.executions(),[('execute','reboot')])
        with self.assertRaises(Problem):self.engine.commit(r['id'])
    def test_every_original_immediate_action_uses_existing_boundary(self):
        for action in module.ACTIONS:self.engine.commit(self.prepare(mode='now',action=action)['id'])
        self.assertEqual([c[1] for c in self.executions()],list(module.ACTIONS))
    def test_countdown_starts_at_confirmation(self):
        r=self.prepare();self.rt.advance(60);plan=self.engine.commit(r['id'])['schedule'];self.assertEqual(plan['remainingSeconds'],1800);self.assertEqual(plan['dueEpoch'],self.rt.now()+1800)
    def test_expired_review_refused(self):
        r=self.prepare();self.rt.advance(121)
        with self.assertRaises(Problem):self.engine.commit(r['id'])
        self.assertFalse(self.rt.calls)
    def test_timezone_change_requires_new_review(self):
        r=self.prepare(mode='at',date='2026-11-01',time='18:30');self.rt.zone_changed=True
        with self.assertRaises(Problem):self.engine.commit(r['id'])
    def test_changed_session_review_refused(self):
        r=self.prepare();self.rt.session['session']='9'
        with self.assertRaises(Problem):self.engine.commit(r['id'])
    def test_countdown_survives_ui_reload(self):
        plan=self.arm();fresh=module.Scheduler(self.rt);self.assertEqual(fresh.status()['schedule']['id'],plan['id']);self.assertEqual(fresh.status()['schedule']['state'],'scheduled')
    def test_countdown_invalid_after_logout_same_runtime(self):
        plan=self.arm();self.rt.session_ended=True;self.engine.tick(plan['id']);self.assertEqual(self.engine.state()['state'],'missed');self.assertFalse(self.executions())
    def test_countdown_not_present_new_runtime(self):
        self.arm();rt=FakeRuntime(Path(self.temp.name)/'new-runtime',self.rt.persistent_root);self.assertEqual(module.Scheduler(rt).status()['schedule'],{})
    def test_absolute_survives_new_login_and_boot(self):
        plan=self.arm(mode='at',date='2026-11-02',time='18:30');rt=FakeRuntime(Path(self.temp.name)/'new-runtime',self.rt.persistent_root);rt.session['boot']='newboot';rt.session['session']='8';rt.clock+=3600;rt.boot=10;rt.mono=10
        fresh=module.Scheduler(rt);view=fresh.status()['schedule'];self.assertEqual(view['id'],plan['id']);self.assertEqual(view['state'],'scheduled');self.assertTrue(rt.timer_active(fresh.state()));self.assertEqual(view['timezone'],'Europe/London');self.assertFalse([c for c in rt.calls if c[0]=='execute'])
    def test_absolute_missed_on_boot_never_catches_up(self):
        plan=self.arm(mode='at',date='2026-11-01',time='18:30');rt=FakeRuntime(Path(self.temp.name)/'new-runtime',self.rt.persistent_root);rt.clock=plan['dueEpoch']+1
        view=module.Scheduler(rt).status()['schedule'];self.assertEqual(view['state'],'missed');self.assertFalse(rt.calls);self.assertTrue((self.rt.persistent_root/'absolute.json').exists())
    def test_future_absolute_retained_without_login(self):
        self.arm(mode='at',date='2026-11-02',time='18:30');self.rt.session_ended=True;self.rt.units.clear();self.assertEqual(self.engine.status()['schedule']['state'],'scheduled');self.assertFalse(self.executions())
    def test_missing_absolute_worker_restores_only_future(self):
        plan=self.arm(mode='at',date='2026-11-01',time='18:30');self.rt.units.clear();self.assertEqual(self.engine.status()['schedule']['state'],'scheduled');self.assertTrue(self.rt.timer_active(self.engine.state()));self.assertFalse(self.executions())
    def test_absolute_restore_failure_retains_instruction_and_error(self):
        self.arm(mode='at',date='2026-11-01',time='18:30');self.rt.units.clear();self.rt.fail_arm=True;v=self.engine.status();self.assertIn('unavailable',v['reason']);self.assertEqual(v['schedule']['state'],'scheduled')
    def test_duplicate_dispatch_guard(self):
        plan=self.arm();self.just_before(plan);self.rt.advance(1);self.engine.fire(plan['id']);self.engine.fire(plan['id']);self.assertEqual(self.executions(),[('execute','reboot')]);self.assertEqual(self.engine.state()['state'],'succeeded')
    def test_worker_ticks_dispatch_at_continuously_available_deadline(self):
        plan=self.arm(seconds='2');self.rt.advance(1);self.assertTrue(self.engine.tick(plan['id']));self.rt.advance(1);self.assertFalse(self.engine.tick(plan['id']));self.assertEqual(self.executions(),[('execute','reboot')])
    def test_countdown_ignores_wallclock_changes(self):
        plan=self.arm(seconds='2');self.rt.clock+=10000;self.assertEqual(self.engine.display(self.engine.state())['remainingSeconds'],2);self.rt.advance(2);self.engine.tick(plan['id']);self.assertEqual(len(self.executions()),1)
    def test_suspend_over_deadline_never_executes_even_one_second_late(self):
        plan=self.arm(seconds='30');self.rt.advance(31,suspend=True);self.engine.tick(plan['id']);self.assertEqual(self.engine.state()['state'],'missed');self.assertFalse(self.executions())
    def test_scheduler_unavailable_over_deadline_never_executes(self):
        plan=self.arm(seconds='30');self.rt.advance(31);self.engine.tick(plan['id']);self.assertEqual(self.engine.state()['state'],'missed');self.assertFalse(self.executions())
    def test_absolute_clock_forward_across_deadline_is_missed(self):
        plan=self.arm(mode='at',date='2026-11-01',time='12:01');self.rt.clock+=61;self.rt.boot+=1;self.rt.mono+=1;self.engine.tick(plan['id']);self.assertEqual(self.engine.state()['state'],'missed');self.assertFalse(self.executions())
    def test_resume_before_deadline_can_continue(self):
        plan=self.arm(seconds='30');self.rt.advance(10,suspend=True);self.assertTrue(self.engine.tick(plan['id']));self.assertEqual(self.engine.display(self.engine.state())['remainingSeconds'],20)
    def test_early_fire_refused(self):
        plan=self.arm();self.engine.fire(plan['id']);self.assertEqual(self.engine.state()['state'],'missed');self.assertFalse(self.executions())
    def test_cancel_queued_deadline(self):
        plan=self.arm();self.engine.cancel(plan['id']);self.rt.advance(1800);self.engine.fire(plan['id']);self.assertFalse(self.executions());self.assertEqual(self.engine.state()['state'],'cancelled')
    def test_cancel_receipt_prevents_dispatch_even_if_worker_stop_fails(self):
        self.arm();self.rt.fail_stop=True
        self.engine.cancel(self.engine.state()['id'])
        self.assertEqual(self.engine.state()['state'],'cancelled');self.assertFalse(self.executions())
    def test_replace_requires_matching_review(self):
        old=self.arm();r=self.prepare(action='lock');self.engine.cancel(old['id'])
        with self.assertRaises(Problem):self.engine.commit(r['id'])
    def test_explicit_replacement_old_worker_cannot_fire(self):
        old=self.arm();new=self.arm(action='lock',seconds='2700');self.engine.fire(old['id']);self.assertEqual(self.engine.state()['id'],new['id']);self.assertFalse(self.rt.timer_active(old));self.assertFalse(self.executions())
    def test_failed_replacement_preserves_old(self):
        old=self.arm();r=self.prepare();self.rt.fail_arm=True
        with self.assertRaises(Problem):self.engine.commit(r['id'])
        self.assertEqual(self.engine.state()['id'],old['id']);self.assertTrue(self.rt.timer_active(old))
    def test_failed_stop_cannot_revive_obsolete_replacement(self):
        old=self.arm();r=self.prepare();self.rt.fail_stop=True
        self.engine.commit(r['id'])
        self.assertNotEqual(self.engine.state()['id'],old['id']);self.engine.fire(old['id']);self.assertFalse(self.executions())
    def test_postpone_ten_and_thirty_minutes_updates_authority(self):
        old=self.arm();ten=self.engine.postpone({'id':old['id'],'seconds':600})['schedule'];self.assertEqual(ten['remainingSeconds'],2400);thirty=self.engine.postpone({'id':ten['id'],'seconds':1800})['schedule'];self.assertEqual(thirty['remainingSeconds'],4200);self.engine.fire(old['id']);self.engine.fire(ten['id']);self.assertFalse(self.executions())
    def test_postpone_preserves_absolute_type(self):
        old=self.arm(mode='at',date='2026-11-01',time='18:30');new=self.engine.postpone({'id':old['id'],'seconds':600})['schedule'];self.assertEqual(new['mode'],'at');self.assertEqual(new['dueEpoch'],old['dueEpoch']+600);self.assertTrue((self.rt.persistent_root/'absolute.json').exists())
    def test_execute_now_schedule_is_reviewed_and_claimed_once(self):
        plan=self.arm();r=self.prepare(mode='now',executeId=plan['id']);self.assertFalse(self.executions());self.engine.commit(r['id']);self.engine.fire(plan['id']);self.assertEqual(self.executions(),[('execute','reboot')]);self.assertEqual(self.engine.state()['state'],'succeeded')
    def test_execute_now_review_cannot_target_cancelled_instruction(self):
        plan=self.arm();r=self.prepare(mode='now',executeId=plan['id']);self.engine.cancel(plan['id'])
        with self.assertRaises(Problem):self.engine.commit(r['id'])
        self.assertFalse(self.executions())
    def test_missed_supports_cancel_reschedule_execute_now(self):
        plan=self.arm();self.rt.advance(1801);self.engine.tick(plan['id']);self.assertEqual(self.engine.state()['state'],'missed');r=self.prepare(mode='now',executeId=plan['id']);self.engine.commit(r['id']);self.assertEqual(len(self.executions()),1)
        plan=self.arm();self.rt.advance(1801);self.engine.tick(plan['id']);self.engine.cancel(plan['id']);self.assertEqual(self.engine.state()['state'],'cancelled')
        self.assertEqual(self.arm()['state'],'scheduled')
    def test_running_action_cannot_cancel_replace_postpone(self):
        self.arm();current=self.engine.state();current.update(state='running',claimedEpoch=self.rt.now());self.engine.save(current)
        with self.assertRaises(Problem):self.engine.cancel(current['id'])
        with self.assertRaises(Problem):self.engine.postpone({'id':current['id'],'seconds':600})
        with self.assertRaises(Problem):self.prepare()
    def test_unverified_dispatch_never_retried(self):
        self.arm();current=self.engine.state();current.update(state='running',claimedEpoch=self.rt.now()-31);self.engine.save(current);self.assertEqual(self.engine.status()['schedule']['state'],'unverified');self.engine.fire(current['id']);self.assertFalse(self.executions())
    def test_failed_action_not_retried(self):
        plan=self.arm(seconds='2');self.rt.advance(2);self.rt.fail_action=True;self.engine.tick(plan['id']);self.assertEqual(self.engine.state()['state'],'failed');self.rt.fail_action=False;self.engine.fire(plan['id']);self.assertFalse(self.executions())
    def test_worker_loss_countdown_missed(self):
        self.arm();self.rt.units.clear();self.assertEqual(self.engine.status()['schedule']['state'],'missed')
    def test_urgency_and_progress_are_shared(self):
        plan=self.arm(seconds='1800');self.assertEqual(plan['progress'],1)
        for remaining,urgency in [(600,'approaching'),(300,'warning'),(60,'critical'),(10,'final')]:
            self.rt.advance(self.engine.remaining(self.engine.state())-remaining);v=self.engine.display(self.engine.state());self.assertEqual(v['remainingSeconds'],remaining);self.assertEqual(v['urgency'],urgency);self.assertAlmostEqual(v['progress'],remaining/1800)
    def test_countdown_disk_policy_and_private_atomic_receipts(self):
        self.arm();self.assertFalse((self.rt.persistent_root/'absolute.json').exists());self.assertEqual((self.rt.root/'session-countdown.json').stat().st_mode&0o777,0o600);self.assertEqual((self.rt.root/'session-schedule.json').stat().st_mode&0o777,0o600)
    def test_absolute_private_record_and_completion_persist(self):
        plan=self.arm(mode='at',date='2026-11-01',time='12:01');self.just_before(plan);self.rt.advance(1);self.engine.tick(plan['id']);self.rt.root=Path(self.temp.name)/'fresh';rt=FakeRuntime(self.rt.root,self.rt.persistent_root);rt.clock=self.rt.clock+60;engine=module.Scheduler(rt);self.assertEqual(engine.status()['schedule']['state'],'succeeded');engine.fire(plan['id']);self.assertFalse(rt.calls);self.assertEqual((rt.persistent_root/'absolute.json').stat().st_mode&0o777,0o600)
    def test_invalid_forms_refused(self):
        for extra in [{'action':'shutdown;reboot'},{'action':{}},{'mode':'weekly'},{'seconds':'0'},{'seconds':'-1'},{'seconds':'2.5'},{'seconds':'604801'},{'seconds':'$(reboot)'}]:
            with self.assertRaises(Problem):self.prepare(**extra)
        self.assertFalse(self.rt.calls)
    def test_invalid_postponements_refused(self):
        plan=self.arm()
        for req in [{},{'id':plan['id'],'seconds':1},{'id':'stale','seconds':600}]:
            with self.assertRaises(Problem):self.engine.postpone(req)
    def test_dates_past_and_invalid(self):
        for date,time,field in [('2026-02-31','09:00','date'),('2026-11-01','25:00','time'),('2026-10-24','09:00','time'),('2028-11-25','09:00','time')]:
            with self.assertRaises(Problem) as error:self.prepare(mode='at',date=date,time=time)
            self.assertIn(field,error.exception.fields)
    def test_dst_missing_and_ambiguous(self):
        self.rt.clock=datetime(2027,3,27,12,tzinfo=timezone.utc).timestamp()
        with self.assertRaises(Problem) as error:self.prepare(mode='at',date='2027-03-28',time='01:30')
        self.assertIn('time',error.exception.fields)
        self.rt.clock=datetime(2026,10,24,12,tzinfo=timezone.utc).timestamp()
        with self.assertRaises(Problem) as error:self.prepare(mode='at',date='2026-10-25',time='01:30')
        self.assertIn('fold',error.exception.fields)
        one=self.prepare(mode='at',date='2026-10-25',time='01:30',fold=0);two=self.prepare(mode='at',date='2026-10-25',time='01:30',fold=1);self.assertEqual(two['dueEpoch']-one['dueEpoch'],3600)
    def test_concurrent_deadline_claims_dispatch_once(self):
        from concurrent.futures import ThreadPoolExecutor
        plan=self.arm(seconds='2');self.rt.advance(2)
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(lambda _:module.Scheduler(self.rt).fire(plan['id']),range(2)))
        self.assertEqual(len(self.executions()),1);self.assertEqual(self.engine.state()['state'],'succeeded')
    def test_failed_authoritative_write_does_not_replace_old_instruction(self):
        old=self.arm();review=self.prepare();original=self.engine.write
        def fail(name,value):
            if str(name)=='session-countdown.json':raise OSError('Private full storage simulation')
            return original(name,value)
        self.engine.write=fail
        with self.assertRaises(OSError):self.engine.commit(review['id'])
        self.assertEqual(self.engine.state()['id'],old['id']);self.assertTrue(self.rt.timer_active(old));self.assertFalse(self.executions())
    def test_receipt_failure_does_not_stop_already_committed_instruction(self):
        review=self.prepare(mode='at',date='2026-11-02',time='18:30');original=self.engine.write
        def fail(name,value):
            if str(name)=='session-schedule.json':raise OSError('Private receipt failure')
            return original(name,value)
        self.engine.write=fail
        with self.assertRaises(OSError):self.engine.commit(review['id'])
        record=self.engine.state();self.assertEqual(record['id'],review['id']);self.assertTrue(self.rt.timer_active(record));self.assertFalse(self.executions())
    def test_runtime_argv_supervision_no_shell_or_privileges(self):
        rt=object.__new__(module.Runtime);rt.root=self.rt.root;rt.persistent_root=self.rt.persistent_root;rt.tool=Path('/trusted/action');commands=[]
        def run(command,**kwargs):commands.append(command);return subprocess.CompletedProcess(command,0,'active','')
        rt.run=run;self.arm();plan=self.engine.state()
        with patch.dict(os.environ,{'XDG_RUNTIME_DIR':str(self.rt.root),'WAYLAND_DISPLAY':'wayland-1'}):rt.arm(plan)
        command=commands[0];self.assertIn('--property=PartOf=graphical-session.target',command);self.assertIn('--property=Type=exec',command);self.assertIn('--expand-environment=no',command);self.assertNotIn('/bin/sh',command);self.assertEqual(command[-2:],['watch',plan['id']]);self.assertFalse(any('linger' in v or 'WakeSystem' in v for v in command))

if __name__=='__main__':unittest.main()
