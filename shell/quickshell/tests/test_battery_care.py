#!/usr/bin/env python3
"""Inert transaction tests: no real subprocess, sysfs, polkit or root write."""
import base64
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
def module(name, p):
    spec = importlib.util.spec_from_file_location(name, p); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m
core = module('care', ROOT/'components/power/battery_care.py')
client = module('client', ROOT/'shell/quickshell/scripts/battery-care-client.py')

class Fake:
    def __init__(self):
        self.directory = tempfile.TemporaryDirectory(); self.state = Path(self.directory.name); self.config = self.state/'configuration'
        self.values = {'BAT0':[0,100],'BAT1':[0,100]}; self.identities = {'BAT0':'pack0','BAT1':'pack1'}
        self.identity='owner1'; self.source='0'; self.image=None; self.other_config='unchanged'
        self.supported = {'BAT0':True,'BAT1':True}; self.persistent_available=True; self.records={}; self.commits={}; self.calls=[]
        self.failure=''; self.fail_pack='BAT1'; self.probe=True; self.snap_failure=False; self.persist_failure='';self.parse_failure=False
    def snapshot(self):
        if self.snap_failure:raise OSError('lost readback')
        d={'ok':True,'schemaVersion':1,'identity':self.identity,'sources':{'AC':self.source},'persistentAvailable':self.persistent_available,'persistenceReason':'existing threshold policy','configurationDigest':core.digest([self.image,self.other_config]),'otherConfigurationDigest':core.digest(self.other_config),'packs':[{'name':b,'identity':self.identities[b],'effective':v[:],'supported':self.supported[b]}for b,v in self.values.items()]}
        d['token']=core.digest(d);return d
    def validate_driver(self):
        if not self.probe:raise core.Refused('driver unverified')
    def set_pair(self,b,v):
        self.calls.append([b,v[:]])
        if b==self.fail_pack:
            if self.failure=='denied':return False
            if self.failure=='partial':self.values[b][0]=v[0];return False
            if self.failure=='mismatch':self.values[b]=[v[0],v[1]-1];return True
            if self.failure=='owner':self.identity='owner2'
            if self.failure=='source':self.source='1'
            if self.failure=='other-pack':self.values['BAT0']=[20,60]
            if self.failure=='configuration':self.other_config='external'
            if self.failure=='timeout':raise subprocess.TimeoutExpired(['inert'],20)
            if self.failure=='lost-readback':self.snap_failure=True
        self.values[b]=v[:];return True
    def file_image(self,path):return copy.deepcopy(self.image)
    def verify_config(self,image):return not self.parse_failure
    def replace_config(self,image):
        if self.persist_failure=='before':raise OSError('disk full')
        self.image=copy.deepcopy(image)
        if self.persist_failure=='after':raise OSError('fsync')
    def save(self,v):
        self.records[v['id']]=copy.deepcopy({k:x for k,x in v.items() if not k.startswith('_')});(self.state/(v['id']+'.json')).touch()
    def finalize(self,v):
        self.save(v);self.commits[v['id']]=core.digest(self.records[v['id']])
    def load(self,k,uid):
        v=copy.deepcopy(self.records[k])
        if v['uid']!=uid:raise core.Refused('other account')
        v['_committed']=self.commits.get(k)==core.digest(v)
        return v

