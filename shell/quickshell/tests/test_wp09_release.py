"""All writes, dependency fixtures and transaction failures are isolated."""
import gzip
import hashlib
import importlib.util
import io
import json
import os
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'scripts'))
import senomy_release as release


def module(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'scripts'/('senomy-'+name+'.py'))
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
prefs=module('preferences');maintenance=module('maintenance');snapshot=module('release-snapshot')


class Releases(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.engine=release.Releases(self.root/'store');self.engine.roots={'bin':self.root/'bin','units':self.root/'units','data':self.root/'data'};self.engine.selector=self.root/'config/shell.json'
        self.dep=patch.object(self.engine,'dependencies',return_value={'missing_required_commands':[],'missing_required_packages':[],'missing_optional_commands':['optional-tool']});self.dep.start();self.addCleanup(self.dep.stop)

    def candidate(self,version='one',wrapped=False):
        path=self.root/version;path.mkdir()
        files={'scripts/run':version.encode(),'deploy/release.json':json.dumps({'schema_version':1,'bindings':[{'root':'bin','source':'scripts/run','path':'run'}]}).encode()}
        files['deploy/manifest.json']=json.dumps({'components':[{'entries':[{'source':'scripts/run','target':{'root':'user_bin','path':'run'},'strategy':'replace','mode':'0755'}]}]}).encode()
        files.update({p:b'{}' for p in ['shell/quickshell/shell.qml','scripts/senomy-quickshell-run','scripts/senomy_app_launch.py','deploy/packages.json','appearance/tokens.json']})
        files['appearance/skins/default.json']=b'{"schemaVersion":1,"persona":{"railTextPx":12}}'
        if wrapped:
            files['libexec/entries/run']=('wrapped '+version).encode()
            spec=json.loads(files['deploy/release.json']);spec['bindings'][0]['entrypoint']='libexec/entries/run';files['deploy/release.json']=json.dumps(spec).encode()
        manifest={'schema_version':2,'files':[{'path':p,'sha256':release.digest(b),'bytes':len(b),'mode':'0755' if p in ('scripts/run','libexec/entries/run') else '0644'} for p,b in sorted(files.items())]}
        (path/'release.json').write_text(json.dumps(manifest))
        with tarfile.open(path/'source.tar.gz','w:gz') as archive:
            for entry in manifest['files']:
                item=tarfile.TarInfo('senomyos/'+entry['path']);data=files[entry['path']];item.size=len(data);item.mode=int(entry['mode'],8);archive.addfile(item,io.BytesIO(data))
        (path/'SHA256SUMS').write_text(''.join(release.digest((path/n).read_bytes())+'  '+n+'\n' for n in ['source.tar.gz','release.json']))
        return path

    def install(self,version='one',wrapped=False):return self.engine.install(self.candidate(version,wrapped))['release']

    def test_clean_upgrade_and_exact_rollback(self):
        first=self.install();r=self.engine.activate(first)
        self.assertEqual((self.root/'bin/run').read_text(),'one')
        self.assertEqual(self.engine.status()['state'],'selected-integrity-verified')
        second=self.install('two');r2=self.engine.activate(second)
        self.assertEqual((self.root/'bin/run').read_text(),'two')
        self.engine.restore(Path(r2['receipt']));self.assertEqual((self.root/'bin/run').read_text(),'one')
        self.engine.restore(Path(r['receipt']));self.assertFalse((self.root/'bin/run').exists());self.assertFalse(self.engine.selector.exists())

    def test_old_release_to_pinned_entries_upgrade_and_exact_rollback(self):
        first=self.install();self.engine.activate(first)
        personal=self.root/'bin/personal';personal.write_text('keep')
        second=self.install('two',wrapped=True);plan=self.engine.plan(second)
        self.assertTrue(plan['items'][0]['after']['target'].endswith('/libexec/entries/run'))
        switched=self.engine.activate(second);self.assertEqual((self.root/'bin/run').read_text(),'wrapped two')
        self.engine.restore(Path(switched['receipt']));self.assertEqual((self.root/'bin/run').read_text(),'one')
        self.assertEqual(personal.read_text(),'keep');self.assertEqual(self.engine.status()['state'],'selected-integrity-verified')

    def test_legacy_owned_link_and_regular_file_preserved(self):
        legacy=self.root/'legacy';(legacy/'scripts').mkdir(parents=True);old=legacy/'scripts/run';old.write_text('legacy');old.chmod(0o755)
        (self.root/'bin').mkdir();link=self.root/'bin/run';link.symlink_to(old)
        rid=self.install();plan=self.engine.plan(rid,legacy);self.assertEqual(plan['items'][0]['before']['target'],str(old))
        r=self.engine.activate(rid,legacy);self.engine.restore(Path(r['receipt']));self.assertEqual(os.readlink(link),str(old))
        link.unlink();link.write_text('legacy');link.chmod(0o755)
        r=self.engine.activate(rid,legacy);self.engine.restore(Path(r['receipt']));self.assertFalse(link.is_symlink());self.assertEqual(link.read_text(),'legacy')

    def test_verified_prior_component_source_proves_legacy_copy_without_broad_adoption(self):
        prior=self.install('one');new=self.install('two')
        legacy=self.root/'legacy';(legacy/'scripts').mkdir(parents=True);(legacy/'scripts/run').write_text('two');(legacy/'scripts/run').chmod(0o755)
        (self.root/'bin').mkdir();target=self.root/'bin/run';target.write_text('one');target.chmod(0o755)
        with self.assertRaises(ValueError):self.engine.plan(new,legacy)
        receipt=self.engine.activate(new,legacy,legacy_release=prior)
        self.engine.restore(Path(receipt['receipt']));self.assertEqual(target.read_text(),'one')
        target.write_text('user edit')
        with self.assertRaises(ValueError):self.engine.plan(new,legacy,legacy_release=prior)

    def test_owned_legacy_receipt_allows_reviewed_previous_adapter(self):
        rid=self.install();legacy=self.root/'legacy';legacy.mkdir()
        (self.root/'bin').mkdir();target=self.root/'bin/run';target.write_text('prior deployment');target.chmod(0o644)
        receipt=self.root/'legacy-receipt.json';release.write_json(receipt,{'status':'applied','entries':[{'strategy':'replace','target':{'root':'user_bin','path':'run'},'source':'scripts/run','source_hash':release.digest(target.read_bytes()),'mode':'644'}]})
        with self.assertRaises(ValueError):self.engine.plan(rid,legacy)
        r=self.engine.activate(rid,legacy,[receipt]);self.engine.restore(Path(r['receipt']))
        self.assertEqual(target.read_text(),'prior deployment');self.assertFalse(target.is_symlink())

    def test_changed_legacy_preferences_block_activation_before_writes(self):
        rid=self.install();legacy=self.root/'legacy';(legacy/'appearance/skins').mkdir(parents=True)
        (legacy/'appearance/tokens.json').write_text('{"skin":{"manifest":"skins/default.json"}}')
        (legacy/'appearance/skins/default.json').write_text('{"persona":{"railTextPx":15}}')
        self.assertTrue(self.engine.plan(rid,legacy)['preferences']['migration_required'])
        with self.assertRaises(ValueError):self.engine.activate(rid,legacy)
        self.assertIsNone(self.engine.current());self.assertFalse((self.root/'bin').exists())
        release.write_json(self.engine.selector.parent/'appearance.json',{'schemaVersion':1,'persona':{'railTextPx':15}})
        self.assertFalse(self.engine.plan(rid,legacy)['preferences']['migration_required'])

    def test_unmanaged_and_linked_ancestor_refused(self):
        rid=self.install();(self.root/'elsewhere').mkdir();(self.root/'bin').symlink_to(self.root/'elsewhere')
        with self.assertRaises(ValueError):self.engine.plan(rid)

    def test_dangling_target_and_unknown_file_refused(self):
        rid=self.install();(self.root/'bin').mkdir();p=self.root/'bin/run';p.symlink_to('/unrelated/missing')
        with self.assertRaises(ValueError):self.engine.plan(rid)
        p.unlink();p.write_text('mine')
        with self.assertRaises(ValueError):self.engine.plan(rid)

    def test_payload_integrity_and_mode_drift_refused(self):
        rid=self.install();p=self.engine.store/'versions'/rid/'payload/scripts/run';p.chmod(0o755)
        with self.assertRaises(ValueError):self.engine.installed(rid)
        p.write_text('drift');p.chmod(0o555)
        with self.assertRaises(ValueError):self.engine.installed(rid)

    def test_postactivation_binding_drift_blocks_rollback(self):
        rid=self.install();r=self.engine.activate(rid);p=self.root/'bin/run';p.unlink();p.symlink_to('/external')
        with self.assertRaises(ValueError):self.engine.restore(Path(r['receipt']))
        with self.assertRaises(ValueError):self.engine.status()

    def test_missing_dependencies_do_not_change_targets(self):
        rid=self.install();self.engine.dependencies.return_value={'missing_required_commands':['qs'],'missing_required_packages':[]}
        with self.assertRaises(ValueError):self.engine.activate(rid)
        self.assertIsNone(self.engine.current());self.assertFalse(self.engine.selector.exists())

    def test_mid_activation_exception_rolls_back(self):
        rid=self.install();put=self.engine.put;calls=0
        def fail_once(path,image):
            nonlocal calls
            calls+=1
            if calls==2:raise OSError('interrupted')
            return put(path,image)
        with patch.object(self.engine,'put',side_effect=fail_once):
            with self.assertRaises(OSError):self.engine.activate(rid)
        self.assertIsNone(self.engine.current());self.assertFalse((self.root/'bin/run').exists());self.assertEqual(self.engine.pending(),[])

    def test_power_loss_journal_recovery(self):
        rid=self.install();plan=self.engine.plan(rid);plan.update(state='prepared',store=str(self.engine.store));receipt=self.engine.store/'transactions/interrupted.json';release.write_json(receipt,plan)
        self.engine.put(Path(plan['items'][0]['target']),plan['items'][0]['after'])
        with self.assertRaises(ValueError):self.engine.activate(rid)
        self.engine.restore(receipt);self.assertFalse((self.root/'bin/run').exists())

    def test_bootstrap_provenance_cannot_be_changed_by_rewriting_checksums(self):
        path=self.candidate();value=json.loads((path/'release.json').read_text());value['installer_files']=['senomy-release-snapshot.py','senomy_release.py']
        for name in value['installer_files']:
            data=b'reviewed installer';(path/name).write_bytes(data);value['files'].append({'path':'scripts/'+name,'sha256':release.digest(data),'bytes':len(data),'mode':'0644'})
        (path/'release.json').write_text(json.dumps(value));(path/'senomy_release.py').write_bytes(b'changed installer')
        (path/'SHA256SUMS').write_text(''.join(release.digest((path/n).read_bytes())+'  '+n+'\n' for n in ['source.tar.gz','release.json',*value['installer_files']]))
        with self.assertRaises(ValueError):release.candidate(path)

    def test_archive_path_traversal_and_checksum_refused(self):
        path=self.candidate();(path/'SHA256SUMS').write_text('invalid')
        with self.assertRaises(ValueError):self.engine.install(path)
        path=self.candidate('bad')
        with tarfile.open(path/'source.tar.gz','w:gz') as archive:
            item=tarfile.TarInfo('senomyos/../../escape');item.size=1;archive.addfile(item,io.BytesIO(b'x'))
        (path/'SHA256SUMS').write_text(''.join(release.digest((path/n).read_bytes())+'  '+n+'\n' for n in ['source.tar.gz','release.json']))
        with self.assertRaises(ValueError):self.engine.install(path)
        self.assertFalse((self.root/'escape').exists())


class PreparedEntries(unittest.TestCase):
    def test_inherited_checkout_root_is_replaced_and_arguments_are_literal(self):
        with tempfile.TemporaryDirectory(prefix='senomy payload ') as d:
            root=Path(d)/'payload';(root/'scripts').mkdir(parents=True);(root/'deploy').mkdir()
            run=root/'scripts/run';run.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$SENOMY_SOURCE_ROOT" "$SENOMY_SESSION_ACTION" "$@"\n');run.chmod(0o755)
            (root/'scripts/model.py').write_text('VALUE=1\n');(root/'scripts/model.py').chmod(0o755)
            spec={'schema_version':1,'bindings':[{'root':'bin','path':'run','source':'scripts/run'},{'root':'bin','path':'model.py','source':'scripts/model.py'}]}
            (root/'deploy/release.json').write_text(json.dumps(spec))
            original=snapshot.inventory(root);files,data=snapshot.prepared_payload(original,root)
            transformed=json.loads(data['deploy/release.json'])
            self.assertEqual(transformed['bindings'][0]['source'],'scripts/run')
            self.assertNotIn('entrypoint',transformed['bindings'][1])
            entry=root/transformed['bindings'][0]['entrypoint'];entry.parent.mkdir(parents=True);entry.write_bytes(data[str(entry.relative_to(root))]);entry.chmod(0o755)
            result=__import__('subprocess').run([str(entry),'literal $(not-executed); spaces'],env={**os.environ,'SENOMY_SOURCE_ROOT':'/missing/checkout','SENOMY_SESSION_ACTION':'/missing/action'},cwd=d,capture_output=True,text=True,check=True)
            self.assertEqual(result.stdout.splitlines(),[str(root),str(root/'scripts/senomy-session-action'),'literal $(not-executed); spaces'])
            self.assertTrue(next(e for e in files if e['path']=='libexec/entries/run')['generated'])
            self.assertIn('source_sha256',next(e for e in files if e['path']=='deploy/release.json'))

    def test_release_wallpaper_default_user_precedence_and_link_refusal(self):
        import shutil,subprocess
        with tempfile.TemporaryDirectory() as d:
            temp=Path(d);payload=temp/'payload';scripts=payload/'components/desktop/scripts';scripts.mkdir(parents=True)
            owner=scripts/'senomy-wallpaper';shutil.copy2(ROOT/'components/desktop/scripts/senomy-wallpaper',owner)
            default=payload/'appearance/shared/backgrounds/desktop.png';default.parent.mkdir(parents=True);default.write_bytes(b'fixture')
            commands=temp/'bin';commands.mkdir();renderer=commands/'renderer';renderer.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@"\n');renderer.chmod(0o755)
            python=commands/'python3';shutil.copy2(renderer,python)
            home=temp/'home';home.mkdir();data=home/'data';user=data/'senomyos/appearance/backgrounds/desktop.png'
            env={**os.environ,'HOME':str(home),'XDG_CONFIG_HOME':str(home/'config'),'XDG_DATA_HOME':str(data),'SENOMY_SOURCE_ROOT':str(payload),'SENOMY_SWAYBG_BIN':str(renderer),'PATH':str(commands)+':/usr/bin'}
            first=subprocess.run([str(owner),'--once'],env=env,capture_output=True,text=True,check=True);self.assertEqual(first.stdout.splitlines()[-1],str(default))
            watcher=subprocess.run([str(owner)],env=env,capture_output=True,text=True,check=True);self.assertEqual(watcher.stdout.splitlines()[0],str(scripts/'senomy-wallpaper-watch.py'))
            user.parent.mkdir(parents=True);user.write_bytes(b'user artwork')
            second=subprocess.run([str(owner),'--once'],env=env,capture_output=True,text=True,check=True);self.assertEqual(second.stdout.splitlines()[-1],str(user));self.assertEqual(user.read_bytes(),b'user artwork')
            user.unlink();user.symlink_to(temp/'missing')
            rejected=subprocess.run([str(owner),'--once'],env=env,capture_output=True,text=True);self.assertNotEqual(rejected.returncode,0);self.assertTrue(user.is_symlink())

    def test_changed_source_during_preparation_refused(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);(root/'scripts').mkdir();p=root/'scripts/run';p.write_text('old');entries=snapshot.inventory(root);p.write_text('new')
            with self.assertRaises(ValueError):snapshot.prepared_payload(entries,root)


class Preferences(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.path=Path(self.temp.name)/'config/appearance.json'
        self.base={'schemaVersion':1,'frames':{},'defaultMode':'native','backgrounds':{'calendar':{'source':'../art.png','scaling':'fit'},'tray':{'source':'tray.png'}},'persona':{'railTextPx':12},'unrelated':{'art':'keep'}}

    def test_read_only_payload_save_and_reset(self):
        r=prefs.execute('read',self.base,self.path,{});self.assertFalse(self.path.exists())
        r=prefs.execute('save',self.base,self.path,{'expected':r['version'],'key':'calendar','background':{'imageOpacity':.5},'persona':{'reducedMotion':True}})
        self.assertEqual(r['registry']['backgrounds']['calendar']['source'],'../art.png');self.assertEqual(r['registry']['unrelated']['art'],'keep')
        self.assertNotIn('frames',json.loads(self.path.read_text()));self.assertEqual(self.path.stat().st_mode&0o777,0o600)
        r=prefs.execute('reset',self.base,self.path,{'expected':r['version']});self.assertNotIn('reducedMotion',r['registry']['persona'])

    def test_concurrent_writer_refused(self):
        first=prefs.execute('read',self.base,self.path,{})
        prefs.execute('save',self.base,self.path,{'expected':'absent','key':'tray','background':{},'persona':{'railTextPx':14}})
        with self.assertRaises(ValueError):prefs.execute('save',self.base,self.path,{'expected':first['version'],'key':'calendar','background':{},'persona':{}})
        self.assertEqual(json.loads(self.path.read_text())['persona']['railTextPx'],14)

    def test_malformed_schema_unknown_surface_and_invalid_values(self):
        for value in [{'schemaVersion':1,'persona':{'backgrounds':{'bad':{'color':'invalid'}}}},{'schemaVersion':99},{'schemaVersion':1,'persona':{'uiTextScale':20}},{'schemaVersion':1,'backgrounds':{'missing':{}}}]:
            self.path.parent.mkdir(exist_ok=True);self.path.write_text(json.dumps(value))
            with self.assertRaises(ValueError):prefs.execute('read',self.base,self.path,{})
        self.path.write_text('{bad')
        with self.assertRaises(ValueError):prefs.execute('read',self.base,self.path,{})
        before=self.path.read_bytes();r=prefs.execute('reset',self.base,self.path,{'expected':release.digest(before)})
        self.assertEqual(self.path.with_name('appearance-reset-'+release.digest(before)+'.json').read_bytes(),before);self.assertTrue(r['ok'])

    def test_migration_preserves_existing_values_and_unrelated_keys(self):
        self.path.parent.mkdir();self.path.write_text(json.dumps({'schemaVersion':1,'persona':{'railTextPx':15},'unrelated':{'keep':True}}))
        legacy=self.path.parent/'legacy.json';legacy.write_text(json.dumps(self.base));r=prefs.execute('read',self.base,self.path,{})
        r=prefs.execute('migrate',self.base,self.path,{'expected':r['version'],'legacy':str(legacy)})
        self.assertEqual(r['registry']['persona']['railTextPx'],15);self.assertTrue(json.loads(self.path.read_text())['unrelated']['keep'])
        self.assertEqual(json.loads(legacy.read_text()),self.base)

    def test_symlink_save_refused(self):
        self.path.parent.mkdir();self.path.symlink_to(self.path.parent/'other')
        with self.assertRaises(ValueError):prefs.execute('save',self.base,self.path,{'expected':'absent'})


class Maintenance(unittest.TestCase):
    def test_no_noninteractive_update(self):
        with patch.object(sys,'stdin') as stdin,patch.object(maintenance.subprocess,'call') as call:
            stdin.isatty.return_value=False
            with self.assertRaises(ValueError):maintenance.run_terminal()
            call.assert_not_called()

    def test_dead_terminal_is_interrupted_and_no_false_reboot_claim(self):
        with tempfile.TemporaryDirectory() as d,patch.object(maintenance,'STATE',Path(d)),patch.object(maintenance,'reboot',return_value={'state':'unknown'}):
            release.write_json(Path(d)/'last.json',{'state':'running','pid':99999999,'identity':'gone'})
            r=maintenance.status();self.assertEqual(r['packages']['state'],'interrupted');self.assertEqual(r['reboot']['state'],'unknown')

    def test_denied_cancelled_and_successful_results(self):
        for answer,code,expected in [('no',None,'cancelled'),('UPGRADE OFFICIAL PACKAGES',1,'failed'),('UPGRADE OFFICIAL PACKAGES',0,'package-tool-succeeded')]:
            with tempfile.TemporaryDirectory() as d,patch.object(maintenance,'STATE',Path(d)),patch.object(sys,'stdin') as stdin,patch.object(sys,'stdout') as stdout,patch('builtins.input',return_value=answer),patch.object(maintenance.subprocess,'call',return_value=code) as call:
                stdin.isatty.return_value=stdout.isatty.return_value=True
                maintenance.run_terminal();self.assertEqual(json.loads((Path(d)/'last.json').read_text())['state'],expected)
                if code is None:call.assert_not_called()
                else:call.assert_called_once_with(['/usr/bin/sudo','/usr/bin/pacman','-Syu'])

if __name__=='__main__':unittest.main()
