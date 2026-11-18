#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('profiles',Path(__file__).resolve().parents[1]/'scripts/network-profiles.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
UUID='12345678-1234-1234-1234-123456789abc'

def output(active='no',auto='yes',kind='802-11-wireless',name='A\\:B\\\\C'):
    return subprocess.CompletedProcess([],0,f'{UUID}:{name}:{kind}:{auto}:{active}\n','')

class Profiles(unittest.TestCase):
    def setUp(self):
        owner=patch.object(m,'provider_identity',return_value='fixture-owner');owner.start();self.addCleanup(owner.stop)
        p=patch.object(m.shutil,'which',side_effect=lambda name:'/usr/bin/'+name);p.start();self.addCleanup(p.stop)
    def test_structured_inventory_escaping_and_no_secret_fields(self):
        with patch.object(m,'run',return_value=output()) as run:
            result=m.catalog();self.assertEqual(result['items'][0]['name'],'A:B\\C');self.assertTrue(result['editorAvailable'])
            self.assertEqual(run.call_args.args[0][5],'UUID,NAME,TYPE,AUTOCONNECT,ACTIVE')
            self.assertNotIn('secret',run.call_args.args[0]);self.assertNotIn('password',run.call_args.args[0])
    def test_invalid_inventory_and_oversized(self):
        for text in ['invalid','not-a-uuid:name:wifi:yes:no','x'*270000,output().stdout.rstrip()+'\\']:
            with patch.object(m,'run',return_value=subprocess.CompletedProcess([],0,text,'')):
                with self.assertRaises(ValueError):m.catalog()
    def test_absence_and_unsupported_types_are_read_only(self):
        with patch.object(m.shutil,'which',return_value=None):
            with self.assertRaises(OSError):m.catalog()
        with patch.object(m,'run',return_value=output(kind='loopback')):self.assertFalse(m.catalog()['items'][0]['mutable'])
    def token(self,**kw):
        with patch.object(m,'run',return_value=output(**kw)):return m.catalog()['items'][0]['token']
    def test_stale_identity_never_applies(self):
        for verb in ['forget','disconnect','autoconnect']:
            with patch.object(m,'run',return_value=output()) as run:
                with self.assertRaises(ValueError):m.reviewed(verb,UUID,'0'*64)
                self.assertEqual(run.call_count,1)
    def test_active_forget_and_inactive_disconnect_rejected(self):
        for verb,active in [('forget','yes'),('disconnect','no')]:
            token=self.token(active=active)
            with patch.object(m,'run',return_value=output(active=active)) as run:
                with self.assertRaises(ValueError):m.reviewed(verb,UUID,token)
                self.assertEqual(run.call_count,1)
    def test_forget_observed_absence(self):
        token=self.token()
        with patch.object(m,'run',side_effect=[output(),subprocess.CompletedProcess([],0,'',''),subprocess.CompletedProcess([],0,'','')]) as run:
            self.assertEqual(m.reviewed('forget',UUID,token)['state'],'succeeded')
            self.assertEqual(run.call_args_list[1].args[0][-3:],['delete','uuid',UUID])
    def test_disconnect_observed_inactive(self):
        token=self.token(active='yes')
        with patch.object(m,'run',side_effect=[output(active='yes'),output(),output()]) as run:
            self.assertEqual(m.reviewed('disconnect',UUID,token)['state'],'succeeded')
            self.assertEqual(run.call_args_list[1].args[0][-3:],['down','uuid',UUID])
    def test_autoconnect_exact_policy_and_no_activation(self):
        token=self.token()
        with patch.object(m,'run',side_effect=[output(),output(),output(auto='no')]) as run:
            self.assertEqual(m.reviewed('autoconnect',UUID,token)['state'],'succeeded')
            args=run.call_args_list[1].args[0];self.assertEqual(args[-5:],['modify','uuid',UUID,'connection.autoconnect','no']);self.assertNotIn('up',args)
    def test_unchanged_or_missing_after_read_is_unverified(self):
        token=self.token()
        for after in [output(),subprocess.TimeoutExpired([],5)]:
            with patch.object(m,'run',side_effect=[output(),output(),after]):
                self.assertEqual(m.reviewed('autoconnect',UUID,token)['state'],'unverified')
    def test_fixed_native_handoff_and_uuid_validation(self):
        with patch.object(m,'launch_tool',return_value={'ok':True}) as launch,patch.object(m,'run',return_value=output()):
            self.assertEqual(m.open_editor('vpn')['state'],'started');launch.assert_called_with('network-editor',['vpn'])
            m.open_editor('edit',UUID);launch.assert_called_with('network-editor',['edit',UUID])
            with self.assertRaises(ValueError):m.open_editor('edit','evil;id')
            with self.assertRaises(ValueError):m.open_editor('shell')
    def test_failure_output_is_generic_and_unsupported_cli_rejected(self):
        with patch('builtins.print') as emit,patch.object(m,'run',side_effect=subprocess.CalledProcessError(1,[],stderr='private token')):
            self.assertEqual(m.main(['catalog']),1);self.assertNotIn('private token',str(emit.call_args))
        with patch('builtins.print'):self.assertEqual(m.main(['apply-confirmed','forget',UUID]),1)