class Transactions(unittest.TestCase):
    def setUp(self):self.s=Fake();self.addCleanup(self.s.directory.cleanup)
    def apply(self,changes=None,persistent=False):
        return core.operation(self.s,{'token':self.s.snapshot()['token'],'changes':changes or {'BAT0':[70,80],'BAT1':[65,85]},'persistent':persistent},1000)
    def restore(self,r):return core.operation(self.s,{'token':self.s.snapshot()['token'],'receipt':r['receipt']},1000,True)
    def test_runtime_dual_and_exact_restore(self):
        before=self.s.snapshot();r=self.apply();self.assertTrue(r['ok']);self.assertIsNone(self.s.image)
        self.assertTrue(self.restore(r)['ok']);self.assertEqual(self.s.snapshot(),before)
    def test_persistent_preserves_other_pack_and_exact_file(self):
        self.s.image={'bytes':base64.b64encode(core.render({'BAT1':[20,90]})).decode(),'mode':0o600,'uid':0,'gid':44};before=copy.deepcopy(self.s.image)
        r=self.apply({'BAT0':[70,80]},True);self.assertTrue(r['ok']);self.assertEqual(core.managed_values(self.s.image),{'BAT0':[70,80],'BAT1':[20,90]});self.assertEqual(self.s.image['mode'],0o600)
        self.assertTrue(self.restore(r)['ok']);self.assertEqual(self.s.image,before)
    def test_persistent_absence_restored(self):
        r=self.apply(persistent=True);self.assertIsNotNone(self.s.image);self.assertTrue(self.restore(r)['ok']);self.assertIsNone(self.s.image)
    def test_authenticated_history_is_account_scoped(self):
        r=self.apply()
        with patch.object(core,'trusted'):
            history=core.Machine.history(self.s,1000);self.assertEqual(history['history'][0]['receipt'],r['receipt']);self.assertNotIn('configBefore',history['history'][0]);self.assertEqual(core.Machine.history(self.s,2000)['history'],[])
    def test_same_pair_no_unnecessary_hardware_write(self):
        r=self.apply({'BAT0':[0,100]});self.assertTrue(r['ok']);self.assertEqual(self.s.calls,[])
    def test_unsupported_batch_submits_nothing(self):
        self.s.supported['BAT1']=False
        with self.assertRaises(core.Refused):self.apply()
        self.assertFalse(self.s.calls)
    def test_missing_pack_submits_nothing(self):
        del self.s.values['BAT1']
        with self.assertRaises(core.Refused):self.apply()
        self.assertFalse(self.s.calls)
    def test_missing_driver_submits_nothing(self):
        self.s.probe=False
        with self.assertRaises(core.Refused):self.apply()
        self.assertFalse(self.s.calls)
    def test_stale_after_auth_no_write(self):
        t=self.s.snapshot()['token'];self.s.identity='replacement'
        with self.assertRaises(core.Refused):core.operation(self.s,{'token':t,'changes':{'BAT0':[70,80]},'persistent':False},1000)
        self.assertFalse(self.s.calls)
    def test_existing_config_refused_before_hardware(self):
        self.s.persistent_available=False
        with self.assertRaises(core.Refused):self.apply(persistent=True)
        self.assertFalse(self.s.calls)
    def test_partial_no_config_save_and_explicit_restore(self):
        self.s.failure='partial';r=self.apply(persistent=True);self.assertFalse(r['ok']);self.assertEqual(r['state'],'partially-applied');self.assertIsNone(self.s.image);self.assertEqual(self.s.values,{'BAT0':[70,80],'BAT1':[65,100]});self.s.failure='';self.assertTrue(self.restore(r)['ok']);self.assertEqual(self.s.values,{'BAT0':[0,100],'BAT1':[0,100]})
    def test_rejection_not_success(self):
        self.s.failure='denied';r=self.apply({'BAT1':[70,80]},True);self.assertFalse(r['ok']);self.assertIsNone(self.s.image);self.assertEqual(self.s.values['BAT1'],[0,100])
    def test_readback_mismatch_not_success(self):
        self.s.failure='mismatch';r=self.apply();self.assertFalse(r['ok']);self.assertFalse(r['snapshot']['packs'][1]['effective']==[65,85])
    def test_provider_replacement_has_no_blind_recovery(self):
        self.s.failure='owner';r=self.apply();self.assertFalse(r['ok']);self.assertIsNone(r['restorableToken'])
        with self.assertRaises(core.Refused):self.restore(r)
    def test_source_drift_has_no_blind_recovery(self):
        self.s.failure='source';r=self.apply();self.assertFalse(r['ok']);self.assertIsNone(r['restorableToken'])
    def test_external_other_pack_or_config_has_no_recovery(self):
        for failure in ('other-pack','configuration'):
            self.s=Fake();self.addCleanup(self.s.directory.cleanup);self.s.failure=failure;r=self.apply({'BAT1':[70,80]});self.assertFalse(r['ok']);self.assertIsNone(r['restorableToken'])
    def test_external_change_after_success_refuses_restore(self):
        r=self.apply();self.s.values['BAT0']=[30,70]
        with self.assertRaises(core.Refused):self.restore(r)
    def test_persistence_error_preserves_preimage_runtime_explicit(self):
        self.s.persist_failure='before';r=self.apply(persistent=True);self.assertFalse(r['ok']);self.assertIsNone(self.s.image);self.assertTrue(r['restorableToken']);self.s.persist_failure='';self.assertTrue(self.restore(r)['ok'])
    def test_configuration_parser_mismatch_not_success(self):
        self.s.parse_failure=True;r=self.apply(persistent=True);self.assertFalse(r['ok']);self.assertEqual(r['state'],'partially-applied');self.s.parse_failure=False;self.assertTrue(self.restore(r)['ok'])
    def test_persistence_uncertain_after_rename_does_not_guess(self):
        self.s.persist_failure='after';r=self.apply(persistent=True);self.assertFalse(r['ok']);self.assertIsNone(r['restorableToken']);self.assertIsNotNone(self.s.image)
    def test_timeout_and_lost_readback(self):
        for failure in ('timeout','lost-readback'):
            self.s=Fake();self.addCleanup(self.s.directory.cleanup);self.s.failure=failure;r=self.apply();self.assertFalse(r['ok']);self.assertIn(r['state'],('unverified','partially-applied'))
            if failure=='lost-readback':self.assertIsNone(r['restorableToken'])
    def test_cross_user_restore_denied(self):
        r=self.apply()
        with self.assertRaises(core.Refused):core.operation(self.s,{'token':self.s.snapshot()['token'],'receipt':r['receipt']},2000,True)
    def test_receipt_durable_before_first_operation(self):
        original=self.s.set_pair
        def run(b,v):
            self.assertTrue(self.s.records);record=next(iter(self.s.records.values()));self.assertEqual(record['previous']['BAT0'],[0,100]);return original(b,v)
        self.s.set_pair=run;self.assertTrue(self.apply()['ok'])

