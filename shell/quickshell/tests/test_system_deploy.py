#!/usr/bin/env python3
"""Production deployer functions; targets and privilege metadata confined to a temporary fixture.

No sudo/root, system target, daemon or privileged helper execution. The stat and
install facades model root ownership without changing real host ownership.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[3]
SOURCE=(ROOT/'scripts/senomy-system-deploy.sh').read_text()
NAMES=('validate_relative_path','literal_path','protected_parents','resolve_target',
       'file_identity','rollback_entry_state','file_hash','resolve_source',
       'system_root_mode','ensure_system_root','write_json_atomic','install_from_receipt','restore_receipt')
def function(name):
    start=SOURCE.index(name+'() {');return SOURCE[start:SOURCE.index('\n}\n',start)+3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def identity(p):
    s=p.stat();return f'{s.st_dev}:{s.st_ino}:{s.st_uid}:{s.st_gid}:{s.st_mode&0o777:o}:{s.st_nlink}'

class SystemDeployment(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='senomy-deploy-regression-');self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.dest=self.root/'libexec';self.dest.mkdir();self.target=self.dest/'senomy-battery-care'
        self.source=self.root/'helper.py';self.source.write_bytes(b'# inert helper payload; never executed\n')
        self.receipt=self.root/'receipt.json';self.script=self.root/'fixture.sh'
        self.script.write_text('''#!/usr/bin/env bash
set -euo pipefail
fail(){ printf '%s\\n' "$*" >&2; exit 1; }
system_root(){ [[ "$1" == local_libexec ]] || return 1; printf '%s\\n' "$FIXTURE_ROOT/libexec"; }
# Metadata-only ownership facade. Inode/mode/link count/content remain real.
stat(){
  if [[ "$1" == -c ]]; then
    case "$2" in
      %u:%g) printf '%s\\n' "${FIXTURE_OWNER:-0:0}"; return ;;
      %U:%G) printf 'root:root\\n'; return ;;
      %a) if [[ "${@: -1}" == /tmp ]]; then printf '755\\n'; return; fi ;;
    esac
  fi
  /usr/bin/stat "$@"
}
install(){
  local -a args=()
  while (($#)); do
    case "$1" in -o|-g) shift 2 ;; *) args+=("$1");shift ;; esac
  done
  /usr/bin/install "${args[@]}"
}
REPO_ROOT="$FIXTURE_ROOT"
'''+ '\n'.join(function(n) for n in NAMES)+'''
case "$1" in
 install) install_from_receipt "$FIXTURE_ROOT/receipt.json" ;;
 rollback) restore_receipt "$FIXTURE_ROOT/receipt.json" "${2:-true}" ;;
 resolve) resolve_target local_libexec "$2" ;;
esac
''')
    def prepare(self,existing=False):
        before=None;mode=None;backup=None;bi=None
        if existing:
            self.target.write_bytes(b'prior exact file\n');self.target.chmod(0o640);before=sha(self.target);mode='640';bi=identity(self.target)
            d=self.root/'backups';d.mkdir();backup='backups/care';shutil.copy2(self.target,self.root/backup)
        item={'id':'care','source':'helper.py','source_hash':sha(self.source),'target':{'root':'local_libexec','path':'senomy-battery-care'},'mode':'0755','existed':existing,'before_hash':before,'before_mode':mode,'before_identity':bi,'installed_identity':None,'backup':backup}
        self.receipt.write_text(json.dumps({'entries':[item]}))
    def run_fixture(self,*args,owner='0:0'):
        return subprocess.run(['/bin/bash',str(self.script),*args],env={'PATH':'/usr/bin:/bin','LC_ALL':'C','FIXTURE_ROOT':str(self.root),'FIXTURE_OWNER':owner},capture_output=True,text=True,timeout=10)
    def installed(self,existing=False):
        self.prepare(existing);r=self.run_fixture('install');self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual(self.target.read_bytes(),self.source.read_bytes());self.assertEqual(self.target.stat().st_mode&0o777,0o755)
        self.assertEqual(json.loads(self.receipt.read_text())['entries'][0]['installed_identity'],identity(self.target))
    def test_normal_create_install_and_exact_rollback(self):
        self.installed();r=self.run_fixture('rollback');self.assertEqual(r.returncode,0,r.stderr);self.assertFalse(self.target.exists());self.assertTrue(self.source.exists())
    def test_normal_update_restores_bytes_and_mode(self):
        self.installed(True);r=self.run_fixture('rollback');self.assertEqual(r.returncode,0,r.stderr);self.assertEqual(self.target.read_bytes(),b'prior exact file\n');self.assertEqual(self.target.stat().st_mode&0o777,0o640)
    def test_HG03_original_symlink_to_identical_copy_is_refused(self):
        self.installed();other=self.dest/'other-copy';self.target.rename(other);self.target.symlink_to(other.name)
        for guard in ('true','false'):
            r=self.run_fixture('rollback',guard);self.assertNotEqual(r.returncode,0);self.assertTrue(self.target.is_symlink());self.assertEqual(other.read_bytes(),self.source.read_bytes())
    def test_symlink_in_parent_refused(self):
        self.installed();other=self.root/'actual-libexec';self.dest.rename(other);self.dest.symlink_to(other.name)
        self.assertNotEqual(self.run_fixture('rollback').returncode,0);self.assertTrue((other/self.target.name).is_file())
    def test_byte_identical_regular_replacement_refused(self):
        self.installed();self.target.rename(self.dest/'original-inode');self.target.write_bytes(self.source.read_bytes());self.target.chmod(0o755)
        self.assertNotEqual(self.run_fixture('rollback').returncode,0);self.assertTrue(self.target.is_file())
    def test_content_and_mode_drift_refused(self):
        self.installed();self.target.chmod(0o600);self.assertNotEqual(self.run_fixture('rollback').returncode,0)
        self.target.chmod(0o755);self.target.write_bytes(b'drift');self.assertNotEqual(self.run_fixture('rollback').returncode,0);self.assertEqual(self.target.read_bytes(),b'drift')
    def test_legacy_receipt_without_identity_refused(self):
        self.installed();v=json.loads(self.receipt.read_text());v['entries'][0].pop('installed_identity');self.receipt.write_text(json.dumps(v))
        self.assertNotEqual(self.run_fixture('rollback').returncode,0);self.assertTrue(self.target.exists())
    def test_untrusted_owner_refused(self):
        self.installed();self.assertNotEqual(self.run_fixture('rollback',owner='1001:1001').returncode,0);self.assertTrue(self.target.exists())
    def test_unsafe_relative_aliases_refused(self):
        for path in ('../other','./helper','sub/../helper','sub//helper','helper/','/etc/passwd'):
            self.assertNotEqual(self.run_fixture('resolve',path).returncode,0,path)
    def test_backup_symlink_refused_before_touching_target(self):
        self.installed(True);backup=self.root/'backups/care';other=self.root/'other-backup';backup.rename(other);backup.symlink_to(other)
        self.assertNotEqual(self.run_fixture('rollback').returncode,0);self.assertEqual(self.target.read_bytes(),self.source.read_bytes());self.assertTrue(other.is_file())

if __name__=='__main__':unittest.main(verbosity=2)
