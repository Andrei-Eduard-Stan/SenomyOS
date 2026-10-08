#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('desktop',Path(__file__).resolve().parents[1]/'scripts/desktop-settings.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class App:
    def __init__(self,id,path,registry):self.id=id;self.path=path;self.registry=registry
    def get_id(self):return self.id
    def get_name(self):return 'Fixture '+self.id
    def get_filename(self):return str(self.path)
    def get_is_hidden(self):return False
    def set_as_default_for_type(self,mime):self.registry.current[mime]=self;self.registry.calls.append((mime,self.id));return True
class Registry:
    def __init__(self):self.current={};self.apps={};self.calls=[]
    def get_default_for_type(self,mime,required):return self.current.get(mime)
    def get_all_for_type(self,mime):return list(self.apps.values())
    def get_all(self):return list(self.apps.values())
    def new(self,id):return self.apps.get(id)
class Container:
    pass
class Desktop(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
        self.user=self.root/'config';self.system=self.root/'system';self.state=self.root/'state';self.apps=self.root/'apps';self.apps.mkdir()
        env=patch.dict(os.environ,{'XDG_CONFIG_HOME':str(self.user),'XDG_CONFIG_DIRS':str(self.system),'XDG_STATE_HOME':str(self.state),'XDG_CURRENT_DESKTOP':'Hyprland'})
        env.start();self.addCleanup(env.stop)
        self.registry=Registry();gio=Container();gio.AppInfo=self.registry
        for id in ['one.desktop','two.desktop']:
            path=self.apps/id;path.write_text('[Desktop Entry]\nType=Application\nName=Fixture\nExec=/usr/bin/true %f\nMimeType=text/plain;\n# preserve comment\n')
            self.registry.apps[id]=App(id,path,self.registry)
        self.registry.current['text/plain']=self.registry.apps['one.desktop']
        for name,value in [('Gio',gio),('DesktopAppInfo',self.registry)]:
            p=patch.object(m,name,value);p.start();self.addCleanup(p.stop)
    def role(self):return next(item for item in m.defaults()['items'] if item['mime']=='text/plain')
    def entry(self,name='fixture.desktop',content=None):
        directory=self.system/'autostart';directory.mkdir(parents=True,exist_ok=True);path=directory/name
        path.write_text(content or '[Desktop Entry]\nType=Application\nName=Fixture\nExec=/usr/bin/true %f\nOnlyShowIn=Hyprland;\n# preserve comment\n[Other]\nKey=value\n');return path
    def test_defaults_registered_options_and_no_launch(self):
        role=self.role();self.assertEqual(role['current'],'one.desktop');self.assertEqual(len(role['options']),2);self.assertEqual(self.registry.calls,[])
        self.assertNotIn('Exec',json.dumps(role));self.assertEqual(len(m.defaults()['items']),6)
    def test_reviewed_default_and_stale_metadata(self):
        token=self.role()['token'];self.assertEqual(m.set_default('text/plain','two.desktop',token)['state'],'succeeded');self.assertEqual(self.registry.calls,[('text/plain','two.desktop')])
        with self.assertRaises(ValueError):m.set_default('text/plain','one.desktop',token)
        with self.assertRaises(ValueError):m.set_default('unrestricted','one.desktop',self.role()['token'])
    def test_changed_registration_or_foreign_app_rejected(self):
        token=self.role()['token'];self.registry.apps['two.desktop'].path.write_text('[Desktop Entry]\nType=Application\nName=Changed\nExec=/usr/bin/false\n')
        with self.assertRaises(ValueError):m.set_default('text/plain','two.desktop',token)
        with self.assertRaises(ValueError):m.set_default('text/plain','evil;id',self.role()['token'])
        self.assertEqual(self.registry.calls,[])
    def test_missing_registry_graceful(self):
        with patch.object(m,'Gio',None):self.assertFalse(m.defaults()['available'])
    def test_system_override_preserves_original_and_other_groups(self):
        system=self.entry();before=system.read_text();item=m.autostart()[0]
        result=m.set_autostart(item['id'],'no',item['token']);self.assertEqual(result['state'],'succeeded');self.assertEqual(system.read_text(),before)
        override=self.user/'autostart/fixture.desktop';text=override.read_text();self.assertIn('# preserve comment',text);self.assertIn('[Other]\nKey=value',text);self.assertIn('Hidden=true\n[Other]',text)
        self.assertFalse(m.autostart()[0]['enabled']);self.assertEqual(override.stat().st_mode&0o777,0o600)
    def test_user_backup_before_update(self):
        self.entry();item=m.autostart()[0];m.set_autostart(item['id'],'no',item['token']);before=(self.user/'autostart/fixture.desktop').read_text()
        item=m.autostart()[0];m.set_autostart(item['id'],'yes',item['token']);backups=list((self.state/'senomyos/autostart-backups').glob('*.desktop'))
        self.assertEqual(len(backups),1);self.assertEqual(backups[0].read_text(),before);self.assertEqual(backups[0].stat().st_mode&0o777,0o600)
    def test_protected_stale_and_symlink_entries(self):
        path=self.entry('nm-applet.desktop');item=m.autostart()[0];self.assertTrue(item['protected'])
        with self.assertRaises(ValueError):m.set_autostart(item['id'],'no',item['token'])
        path=self.entry();item=next(x for x in m.autostart() if x['id']=='fixture.desktop');path.write_text(path.read_text()+'# changed\n')
        with self.assertRaises(ValueError):m.set_autostart(item['id'],'no',item['token'])
        link=path.parent/'link.desktop';link.symlink_to(path);self.assertFalse(any(x['id']=='link.desktop' for x in m.autostart()))
    def test_metadata_eligibility_not_runtime_and_tryexec(self):
        self.entry(content='[Desktop Entry]\nType=Application\nName=Fixture\nExec=/usr/bin/true\nOnlyShowIn=GNOME;\n')
        self.assertFalse(m.autostart()[0]['eligible']);self.assertNotIn('running',m.autostart()[0])
        self.entry(content='[Desktop Entry]\nType=Application\nName=Fixture\nExec=/usr/bin/true\nTryExec=missing-fixture-command\n')
        self.assertFalse(m.autostart()[0]['eligible'])
    def test_add_registered_app_no_execution_and_duplicate_refused(self):
        app=m.defaults()['apps'][0];self.assertEqual(m.add_autostart(app['id'],app['token'])['state'],'succeeded');self.assertEqual(self.registry.calls,[])
        with self.assertRaises(ValueError):m.add_autostart(app['id'],app['token'])
        with self.assertRaises(ValueError):m.add_autostart('../outside.desktop',app['token'])
    def test_future_deployment_private_link_only_and_preserves_existing(self):
        current=m.deployment()
        # Packaged target presence is independently detected; tests never start it.
        with patch.object(m,'deployment',return_value=dict(current,supported=True)):
            self.assertEqual(m.enable_autostart(current['token'])['state'],'succeeded')
        link=self.user/'systemd/user/graphical-session.target.wants/xdg-desktop-autostart.target'
        self.assertTrue(link.is_symlink());self.assertEqual(os.readlink(link),'/usr/lib/systemd/user/xdg-desktop-autostart.target')
        link.unlink();link.write_text('preserve unrelated file');current=m.deployment()
        with patch.object(m,'deployment',return_value=dict(current,supported=True)):
            with self.assertRaises(ValueError):m.enable_autostart(current['token'])
        self.assertEqual(link.read_text(),'preserve unrelated file')
    def test_hidden_update_preserves_unrelated_and_removes_duplicates(self):
        content='[Desktop Entry]\nType=Application\nHidden=false\nHidden=true\nExec=/usr/bin/true\n[Other]\nHidden=leave\n'
        text=m.with_hidden(content,'false');self.assertEqual(text.count('Hidden=false'),1);self.assertIn('[Other]\nHidden=leave',text)
    def test_unknown_cli_and_generic_errors(self):
        with patch('builtins.print'):self.assertEqual(m.main(['launch','arbitrary']),1)
        with patch('builtins.print') as emit,patch.object(m,'defaults',side_effect=OSError('private token')):
            self.assertEqual(m.main(['catalog']),1);self.assertNotIn('private token',str(emit.call_args))

if __name__=='__main__':unittest.main()