class RecoverySecurity(unittest.TestCase):
    setUp=Transactions.setUp
    apply=Transactions.apply
    restore=Transactions.restore
    # Reuse the inert system and request builders, not the inherited test suite.
    def test_HG01_timeout_does_not_authorize_untouched_pack(self):
        def timeout(b,v):
            self.s.calls.append([b,v[:]]);self.s.values['BAT1']=[25,90]
            raise subprocess.TimeoutExpired(['inert'],20)
        self.s.set_pair=timeout;r=self.apply();external=copy.deepcopy(self.s.values)
        self.assertIsNone(r['restorableToken']);self.assertTrue(r['results']['BAT0']['attempted'])
        self.assertEqual(r['results']['BAT0']['outcome'],'uncertain');self.assertFalse(r['results']['BAT1']['attempted'])
        self.assertEqual(r['results']['BAT1']['outcome'],'untouched');calls=copy.deepcopy(self.s.calls)
        with self.assertRaises(core.Refused):self.restore(r)
        self.assertEqual(self.s.calls,calls);self.assertEqual(self.s.values,external);self.assertIsNone(self.s.image)
    def test_timeout_late_completion_remains_unrestorable(self):
        self.s.fail_pack='BAT0';self.s.failure='timeout';r=self.apply()
        self.s.values['BAT0']=[70,80];calls=copy.deepcopy(self.s.calls)
        with self.assertRaises(core.Refused):self.restore(r)
        self.assertEqual(self.s.calls,calls);self.assertEqual(self.s.values['BAT0'],[70,80])
    def test_restore_only_confirmed_modified_pack(self):
        self.s.failure='denied';r=self.apply();self.assertFalse(r['ok'])
        self.assertEqual(r['previous'],{'BAT0':[0,100]});self.assertEqual(r['results']['BAT1']['outcome'],'unchanged')
        self.s.failure='';self.s.calls.clear();self.assertTrue(self.restore(r)['ok'])
        self.assertEqual(self.s.calls,[['BAT0',[0,100]]])
    def test_restore_excludes_already_effective_pack(self):
        r=self.apply({'BAT0':[0,100],'BAT1':[70,80]});self.assertTrue(r['ok'])
        self.s.calls.clear();self.assertTrue(self.restore(r)['ok']);self.assertEqual(self.s.calls,[['BAT1',[0,100]]])
    def test_HG02_exact_owner_drift_and_final_save_failure(self):
        self.s.fail_pack='BAT0';self.s.failure='owner';save=self.s.save;counter=[0]
        def fail(v):
            counter[0]+=1
            if counter[0]>=3:raise OSError('original final receipt failure')
            save(v)
        self.s.save=fail;r=self.apply();durable=self.s.records[r['receipt']]
        self.assertIsNone(r['restorableToken']);self.assertIsNone(durable['afterToken']);self.assertFalse(durable['recoveryEligible'])
        self.s.save=save;self.s.failure='';calls=copy.deepcopy(self.s.calls)
        with self.assertRaises(core.Refused):self.restore(r)
        self.assertEqual(self.s.calls,calls);self.assertIsNone(self.s.image)
    def test_final_write_after_rename_has_no_commit_authority(self):
        save=self.s.save;failed=[False]
        def fail(v):
            if failed[0]:raise OSError('disk unavailable')
            save(v)
            if v['checkpoint']=='complete':
                failed[0]=True;raise OSError('final directory fsync failed')
        self.s.save=fail;r=self.apply();durable=self.s.records[r['receipt']]
        self.assertEqual(durable['checkpoint'],'complete');self.assertTrue(durable['afterToken'])
        self.assertNotIn(r['receipt'],self.s.commits);self.assertIsNone(r['restorableToken'])
        self.s.save=save;calls=copy.deepcopy(self.s.calls)
        with self.assertRaises(core.Refused):self.restore(r)
        self.assertEqual(calls,self.s.calls)
        with patch.object(core,'trusted'):self.assertEqual(core.Machine.history(self.s,1000)['history'],[])
    def test_interrupted_progress_has_no_authority_even_with_exact_state(self):
        save=self.s.save
        def crash(v):
            save(v)
            if any(x['outcome']=='modified' for x in v['results'].values()):raise KeyboardInterrupt('inert process loss')
        self.s.save=crash
        with self.assertRaises(KeyboardInterrupt):self.apply()
        ident=next(iter(self.s.records));self.s.save=save;calls=copy.deepcopy(self.s.calls)
        with self.assertRaises(core.Refused):self.restore({'receipt':ident})
        self.assertEqual(calls,self.s.calls)
    def test_restore_does_not_rewrite_unchanged_configuration(self):
        self.s.persist_failure='before';r=self.apply(persistent=True);self.s.persist_failure=''
        with patch.object(self.s,'replace_config',wraps=self.s.replace_config) as write:
            self.assertTrue(self.restore(r)['ok']);write.assert_not_called()
    def test_checkpoint_integrity_legacy_and_provider_binding(self):
        r=self.apply();original=copy.deepcopy(self.s.records[r['receipt']]);commit=self.s.commits[r['receipt']]
        for field,value in [('schemaVersion',1),('checkpoint','in-progress'),('recoveryEligible',False),('recoveryVerified',False),('providerIdentity','owner2'),('restoreChanges',{'BAT1':[10,20]})]:
            self.s.records[r['receipt']]=dict(copy.deepcopy(original),**{field:value})
            # Also exercise structural/provider validation with a matching digest.
            self.s.commits[r['receipt']]=core.digest(self.s.records[r['receipt']])
            with self.assertRaises(core.Refused):self.restore(r)
        self.s.records[r['receipt']]=original;self.s.commits[r['receipt']]=commit
        self.s.records[r['receipt']]['previous']['BAT0']=[1,99]
        with self.assertRaises(core.Refused):self.restore(r)
    def test_real_finalizer_never_commits_when_receipt_save_fails(self):
        from unittest.mock import Mock
        machine=Mock();machine.save.side_effect=OSError('final save')
        with self.assertRaises(OSError):core.Machine.finalize(machine,{'id':'a'*32})
        machine.write_record.assert_not_called()


