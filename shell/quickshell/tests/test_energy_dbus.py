#!/usr/bin/env python3
"""Real Gio profile API/owner replacement on a private bus; no host writes."""
import importlib.util
import os
from pathlib import Path
import subprocess
import json
import select
import sys
import tempfile
import threading
import time
import unittest
from gi.repository import Gio, GLib

if not os.environ.get('SENOMY_PRIVATE_ENERGY_TEST'):
    raise SystemExit('Run only via the private-bus WP03 validator.')
spec=importlib.util.spec_from_file_location('energy',Path(__file__).parents[1]/'scripts/energy-provider.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
NAME,PATH=m.ENDPOINTS[0]
XML='''<node><interface name="org.freedesktop.UPower.PowerProfiles">
<property name="ActiveProfile" type="s" access="readwrite"/>
<property name="Profiles" type="aa{sv}" access="read"/>
<property name="ActiveProfileHolds" type="aa{sv}" access="read"/>
<property name="PerformanceDegraded" type="s" access="read"/>
</interface></node>'''


class ProfileBus(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.loop=GLib.MainLoop();cls.thread=threading.Thread(target=cls.loop.run,daemon=True);cls.thread.start()
    @classmethod
    def tearDownClass(cls):
        cls.loop.quit();cls.thread.join(timeout=3)
    def setUp(self):
        self.server=None;self.system=m.System();self.system.units=lambda:{}
        self.system.command=lambda argv,timeout=4:subprocess.CompletedProcess(argv,0,'1.10.2\n','')
    def tearDown(self):
        if self.server:self.stop()
    def start(self):
        flags=Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT|Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION
        self.server=Gio.DBusConnection.new_for_address_sync(os.environ['DBUS_SYSTEM_BUS_ADDRESS'],flags,None,None)
        self.profile='balanced'
        def get_property(_conn,_sender,_path,_iface,name):
            if name=='ActiveProfile':return GLib.Variant('s',self.profile)
            if name=='Profiles':return GLib.Variant('aa{sv}',[{'Profile':GLib.Variant('s',p)} for p in m.PROFILES])
            if name=='ActiveProfileHolds':return GLib.Variant('aa{sv}',[])
            return GLib.Variant('s','')
        def set_property(_conn,_sender,_path,_iface,name,value):
            if name!='ActiveProfile' or value.unpack() not in m.PROFILES:return False
            self.profile=value.unpack()
            self.server.emit_signal(None,PATH,'org.freedesktop.DBus.Properties','PropertiesChanged',GLib.Variant('(sa{sv}as)',(NAME,{'ActiveProfile':GLib.Variant('s',self.profile)},[])))
            return True
        self.server.register_object(PATH,Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0],None,get_property,set_property)
        self.server.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',GLib.Variant('(su)',(NAME,0)),None,Gio.DBusCallFlags.NONE,3000,None)
    def stop(self):
        self.server.close_sync(None);self.server=None
        time.sleep(.05)
    def test_late_owner_set_external_change_disappearance_and_replacement(self):
        self.assertFalse(self.system.status()['backend']['available'])
        self.start();before=self.system.status();owner=before['backend']['identity']
        self.assertTrue(before['backend']['available']);self.assertEqual(before['backend']['active'],'balanced')
        result=self.system.set_profile({'profile':'power-saver','token':before['backend']['token']})
        self.assertEqual(result['state'],'verified');self.assertEqual(self.profile,'power-saver')
        self.profile='performance';self.assertEqual(self.system.status()['backend']['active'],'performance')
        self.stop();self.assertFalse(self.system.status()['backend']['available'])
        self.start();replacement=self.system.status()
        self.assertNotEqual(replacement['backend']['identity'],owner)
        with self.assertRaises(m.Problem):self.system.set_profile({'profile':'power-saver','token':before['backend']['token']})
    def test_real_python_bus_peer_can_be_the_tlp_compatibility_daemon(self):
        self.start()
        self.system.units=lambda:{'tlp.service':{'ActiveState':'active','InvocationID':'inert'},'tlp-pd.service':{'ActiveState':'active','MainPID':str(os.getpid())}}
        b=self.system.status()['backend']
        self.assertFalse(b['conflict']);self.assertTrue(b['available']);self.assertEqual(b['kind'],'dbus')
    def test_real_watch_receives_owner_properties_loss_and_resume_signals(self):
        with tempfile.TemporaryDirectory() as directory:
            source=repr(str(Path(m.__file__)))
            code=f'''import importlib.util,subprocess
from pathlib import Path
s=importlib.util.spec_from_file_location("energy",{source});m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
x=m.System(sysroot=Path({directory!r}),runroot=Path({directory!r}));x.units=lambda:{{}};x.command=lambda argv,timeout=4:subprocess.CompletedProcess(argv,0,"1.10.2\\n","");x.watch()
'''
            watcher=subprocess.Popen([sys.executable,'-B','-c',code],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            def observe():
                self.assertTrue(select.select([watcher.stdout],[],[],4)[0], 'No event-driven observation')
                return json.loads(watcher.stdout.readline())
            try:
                self.assertFalse(observe()['backend']['available'])
                self.start();before=observe();self.assertTrue(before['backend']['available'])
                self.profile='performance'
                self.server.emit_signal(None,PATH,'org.freedesktop.DBus.Properties','PropertiesChanged',GLib.Variant('(sa{sv}as)',(NAME,{'ActiveProfile':GLib.Variant('s',self.profile)},[])))
                self.assertEqual(observe()['backend']['active'],'performance')
                self.stop();self.assertFalse(observe()['backend']['available'])
                self.start();self.assertNotEqual(observe()['backend']['identity'],before['backend']['identity'])
                self.server.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',GLib.Variant('(su)',('org.freedesktop.login1',0)),None,Gio.DBusCallFlags.NONE,3000,None)
                self.server.emit_signal(None,'/org/freedesktop/login1','org.freedesktop.login1.Manager','PrepareForSleep',GLib.Variant('(b)',(False,)))
                self.assertTrue(observe()['backend']['available'])  # simulated resume only
            finally:
                watcher.terminate();watcher.communicate(timeout=3)


if __name__=='__main__':unittest.main()
