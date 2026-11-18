from pathlib import Path
import importlib.util
import json
import os
import subprocess
import sys
import time
import tempfile
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('locks',Path(__file__).parents[1]/'scripts/osk-lock-state.py');locks=importlib.util.module_from_spec(spec);spec.loader.exec_module(locks)
class Locks(unittest.TestCase):
    def test_state_rejects_unknown_or_malformed_lock_data(self):
        for value in ('[]','{}','not json','{"ok":true,"available":true,"capsLock":"text"}'):
            with patch.object(locks,'request',return_value=value):self.assertEqual(locks.state(),{'ok':False,'available':False})
        with patch.object(locks,'request',return_value='{"ok":true,"available":true,"capsLock":false,"extra":"discard"}'):
            self.assertEqual(locks.state(),{'ok':True,'available':True,'capsLock':False})
    def test_request_and_runtime_boundaries_reject_untrusted_commands(self):
        with self.assertRaises(ValueError):locks.request('arbitrary-command')
        with patch.dict(os.environ,{'HYPRLAND_INSTANCE_SIGNATURE':'../foreign','XDG_RUNTIME_DIR':'/tmp'}):
            with self.assertRaises(OSError):locks.directory()
    def test_bridge_ends_when_its_disposable_owner_dies(self):
        # Real Linux parent-death signal; only two disposable Python processes.
        code="import importlib.util,time; s=importlib.util.spec_from_file_location('locks',"+repr(str(Path(__file__).parents[1]/'scripts/osk-lock-state.py'))+"); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); m.arm_owned_child(); print('ready',flush=True); time.sleep(30)"
        parent_code="import subprocess,sys,time; p=subprocess.Popen([sys.executable,'-c',"+repr(code)+"],stdout=subprocess.PIPE,text=True); assert p.stdout.readline().strip()=='ready'; print(p.pid,flush=True); time.sleep(30)"
        owner=subprocess.Popen([sys.executable,'-c',parent_code],stdout=subprocess.PIPE,text=True)
        child=None;child_identity=None
        try:
            child=int(owner.stdout.readline());child_identity=Path('/proc',str(child),'stat').read_text().rsplit(')',1)[1].split()[19];owner.terminate();owner.wait(timeout=3)
            for _ in range(50):
                path=Path('/proc',str(child),'status')
                if not path.exists() or '\nState:\tZ' in path.read_text():break
                time.sleep(.02)
            else:self.fail('Caps bridge survived owner death')
        finally:
            if owner.poll() is None:owner.terminate();owner.wait(timeout=3)
            owner.stdout.close()
            if child is not None:
                try:
                    if Path('/proc',str(child),'stat').read_text().rsplit(')',1)[1].split()[19]==child_identity:os.kill(child,15)
                except (FileNotFoundError,ProcessLookupError):pass
    def test_component_must_match_running_compositor_and_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);p=root/'.local/lib/senomyos/osk/caps-sync.so';p.parent.mkdir(parents=True);p.write_bytes(b'fixture')
            p.with_suffix('.json').write_text(json.dumps({'commit':'a'*40,'sha256':locks.hashlib.sha256(p.read_bytes()).hexdigest()}))
            with patch.object(locks.Path,'home',return_value=root),patch.object(locks,'state',side_effect=[{'ok':False},{'ok':True}]),patch.object(locks,'request',side_effect=[json.dumps({'commit':'a'*40}),'ok']) as request:
                self.assertTrue(locks.ensure_plugin());self.assertEqual(request.call_args_list[-1].args,('plugin load '+str(p),))
            with patch.object(locks.Path,'home',return_value=root),patch.object(locks,'state',return_value={'ok':False}),patch.object(locks,'request',return_value=json.dumps({'commit':'b'*40})) as request:
                self.assertFalse(locks.ensure_plugin());self.assertEqual(request.call_count,1)
            p.write_bytes(b'changed')
            with patch.object(locks.Path,'home',return_value=root),patch.object(locks,'state',return_value={'ok':False}),patch.object(locks,'request',return_value=json.dumps({'commit':'a'*40})) as request:
                self.assertFalse(locks.ensure_plugin());self.assertEqual(request.call_count,1)
if __name__=='__main__':unittest.main()