class Validation(unittest.TestCase):
    def test_boundaries_and_types(self):
        for v in ([0,1],[0,100],[96,100],[99,100]):self.assertEqual(core.pair(v),v)
        for v in ([True,80],[70.,80],['70',80],[-1,80],[0,101],[99,99],[80,70],[0,0],None,[50]):
            with self.assertRaises(core.Refused):core.pair(v)
    def test_fixed_targets_and_schema(self):
        for b in ('BAT2','../../etc/passwd','BAT0;touch /tmp/oops'):
            with self.assertRaises(core.Refused):core.request_valid({'token':'a'*64,'persistent':False,'changes':{b:[70,80]}})
        with self.assertRaises(core.Refused):core.request_valid({'token':'a'*64,'persistent':'yes','changes':{'BAT0':[70,80]}})
        with self.assertRaises(core.Refused):core.request_valid({'token':int('1'*64),'persistent':False,'changes':{'BAT0':[70,80]}})
        with self.assertRaises(core.Refused):core.request_valid({'token':'a'*64,'receipt':int('1'*32)},True)
    def test_managed_file_rejects_unrelated_content(self):
        for s in ('PATH=/tmp\n',core.HEADER+'STOP_CHARGE_THRESH_BAT0=80\n',core.HEADER+'START_CHARGE_THRESH_BAT0=70\nSTART_CHARGE_THRESH_BAT0=60\nSTOP_CHARGE_THRESH_BAT0=80\n'):
            with self.assertRaises(core.Refused):core.managed_values({'bytes':base64.b64encode(s.encode()).decode()})
    def test_auth_denial_is_not_success(self):
        with patch.object(client,'ready',return_value=True):
            def deny(*a,**kw):return subprocess.CompletedProcess(a,126,'','')
            r=client.invoke('apply',{'token':'a'*64,'changes':{'BAT0':[70,80]},'persistent':False},deny);self.assertFalse(r['ok']);self.assertEqual(r['state'],'rejected')
    def test_missing_dependency_does_not_spawn(self):
        with patch.object(client,'ready',return_value=False):
            def forbidden(*a,**kw):raise AssertionError('spawned')
            r=client.invoke('apply',{'token':'a'*64,'changes':{'BAT0':[70,80]},'persistent':False},forbidden);self.assertEqual(r['state'],'unavailable')
    def test_transport_timeout_unknown(self):
        with patch.object(client,'ready',return_value=True):
            def timeout(*a,**kw):raise subprocess.TimeoutExpired(['inert'],180)
            self.assertEqual(client.invoke('apply',{'token':'a'*64,'changes':{'BAT0':[70,80]},'persistent':False},timeout)['state'],'unverified')
    def test_timeout_wait_never_signals_elevated_child(self):
        from unittest.mock import Mock
        child=Mock();child.wait.side_effect=subprocess.TimeoutExpired(['inert'],1)
        with patch.object(client.subprocess,'Popen',return_value=child):
            with self.assertRaises(subprocess.TimeoutExpired):client.authenticated(['inert'],timeout=1)
        child.kill.assert_not_called();child.terminate.assert_not_called();child.send_signal.assert_not_called()
    def test_transport_never_accepts_nonzero_success(self):
        with patch.object(client,'ready',return_value=True):
            def bad(*a,**kw):return subprocess.CompletedProcess(a,1,'{"ok":true,"state":"verified"}','')
            self.assertFalse(client.invoke('apply',{'token':'a'*64,'changes':{'BAT0':[70,80]},'persistent':False},bad)['ok'])

