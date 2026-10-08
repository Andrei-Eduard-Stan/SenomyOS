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
        with patch.object(m.subprocess,'Popen') as launch,patch.object(m,'run',return_value=output()):
            self.assertEqual(m.open_editor('vpn')['state'],'started');self.assertEqual(launch.call_args.args[0],['/usr/bin/nm-connection-editor','--show','vpn'])
            m.open_editor('edit',UUID);self.assertEqual(launch.call_args.args[0][-2:],['--edit',UUID])
            with self.assertRaises(ValueError):m.open_editor('edit','evil;id')
            with self.assertRaises(ValueError):m.open_editor('shell')
    def test_failure_output_is_generic_and_unsupported_cli_rejected(self):
        with patch('builtins.print') as emit,patch.object(m,'run',side_effect=subprocess.CalledProcessError(1,[],stderr='private token')):
            self.assertEqual(m.main(['catalog']),1);self.assertNotIn('private token',str(emit.call_args))
        with patch('builtins.print'):self.assertEqual(m.main(['apply-confirmed','forget',UUID]),1)

if __name__=='__main__':unittest.main()
