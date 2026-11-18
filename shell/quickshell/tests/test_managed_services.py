#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('services',Path(__file__).resolve().parents[1]/'scripts/managed-services.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

def output(**overrides):
    fields=dict(Id='pipewire.service',LoadState='loaded',ActiveState='active',SubState='running',MainPID='100',InvocationID='old',StateChangeTimestampMonotonic='123',CanStart='yes',CanStop='yes')
    fields.update(overrides)
    return subprocess.CompletedProcess([],0,'\n'.join(k+'='+v for k,v in fields.items()),'')

class Services(unittest.TestCase):
    def setUp(self):
        self.which=patch.object(m.shutil,'which',return_value='/usr/bin/systemctl');self.which.start();self.addCleanup(self.which.stop)
    def test_fixed_user_scope_and_allowlist(self):
        with patch.object(m,'run',return_value=output()) as run:
            item=m.snapshot('pipewire.service')
            self.assertTrue(item['restartAllowed']);self.assertEqual(item['pid'],100)
            self.assertEqual(run.call_args.args[0][:4],['/usr/bin/systemctl','--user','show','pipewire.service'])
        for unit in ['senomy-quickshell.service','evil.service','pipewire.service;id','sshd.service']:
            with self.assertRaises(ValueError):m.snapshot(unit)
    def test_absent_systemctl(self):
        with patch.object(m.shutil,'which',return_value=None):
            self.assertFalse(m.catalog()['available'])
            with self.assertRaises(OSError):m.snapshot('pipewire.service')
    def test_not_loaded_transition_and_protected(self):
        for fields in [{'LoadState':'not-found'},{'ActiveState':'activating'},{'CanStop':'no'},{'CanStart':'no'}]:
            with patch.object(m,'run',return_value=output(**fields)):
                self.assertFalse(m.snapshot('pipewire.service')['restartAllowed'])
    def test_malformed_wrong_identity_and_oversized(self):
        for result in [output(Id='another.service'),output(MainPID='abc'),subprocess.CompletedProcess([],0,'Id=pipewire.service',''),subprocess.CompletedProcess([],0,'x'*9000,'')]:
            with patch.object(m,'run',return_value=result):
                with self.assertRaises(ValueError):m.snapshot('pipewire.service')
    def test_stale_token_does_not_restart(self):
        with patch.object(m,'run',return_value=output()) as run:
            with self.assertRaises(ValueError):m.restart('pipewire.service','0'*64)
            self.assertEqual(run.call_count,1)
    def test_confirmed_restart_observed_new_instance(self):
        with patch.object(m,'run',return_value=output()): token=m.snapshot('pipewire.service')['token']
        with patch.object(m,'run',side_effect=[output(),subprocess.CompletedProcess([],0,'',''),output(InvocationID='new',MainPID='101')]) as run:
            self.assertEqual(m.restart('pipewire.service',token)['state'],'succeeded')
            self.assertEqual(run.call_args_list[1].args[0],['/usr/bin/systemctl','--user','restart','pipewire.service'])
    def test_success_requires_new_active_instance(self):
        with patch.object(m,'run',return_value=output()): token=m.snapshot('pipewire.service')['token']
        for fields in [{},{'InvocationID':'new','ActiveState':'failed'},{'InvocationID':''}]:
            with patch.object(m,'run',side_effect=[output(),subprocess.CompletedProcess([],0,'',''),output(**fields)]):
                self.assertEqual(m.restart('pipewire.service',token)['state'],'unverified')
    def test_restart_timeout(self):
        with patch.object(m,'run',return_value=output()): token=m.snapshot('pipewire.service')['token']
        with patch.object(m,'run',side_effect=[output(),subprocess.TimeoutExpired(['systemctl'],30)]):
            with self.assertRaises(subprocess.TimeoutExpired):m.restart('pipewire.service',token)
    def test_identity_change_changes_token(self):
        with patch.object(m,'run',return_value=output()): first=m.snapshot('pipewire.service')['token']
        for fields in [{'InvocationID':'new'},{'MainPID':'101'},{'StateChangeTimestampMonotonic':'124'}]:
            with patch.object(m,'run',return_value=output(**fields)):
                self.assertNotEqual(m.snapshot('pipewire.service')['token'],first)
    def test_unknown_commands_and_bad_targets(self):
        with patch('builtins.print'):
            self.assertEqual(m.main(['restart-confirmed','evil.service','0'*64]),1)
            self.assertEqual(m.main(['arbitrary']),1)
            self.assertEqual(m.main(['process','0']),1)
    def test_association_only_main_pid_owned(self):
        with patch.object(m.Path,'stat') as stat,patch.object(m,'catalog',return_value={'items':[{'pid':42,'restartAllowed':True,'unit':'pipewire.service'}]}):
            stat.return_value.st_uid=m.os.getuid()
            self.assertTrue(m.association('42')['supported']);self.assertFalse(m.association('43')['supported'])
            stat.return_value.st_uid=m.os.getuid()+1;self.assertFalse(m.association('42')['supported'])

if __name__=='__main__':unittest.main()