class FilesystemAndSources(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);self.m=core.Machine(sysroot=self.root/'sys',etc=self.root/'etc',state=self.root/'state')
    def test_atomic_exact_file_bytes_modes_and_absence(self):
        image={'bytes':base64.b64encode(b'# fixture exact bytes\n').decode(),'mode':0o640,'uid':__import__('os').getuid(),'gid':__import__('os').getgid()}
        self.m.replace_config(image);self.assertEqual(self.m.config.read_bytes(),b'# fixture exact bytes\n');self.assertEqual(self.m.config.stat().st_mode&0o777,0o640);self.m.replace_config(None);self.assertFalse(self.m.config.exists())
    def test_untrusted_file_and_symlink_refused(self):
        p=self.root/'untrusted';p.write_text('test');p.chmod(0o666)
        with self.assertRaises(core.Refused):self.m.file_image(p)
        q=self.root/'link';q.symlink_to(p)
        with self.assertRaises(core.Refused):self.m.file_image(q)
    def test_actual_config_readback_requires_all_pairs(self):
        image={'bytes':base64.b64encode(core.render({'BAT0':[70,80]})).decode()}
        self.m.run=lambda *a,**k:subprocess.CompletedProcess(a,0,'99-senomyos-battery-care.conf L0002: START_CHARGE_THRESH_BAT0="70"\n99-senomyos-battery-care.conf L0003: STOP_CHARGE_THRESH_BAT0="80"\n','')
        self.assertTrue(self.m.verify_config(image));self.assertFalse(self.m.verify_config(None))
    @unittest.skipUnless(Path('/usr/share/tlp/tlp-readconfs').is_file(),'Installed TLP reader absent')
    def test_generated_dropin_with_real_tlp_parser_in_temporary_tree(self):
        reader=Path('/usr/share/tlp/tlp-readconfs').read_text()
        if __import__('hashlib').sha256(reader.encode()).hexdigest()!='ded0328f4afe0f7f3243bb1e69bdc3bcd2c5cf5e8c642ccbe982ba454c9d77af':self.skipTest('Review changed TLP parser before isolated execution')
        directory=self.root/'tlp.d';directory.mkdir();main=self.root/'tlp.conf';main.write_text('CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power\n');saved=main.read_bytes()
        defaults=self.root/'defaults.conf';defaults.write_text('TLP_ENABLE=1\nTLP_AUTO_SWITCH=2\n');rename=self.root/'rename.conf';rename.touch();deprecated=self.root/'deprecated.conf';deprecated.touch()
        mapping={'CONF_USR':main,'CONF_DIR':directory,'CONF_DEF':defaults,'CONF_REN':rename,'CONF_DPR':deprecated}
        for key,path in mapping.items():
            reader,count=__import__('re').subn(r"use constant "+key+r" => '[^']+';",'use constant '+key+" => '"+str(path)+"';",reader);self.assertEqual(count,1)
        script=self.root/'reader.pl';script.write_text(reader);(directory/'99-senomyos-battery-care.conf').write_bytes(core.render({'BAT0':[70,80],'BAT1':[60,85]}));merged=self.root/'merged.conf'
        def run():
            p=subprocess.run(['/usr/bin/perl',str(script),'--notrace','--outfile',str(merged)],capture_output=True,text=True,timeout=3,env={'PATH':'/usr/bin:/bin','LC_ALL':'C'});self.assertEqual(p.returncode,0,p.stderr);return merged.read_text()
        out=run();self.assertIn('START_CHARGE_THRESH_BAT0="70"',out);self.assertIn('STOP_CHARGE_THRESH_BAT1="85"',out);self.assertEqual(main.read_bytes(),saved)
        main.write_bytes(saved+b'STOP_CHARGE_THRESH_BAT0=95\n');self.assertIn('STOP_CHARGE_THRESH_BAT0="95"',run())
    def protected_fixture(self):
        # Real atomic files and fsync, with only ownership metadata modelled.
        import os
        def metadata(path,*args,**kwargs):
            st=list(os.lstat(path));st[4]=0;st[5]=0;return os.stat_result(st)
        return patch.object(core,'trusted'),patch.object(Path,'lstat',metadata)
    def test_real_checkpoint_commit_integrity_and_missing_commit(self):
        record={'id':'b'*32,'uid':1000,'schemaVersion':2,'checkpoint':'complete'}
        trusted,metadata=self.protected_fixture()
        with trusted,metadata:
            self.m.save(record);self.assertFalse(self.m.load(record['id'],1000)['_committed'])
            self.m.finalize(record);self.assertTrue(self.m.load(record['id'],1000)['_committed'])
            self.assertEqual((self.m.state/(record['id']+'.json')).stat().st_mode&0o777,0o600)
            p=self.m.state/(record['id']+'.json');p.write_text(json.dumps(dict(record,checkpoint='in-progress')))
            self.assertFalse(self.m.load(record['id'],1000)['_committed'])
    def test_real_receipt_directory_fsync_failure_never_commits(self):
        record={'id':'c'*32,'uid':1000,'schemaVersion':2,'checkpoint':'complete'}
        trusted,metadata=self.protected_fixture();calls=[0];fsync=core.os.fsync
        def disk_fault(fd):
            calls[0]+=1
            if calls[0]==2:raise OSError('inert final receipt directory fsync failure')
            fsync(fd)
        with trusted,metadata:
            with patch.object(core.os,'fsync',side_effect=disk_fault):
                with self.assertRaises(OSError):self.m.finalize(record)
            self.assertFalse((self.m.state/(record['id']+'.commit')).exists())
            self.assertFalse(self.m.load(record['id'],1000)['_committed'])
            self.assertFalse(list(self.m.state.glob('.checkpoint-*')))
    def test_bad_sensor_values_are_unknown(self):
        p=self.root/'sensor'
        for value in ('nan','inf','-1','garbage'):
            p.write_text(value);self.assertIsNone(core.number(p))
    def machine(self):
        # Production readout logic; all policy/provider reads are inert.
        module=self.m.sysroot/'module/thinkpad_acpi';module.mkdir(parents=True)
        for b,full,design in (('BAT0',20000000,25000000),('BAT1',40000000,50000000)):
            p=self.m.sysroot/'class/power_supply'/b;p.mkdir(parents=True)
            for n,v in {'type':'Battery','present':'1','serial_number':b+'-fixture','energy_full':full,'energy_full_design':design,'cycle_count':25,'charge_control_start_threshold':0,'charge_control_end_threshold':100}.items():(p/n).write_text(str(v))
        def run(a,**kw):
            return subprocess.CompletedProcess(a,0,'Id=tlp.service\nActiveState=active\nInvocationID=fixture\nMainPID=0\n'if a[0].endswith('systemctl')else'TLP 1.10.2','')
        self.m.run=run;self.m.bus=lambda *a:[[]];self.m.upower=lambda:('fixture-owner',{b:{'EnergyFull':full,'EnergyFullDesign':design,'ChargeCycles':25,'ChargeThresholdEnabled':False}for b,full,design in [('BAT0',22,25),('BAT1',40,50)]});self.m.configurations=lambda:({}, {},False);self.m.file_image=lambda p:None
        return self.m
    def test_dual_capacity_provenance_and_disagreement(self):
        m=self.machine();d=m.snapshot();self.assertEqual(len(d['packs']),2);p=d['packs'][0];self.assertEqual(p['healthPercent'],80);self.assertEqual(p['kernel']['fullWh'],20);self.assertEqual(p['upower']['EnergyFull'],22);self.assertTrue(p['capacityMismatch']);self.assertFalse(d['packs'][1]['capacityMismatch'])
    def test_missing_capacity_not_manufactured(self):
        m=self.machine();p=m.sysroot/'class/power_supply/BAT0';(p/'energy_full').unlink();d=m.snapshot()['packs'][0];self.assertIsNone(d['healthPercent']);self.assertIn('Unavailable',d['healthBasis'])
    def test_like_units_charge_health_fallback(self):
        m=self.machine();p=m.sysroot/'class/power_supply/BAT0';(p/'energy_full').unlink();(p/'charge_full').write_text('2000');(p/'charge_full_design').write_text('4000');d=m.snapshot()['packs'][0];self.assertEqual(d['healthPercent'],50);self.assertIn('same units',d['healthBasis'])
    def test_missing_driver_or_unknown_effective_disables_controls(self):
        m=self.machine();(m.sysroot/'module/thinkpad_acpi').rmdir();self.assertFalse(m.snapshot()['packs'][0]['supported']);(m.sysroot/'module/thinkpad_acpi').mkdir();(m.sysroot/'class/power_supply/BAT0/charge_control_end_threshold').write_text('0');self.assertFalse(m.snapshot()['packs'][0]['supported'])
    def test_upower_enabled_blocks_competing_writes(self):
        m=self.machine();original=m.upower
        def enabled():
            owner,data=original();data['BAT0']['ChargeThresholdEnabled']=True;return owner,data
        m.upower=enabled;self.assertFalse(m.snapshot()['packs'][0]['supported'])
    def test_unrecognised_serial_disables_control(self):
        m=self.machine();(m.sysroot/'class/power_supply/BAT0/serial_number').unlink();self.assertFalse(m.snapshot()['packs'][0]['supported'])

if __name__=='__main__':unittest.main(verbosity=2)
