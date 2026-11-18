import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from bluetooth_model import Controller, ADAPTER, DEVICE, BATTERY

A='/org/bluez/hci0'; D=A+'/dev_AA_BB_CC_DD_EE_FF'; E=A+'/dev_11_22_33_44_55_66'

class BluetoothTransactions(unittest.TestCase):
    def setUp(self):
        self.now=0;self.calls=[]
        self.model=Controller(lambda op,stage,done:self.calls.append((copy.deepcopy(op),stage,done)),clock=lambda:self.now)
        self.objects={A:{ADAPTER:{'Powered':True,'Alias':'Adapter'}},D:{DEVICE:{'Adapter':A,'Name':'Earbuds','Alias':'Earbuds','Address':'AA:BB:CC:DD:EE:FF','Paired':True,'Connected':False,'Trusted':True,'Blocked':False}}}
        self.model.provider(':test',copy.deepcopy(self.objects));self.model.set_context(True)
    def request(self,action='connect',path=D,value=None):
        return self.model.request({'action':action,'path':path,'token':self.model.tokens.get(path),'adapterToken':self.model.tokens.get(A),'expected':self.model.expected(path),'value':value})[0]
    def props(self,path=D,**changes):
        self.objects[path][DEVICE if path!=A else ADAPTER].update(changes)
        self.model.update(copy.deepcopy(self.objects))
    def done(self,index=0,name='',detail=''):
        op,stage,callback=self.calls[index];callback(op['path'],op['id'],stage,name,detail)
    def op(self,path=D):return self.model.operations[path]
    def test_success_needs_reply_and_observation(self):
        self.assertTrue(self.request());self.done();self.assertEqual(self.op()['phase'],'running')
        self.props(Connected=True);self.assertEqual(self.op()['phase'],'succeeded')
    def test_property_before_reply_stays_managed(self):
        self.request();self.props(Connected=True);self.assertEqual(self.op()['phase'],'running');self.done();self.assertEqual(self.op()['phase'],'succeeded')
    def test_precise_failure_and_retry(self):
        self.request();self.done(name='org.bluez.Error.Failed',detail='br-connection-page-timeout')
        self.assertEqual(self.op()['phase'],'failed');self.assertIn('did not answer',self.op()['message']);self.assertTrue(self.request());self.assertEqual(len(self.calls),2)
    def test_different_errors_remain_distinct(self):
        for code,detail,phrase in [('AuthenticationFailed','bad key','authentication'),('NotReady','','not ready'),('InProgress','','another operation'),('Failed','profile-unavailable','service is unavailable'),('Failed','unknown','could not complete')]:
            self.request();self.done(len(self.calls)-1,'org.bluez.Error.'+code,detail);self.assertIn(phrase,self.op()['message'])
    def test_double_click_has_one_backend_call(self):
        self.assertTrue(self.request());self.assertFalse(self.request());self.assertEqual(len(self.calls),1)
    def test_connect_cancel_calls_cleanup_while_disconnected(self):
        self.request();self.assertTrue(self.model.cancel(D));self.assertEqual(self.calls[1][1],'cleanup')
        self.done(1);self.assertEqual(self.op()['phase'],'cancelling');self.done(0,'org.bluez.Error.Canceled','cancelled');self.assertEqual(self.op()['phase'],'cancelled')
    def test_cancel_race_keeps_connected(self):
        self.request();self.model.cancel(D);self.props(Connected=True);self.done(0);self.done(1)
        self.assertEqual(self.op()['phase'],'succeeded');self.assertTrue(self.model.snapshot()['devices'][0]['connected'])
    def test_cancel_error_never_claims_cancelled(self):
        self.request();self.model.cancel(D);self.done(0,'org.bluez.Error.Canceled','');self.done(1,'org.bluez.Error.Failed','error')
        self.assertEqual(self.op()['phase'],'failed');self.assertIn('could not be confirmed',self.op()['message'])
    def test_timeout_attempts_cleanup_and_bounded_resolution(self):
        self.request();self.now=31;self.model.tick();self.assertEqual(self.op()['phase'],'cancelling')
        self.assertEqual(len(self.calls),2);self.now=42;self.model.tick();self.assertEqual(self.op()['phase'],'failed');self.assertTrue(self.request())
    def test_late_callback_cannot_overwrite_retry(self):
        self.request();self.now=31;self.model.tick();self.now=42;self.model.tick();self.request();new=self.op()['id']
        self.done(0,'org.bluez.Error.Failed','old error');self.done(1);self.assertEqual(self.op()['id'],new);self.assertEqual(self.op()['phase'],'running')
    def test_no_reply_triggers_real_cleanup(self):
        self.request();self.done(name='org.freedesktop.DBus.Error.NoReply',detail='timed out');self.assertEqual(self.op()['phase'],'cancelling');self.assertEqual(len(self.calls),2)
    def test_view_close_keeps_connect_and_cancels_pair(self):
        self.request();self.model.set_context(False);self.assertEqual(self.op()['phase'],'running');self.model.set_context(True)
        self.done(name='org.bluez.Error.Failed');self.props(Paired=False);self.request('pair');self.model.set_context(False);self.assertEqual(self.op()['phase'],'cancelling')
    def test_pair_cancel_waits_for_both_replies(self):
        self.props(Paired=False);self.assertTrue(self.request('pair'));self.model.cancel(D);self.done(0,'org.bluez.Error.Canceled');self.assertEqual(self.op()['phase'],'cancelling');self.done(1);self.assertEqual(self.op()['phase'],'cancelled')
    def test_service_restart_invalidates_incarnation(self):
        self.request();token=self.model.tokens[D];self.model.provider(':new',copy.deepcopy(self.objects));self.assertEqual(self.op()['phase'],'failed');self.assertNotEqual(token,self.model.tokens[D]);self.done();self.assertEqual(self.op()['phase'],'failed')
    def test_removed_readded_path_is_new_device(self):
        self.request();token=self.model.tokens[D];objects=copy.deepcopy(self.objects);del objects[D];self.model.update(objects);self.model.update(copy.deepcopy(self.objects));self.assertNotEqual(token,self.model.tokens[D]);self.done();self.assertEqual(self.op()['phase'],'failed')
    def test_per_device_operations_are_independent(self):
        self.objects[E]=copy.deepcopy(self.objects[D]);self.objects[E][DEVICE]['Name']='Keyboard';self.model.update(copy.deepcopy(self.objects))
        self.assertTrue(self.request());self.assertTrue(self.request(path=E));self.assertEqual(len(self.calls),2)
    def test_adapter_change_conflicts_with_active_device(self):
        self.request();self.assertFalse(self.request('disable',A));self.assertEqual(len(self.calls),1)
    def test_blocked_and_disabled_connect_rejected(self):
        self.props(Blocked=True);self.assertFalse(self.request());self.props(Blocked=False);self.props(A,Powered=False);self.assertFalse(self.request())
    def test_stale_preview_state_rejected(self):
        req={'action':'connect','path':D,'token':self.model.tokens[D],'expected':self.model.expected(D)}
        self.props(Blocked=True);self.assertFalse(self.model.request(req)[0]);self.assertEqual(self.calls,[])
    def test_forget_only_succeeds_on_removal(self):
        self.assertTrue(self.request('forget'));self.done();self.assertEqual(self.op()['phase'],'running');del self.objects[D];self.model.update(copy.deepcopy(self.objects));self.assertEqual(self.op()['phase'],'succeeded')
    def test_alias_and_trust_need_readback(self):
        self.request('rename',value='My earbuds');self.done();self.assertEqual(self.op()['phase'],'running');self.props(Alias='My earbuds');self.assertEqual(self.op()['phase'],'succeeded')
        self.assertFalse(self.request('rename',value='bad\nname'));self.assertTrue(self.request('untrust'));self.done(1);self.props(Trusted=False);self.assertEqual(self.op()['phase'],'succeeded')
    def test_known_devices_never_claim_freshness_from_cache(self):
        self.props(Paired=False);device=self.model.snapshot()['devices'][0];self.assertEqual(device['group'],'other');self.assertFalse(device['recent'])
        self.model.update(copy.deepcopy(self.objects),[D]);self.assertEqual(self.model.snapshot()['devices'][0]['group'],'nearby');self.now=46;self.assertFalse(self.model.snapshot()['devices'][0]['recent'])
    def test_battery_only_if_reported(self):
        self.assertIsNone(self.model.snapshot()['devices'][0]['battery']);self.objects[D][BATTERY]={'Percentage':73};self.model.update(copy.deepcopy(self.objects));self.assertEqual(self.model.snapshot()['devices'][0]['battery'],73)
    def test_scan_deliberate_bounded_and_owned(self):
        self.assertEqual(self.calls,[]);self.assertTrue(self.model.start_scan(A));self.assertFalse(self.model.start_scan(A));self.done();self.assertTrue(self.model.scan['owned']);self.now=31;self.model.tick();self.assertEqual(self.calls[-1][1],'cleanup');self.done(1);self.assertEqual(self.model.scan['state'],'idle')
    def test_scan_does_not_release_another_clients_session(self):
        self.props(A,Discovering=True);self.model.set_context(False);self.assertEqual(self.calls,[])
        self.model.set_context(True);self.model.start_scan(A);self.done();self.model.stop_scan();self.done(1);self.assertTrue(self.objects[A][ADAPTER]['Discovering'])
    def test_close_while_scan_start_pending_releases_after_reply(self):
        self.model.start_scan(A);self.model.set_context(False);self.assertEqual(len(self.calls),1);self.done();self.assertEqual(len(self.calls),2);self.done(1);self.assertFalse(self.model.scan['owned'])
    def test_offline_management_is_allowed_but_connections_are_not(self):
        self.props(A,Powered=False)
        self.assertFalse(self.request('connect'))
        self.assertTrue(self.request('rename',value='Desk buds'));self.done();self.props(Alias='Desk buds');self.assertEqual(self.op()['phase'],'succeeded')
        self.assertTrue(self.request('forget'));self.done(1);del self.objects[D];self.model.update(copy.deepcopy(self.objects));self.assertEqual(self.op()['phase'],'succeeded')
    def test_remove_cannot_silently_forget_a_pairing(self):
        self.assertFalse(self.request('remove'));self.assertEqual(self.calls,[])
        self.props(Paired=False,Bonded=True);self.assertFalse(self.request('remove'))
        self.props(Paired=False,Bonded=False);self.assertTrue(self.request('remove'));self.done();self.assertEqual(self.op()['phase'],'running');del self.objects[D];self.model.update(copy.deepcopy(self.objects));self.assertEqual(self.op()['phase'],'succeeded')
    def test_wake_requires_capability_and_boolean_and_observation(self):
        self.assertFalse(self.request('wake',value=True))
        self.props(WakeAllowed=False);self.assertFalse(self.request('wake',value='true'));self.assertTrue(self.request('wake',value=True));self.done();self.assertEqual(self.op()['phase'],'running');self.props(WakeAllowed=True);self.assertEqual(self.op()['phase'],'succeeded')
    def test_optional_properties_stay_unknown_and_rssi_expires(self):
        device=self.model.snapshot()['devices'][0];self.assertIsNone(device['wakeAllowed']);self.assertIsNone(device['rssi']);self.assertIsNone(device['lastObservedAt'])
        self.props(RSSI=-51,Class=2360324,Modalias='bluetooth:v02B0p0000d001F',WakeAllowed=False)
        self.model.update(copy.deepcopy(self.objects),[D]);device=self.model.snapshot()['devices'][0]
        self.assertEqual(device['rssi'],-51);self.assertEqual(device['class'],2360324);self.assertIsNotNone(device['lastObservedAt'])
        self.now=46;self.assertIsNone(self.model.snapshot()['devices'][0]['rssi'])
    def test_same_name_devices_keep_distinct_identities(self):
        self.objects[E]=copy.deepcopy(self.objects[D]);self.objects[E][DEVICE].update(Paired=False,Address='11:22:33:44:55:66');self.model.update(copy.deepcopy(self.objects),[E])
        devices=self.model.snapshot()['devices'];self.assertEqual(len(devices),2);self.assertNotEqual(devices[0]['token'],devices[1]['token']);self.assertTrue(self.request('connect',D));self.assertEqual(self.calls[0][0]['path'],D)
    def test_alias_reset_without_remote_name_uses_reported_address(self):
        self.props(Name='',Alias='Local alias');self.assertTrue(self.request('rename',value=''));self.done();self.props(Alias='AA:BB:CC:DD:EE:FF');self.assertEqual(self.op()['phase'],'succeeded')
    def test_foreign_actions_rejected(self):
        self.assertFalse(self.request('shell'));self.assertEqual(self.calls,[])

    def test_adapter_replacement_releases_obsolete_scan_identity(self):
        self.assertTrue(self.model.start_scan(A));self.done();self.assertTrue(self.model.scan['owned'])
        self.model.update({});self.assertFalse(self.model.scan['owned']);self.model.update(copy.deepcopy(self.objects));self.assertTrue(self.model.start_scan(A))
        self.done(0);self.assertEqual(self.model.scan['state'],'starting') # obsolete reply cannot own new adapter
        self.done(1);self.assertTrue(self.model.scan['owned'])
    def test_removed_adapter_while_starting_ignores_late_discovery_reply(self):
        self.model.start_scan(A);self.model.update({});self.done();self.assertFalse(self.model.scan['owned']);self.assertEqual(self.model.scan['state'],'idle')
        self.model.update(copy.deepcopy(self.objects));self.assertTrue(self.model.start_scan(A))

if __name__=='__main__':unittest.main()