class NetworkCompletion(unittest.TestCase):
    setUp=Profiles.setUp
    token=Profiles.token
    # Shared fixtures are reused without repeating inherited cases.
    def test_reviewed_connect_uses_owned_native_authentication(self):
        token=self.token()
        with patch.object(m,'run',return_value=output()) as run,patch.object(m,'launch_tool',return_value={'ok':True}) as launch:
            self.assertEqual(m.reviewed('connect',UUID,token)['state'],'awaiting-activation')
            launch.assert_called_once_with('network-profile-auth',[UUID]);self.assertEqual(run.call_count,1)
        token=self.token(active='yes')
        with patch.object(m,'run',return_value=output(active='yes')),patch.object(m,'launch_tool') as launch:
            with self.assertRaises(ValueError):m.reviewed('connect',UUID,token)
            launch.assert_not_called()
    def test_authentication_handoff_failure_is_not_success(self):
        token=self.token()
        with patch.object(m,'run',return_value=output()),patch.object(m,'launch_tool',return_value={'ok':False,'message':'Scope creation failed'}):
            with self.assertRaisesRegex(ValueError,'Scope creation failed'):m.reviewed('connect',UUID,token)
    def test_provider_identity_is_in_token_and_drift_is_refused(self):
        a=self.token()
        with patch.object(m,'provider_identity',return_value='replacement'):b=self.token()
        self.assertNotEqual(a,b)
        with patch.object(m,'provider_identity',side_effect=['first','second']),patch.object(m,'run',return_value=output()):
            with self.assertRaises(ValueError):m.catalog()
    def test_replaced_provider_cannot_report_profile_success(self):
        token=self.token()
        with patch.object(m,'provider_identity',side_effect=['fixture-owner','fixture-owner','new','new']),patch.object(m,'run',side_effect=[output(),output(),output(auto='no')]):
            self.assertEqual(m.reviewed('autoconnect',UUID,token)['state'],'unverified')
    def test_unavailable_snapshot_clears_stale_inventory(self):
        from unittest.mock import Mock
        client=Mock();client.get_dbus_name_owner.return_value='';client.get_nm_running.return_value=False
        data=m.network_snapshot(client);self.assertFalse(data['providerAvailable']);self.assertEqual(data['items'],[]);self.assertEqual(data['devices'],[]);client.get_connections.assert_not_called()
    def test_signal_cleanup_never_calls_device_disconnect(self):
        from gi.repository import GObject
        class Device(GObject.Object):
            flag=GObject.Property(type=bool,default=False)
            def disconnect(self,*args):raise AssertionError('Device disconnect must never be used for signal cleanup')
        device=Device();seen=[];handler=GObject.Object.connect(device,'notify::flag',lambda *args:seen.append(True));bindings=[(device,handler)]
        m.release_signals(bindings);device.flag=True;self.assertEqual(seen,[]);self.assertEqual(bindings,[])
    def test_structured_ip_preserves_ipv6_dns_and_routes(self):
        from unittest.mock import Mock
        address=Mock();address.get_address.return_value='2001:db8::10';address.get_prefix.return_value=64
        route=Mock();route.get_dest.return_value='::';route.get_prefix.return_value=0;route.get_next_hop.return_value='fe80::1';route.get_metric.return_value=42
        config=Mock();config.get_addresses.return_value=[address];config.get_nameservers.return_value=['2001:db8::53'];config.get_gateway.return_value='fe80::1';config.get_routes.return_value=[route]
        data=m.ip_details(config);self.assertEqual(data['addresses'],['2001:db8::10/64']);self.assertEqual(data['routes'][0]['nextHop'],'fe80::1');self.assertEqual(data['dns'],['2001:db8::53']);self.assertIsNone(m.ip_details(None)['gateway'])
    def test_activating_vpn_is_not_an_activated_profile(self):
        from types import SimpleNamespace as N
        from unittest.mock import Mock
        client=Mock();client.get_dbus_name_owner.return_value='owner';client.get_nm_running.return_value=True
        client.get_primary_connection.return_value=None;client.get_devices.return_value=[]
        client.connectivity_check_get_uri.return_value='http://example.invalid/check';client.get_connectivity.return_value=N(value_nick='portal')
        active=Mock();active.get_uuid.return_value=UUID;active.get_state.return_value=N(value_nick='activating');active.get_id.return_value='Fixture VPN';active.get_connection_type.return_value='vpn';client.get_active_connections.return_value=[active]
        profile=Mock();profile.get_uuid.return_value=UUID;profile.get_id.return_value='Fixture VPN';profile.get_connection_type.return_value='vpn';profile.get_setting_connection.return_value.get_autoconnect.return_value=False;client.get_connections.return_value=[profile]
        data=m.network_snapshot(client);self.assertFalse(data['items'][0]['active']);self.assertEqual(data['activeTunnels'][0]['state'],'activating')
        active.get_state.return_value=N(value_nick='activated');self.assertTrue(m.network_snapshot(client)['items'][0]['active'])
        client.connectivity_check_get_uri.return_value='https://user:secret@example.invalid/check';self.assertEqual(m.network_snapshot(client)['portalUri'],'')

if __name__=='__main__':unittest.main()
