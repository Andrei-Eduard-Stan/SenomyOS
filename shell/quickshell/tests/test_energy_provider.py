#!/usr/bin/env python3
"""Inert policy/transport tests: no live profile or sysfs writes."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('energy', Path(__file__).parents[1]/'scripts/energy-provider.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)


def tlp(active=True, modern=True, profile='balanced'):
    return dict(active=active, modern=modern, profile=profile, identity='invocation-1')


def endpoint(owner=':1.5', executable='tlp-pd', active='balanced'):
    return dict(owner=owner, executable=executable, name=m.ENDPOINTS[0][0], path=m.ENDPOINTS[0][1],
                properties={'ActiveProfile':active, 'Profiles':[{'Profile':p} for p in m.PROFILES]})


def snapshot(profile='balanced', kind='tlp', identity='invocation-1', available=True, token='review-token'):
    return {'ok':True,'backend':dict(active=profile,kind=kind,identity=identity,available=available,
                profiles=list(m.PROFILES),token=token,reason='',conflict=False,
                busName=m.ENDPOINTS[0][0], objectPath=m.ENDPOINTS[0][1])}


class BusError(Exception): pass


class FakeSystem(m.System):
    def __init__(self, states=None, result=0, error=None):
        self.states = states or [snapshot(), snapshot('power-saver')]
        self.index=0; self.commands=[]; self.calls=[]; self.result=result; self.error=error
        self.GLib=types.SimpleNamespace(Error=BusError, Variant=lambda *x:x)
    def status(self):
        value=self.states[min(self.index,len(self.states)-1)]; self.index+=1
        if isinstance(value, Exception): raise value
        return value
    def command(self, argv, timeout=4):
        self.commands.append((argv,timeout))
        if self.error: raise self.error
        return subprocess.CompletedProcess(argv,self.result,'','')
    def call(self,*args,**kwargs):
        self.calls.append(args)
        if self.error: raise self.error
        return ()


class Ownership(unittest.TestCase):
    def test_active_tlp_without_profile_daemon(self):
        b=m.choose(tlp(),[],{},True)
        self.assertTrue(b['available']); self.assertEqual(b['profiles'],list(m.PROFILES)); self.assertEqual(b['kind'],'tlp')
    def test_missing_inactive_and_legacy_tlp(self):
        for value in (tlp(False),tlp(True,False),tlp(True,True,'')):
            self.assertFalse(m.choose(value,[],{},True)['available'])
    def test_missing_authentication_dependency(self):
        self.assertFalse(m.choose(tlp(),[],{},False)['available'])
    def test_compatible_tlp_pd_and_late_owner(self):
        self.assertEqual(m.choose(tlp(),[endpoint()],{},True)['kind'],'dbus')
        self.assertEqual(m.choose(tlp(False),[],{},True)['kind'],'none')
        self.assertEqual(m.choose(tlp(False),[endpoint(executable='power-profiles-daemon')],{},True)['kind'],'dbus')
        self.assertFalse(m.choose(tlp(False),[],{},True)['available'])
    def test_python_tlp_pd_is_identified_by_bus_pid_and_active_unit(self):
        e=endpoint(executable='python3.14');e['pid']=4321
        units={'tlp-pd.service':{'ActiveState':'active','MainPID':'4321'}}
        b=m.choose(tlp(),[e],units,True)
        self.assertFalse(b['conflict']);self.assertTrue(b['available']);self.assertEqual(b['kind'],'dbus')
        units['tlp-pd.service']['MainPID']='4322'
        self.assertTrue(m.choose(tlp(),[e],units,True)['conflict'])
    def test_conflicting_policy_writers_disable_selection(self):
        cases=[([endpoint(executable='power-profiles-daemon')],{}),
               ([],{'tuned.service':{'ActiveState':'active'}}),
               ([endpoint(),endpoint(owner=':1.9')],{})]
        for endpoints,units in cases:
            b=m.choose(tlp(),endpoints,units,True)
            self.assertTrue(b['conflict']);self.assertFalse(b['available']);self.assertEqual(b['profiles'],[])
    def test_aliases_of_same_owner_are_not_two_daemons(self):
        self.assertFalse(m.choose(tlp(),[endpoint(),endpoint()],{},True)['conflict'])
    def test_holds_degradation_and_unsupported_profiles(self):
        e=endpoint();e['properties'].update(Profiles=[{'Profile':'balanced'},{'Profile':'fake'}], ActiveProfileHolds=[{'ApplicationId':'app','Profile':'balanced','Reason':'test'}], PerformanceDegraded='high-temperature')
        b=m.choose(tlp(),[e],{},True)
        self.assertEqual(b['profiles'],['balanced']);self.assertEqual(b['degraded'],'high-temperature');self.assertEqual(len(b['holds']),1)
    def test_invalid_active_profile_disables_actions(self):
        self.assertFalse(m.choose(tlp(),[endpoint(active='unknown')],{},True)['available'])
    def test_tuned_bridge_is_one_policy_owner(self):
        units={name:{'ActiveState':'active'} for name in ('tuned.service','tuned-ppd.service')}
        b=m.choose(tlp(False),[endpoint(executable='tuned-ppd')],units,True)
        self.assertFalse(b['conflict']);self.assertTrue(b['available'])
    def test_unrecognized_bridge_with_competing_active_service_is_not_assumed_safe(self):
        b=m.choose(tlp(False),[endpoint(executable='unknown-daemon')],{'auto-cpufreq.service':{'ActiveState':'active'}},True)
        self.assertTrue(b['conflict']);self.assertFalse(b['available'])


class Transactions(unittest.TestCase):
    request={'profile':'power-saver','token':'review-token'}
    def test_verified_tlp_uses_only_fixed_unprivileged_auth_handoff(self):
        s=FakeSystem();result=s.set_profile(self.request)
        self.assertTrue(result['ok']);self.assertEqual(result['state'],'verified')
        self.assertEqual(s.commands,[(['/usr/bin/pkexec','/usr/bin/tlp','power-saver'],90)])
    def test_unsupported_payloads_never_submit(self):
        for req in ({'profile':'../evil','token':'review-token'}, {'profile':'balanced','token':'x','command':'x'},[],{'profile':'balanced','token':None}):
            s=FakeSystem()
            with self.assertRaises(m.Problem):s.set_profile(req)
            self.assertEqual(s.commands,[])
    def test_stale_review_on_provider_source_or_external_profile_change(self):
        s=FakeSystem([snapshot(token='changed')])
        with self.assertRaisesRegex(m.Problem,'changed during review'):s.set_profile(self.request)
        self.assertEqual(s.commands,[])
    def test_unavailable_profile_never_submits(self):
        s=FakeSystem([snapshot(available=False)])
        with self.assertRaises(m.Problem):s.set_profile(self.request)
        self.assertEqual(s.commands,[])
    def test_auth_cancel_and_rejection_preserve_prior_reported_profile(self):
        for code in (1,126,127):
            s=FakeSystem([snapshot(),snapshot()],result=code);out=s.set_profile(self.request)
            self.assertFalse(out['ok']);self.assertEqual(out['state'],'rejected');self.assertEqual(out['backend']['active'],'balanced');self.assertEqual(len(s.commands),1)
    def test_partial_failure_does_not_rollback_external_state(self):
        s=FakeSystem(result=1);out=s.set_profile(self.request)
        self.assertFalse(out['ok']);self.assertEqual(out['state'],'partially-applied');self.assertEqual(len(s.commands),1)
    def test_acceptance_with_readback_mismatch_is_not_success(self):
        s=FakeSystem([snapshot(),snapshot()]);out=s.set_profile(self.request)
        self.assertFalse(out['ok']);self.assertEqual(out['state'],'unverified')
    def test_backend_restarts_during_request_is_unverified(self):
        s=FakeSystem([snapshot(),snapshot('power-saver',identity='new-owner')]);out=s.set_profile(self.request)
        self.assertFalse(out['ok']);self.assertEqual(out['state'],'unverified')
    def test_error_followed_by_owner_replacement_is_unverified(self):
        s=FakeSystem([snapshot(),snapshot(identity='new-owner')],result=1)
        self.assertEqual(s.set_profile(self.request)['state'],'unverified')
    def test_timeout_is_unverified_without_retry(self):
        s=FakeSystem([snapshot(),snapshot()],error=m.Problem('unverified','timed out'))
        self.assertEqual(s.set_profile(self.request)['state'],'unverified');self.assertEqual(len(s.commands),1)
    def test_readback_loss_never_claims_success(self):
        s=FakeSystem([snapshot(),RuntimeError('owner lost')]);self.assertEqual(s.set_profile(self.request)['state'],'unverified')
    def test_dbus_set_targets_unique_owner_not_replacement_service(self):
        s=FakeSystem([snapshot(kind='dbus',identity=':1.5'),snapshot('power-saver',kind='dbus',identity=':1.5')]);out=s.set_profile(self.request)
        self.assertTrue(out['ok']);self.assertEqual(s.calls[0][0],':1.5');self.assertEqual(s.calls[0][3],'Set');self.assertEqual(s.commands,[])
    def test_dbus_rejection(self):
        s=FakeSystem([snapshot(kind='dbus'),snapshot(kind='dbus')],error=BusError('denied'))
        self.assertEqual(s.set_profile(self.request)['state'],'rejected')
    def test_real_glib_timeout_category_is_uncertain_not_refusal(self):
        from gi.repository import Gio, GLib
        error=GLib.Error.new_literal(Gio.io_error_quark(),'inert timeout',Gio.IOErrorEnum.TIMED_OUT)
        self.assertEqual(m.System.bus_problem(error).state,'unverified')
    def test_already_active_request_is_noop(self):
        s=FakeSystem([snapshot('power-saver')]);self.assertEqual(s.set_profile(self.request)['state'],'verified');self.assertEqual(s.commands,[])


class Diagnostics(unittest.TestCase):
    def test_missing_nonfinite_negative_and_real_zero(self):
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'sensor'
            self.assertIsNone(m.number(p))
            for bad in ('NaN','inf','-1','garbage'):
                p.write_text(bad);self.assertIsNone(m.number(p))
            p.write_text('0');self.assertEqual(m.number(p),0)
    def test_two_battery_health_thresholds_and_inhibitor_order(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for name,energy,design in [('BAT0','20000000','25000000'),('BAT1','30000000','50000000')]:
                p=root/'class/power_supply'/name;p.mkdir(parents=True)
                for k,v in {'type':'Battery','present':'1','energy_full':energy,'energy_full_design':design,'cycle_count':'20','charge_control_start_threshold':'75','charge_control_end_threshold':'80'}.items():(p/k).write_text(v)
            s=FakeSystem();s.sysroot=root
            def call(*args,**kwargs):
                return ([('sleep','video-player','Playback','delay',1000,123)],) if args[3]=='ListInhibitors' else ({'IdleAction':'ignore','HandleLidSwitch':'ignore'},)
            s.call=call
            out=s.details();self.assertEqual([p['healthPercent'] for p in out['packs']],[80,60]);self.assertFalse(out['packs'][0]['thresholdEditing'])
            self.assertEqual(out['inhibitors'][0]['who'],'video-player');self.assertEqual(out['inhibitors'][0]['what'],'sleep');self.assertEqual(out['inhibitors'][0]['mode'],'delay')
    def test_absent_and_peripheral_batteries_not_included(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for name,fields in [('BAT0',{'present':'0'}),('mouse',{'scope':'Device'})]:
                p=root/'class/power_supply'/name;p.mkdir(parents=True)
                for k,v in dict(type='Battery',**fields).items():(p/k).write_text(v)
            s=FakeSystem();s.sysroot=root;s.call=lambda *args,**kwargs:([],) if args[3]=='ListInhibitors' else ({},)
            self.assertEqual(s.details()['packs'],[])
    def test_missing_health_and_logind_are_explicit(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);p=root/'class/power_supply/BAT0';p.mkdir(parents=True);(p/'type').write_text('Battery')
            s=FakeSystem(error=BusError());s.sysroot=root;out=s.details()
            self.assertIsNone(out['packs'][0]['healthPercent']);self.assertTrue(out['error'])


if __name__=='__main__':unittest.main()
