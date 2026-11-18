#!/usr/bin/env python3
"""Provider changes on a private D-Bus only; never uses the desktop session bus."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
scenario = r'''
import json,os,select,subprocess,sys
from gi.repository import Gio,GLib
bus=Gio.bus_get_sync(Gio.BusType.SESSION,None)
name='org.freedesktop.Notifications'
def call(method,args,result):
 return bus.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus',method,args,GLib.VariantType(result),Gio.DBusCallFlags.NO_AUTO_START,2000,None)
observer=subprocess.Popen([sys.executable,sys.argv[1],str(os.getpid())],stdout=subprocess.PIPE,text=True)
peer=None
def observe(state):
 for _ in range(20):
  if select.select([observer.stdout],[],[],.2)[0]:
   value=json.loads(observer.stdout.readline())
   if value['state']==state:return value
 raise AssertionError('Missing ownership transition: '+state)
try:
 assert observe('unowned')['owned'] is False
 assert call('RequestName',GLib.Variant('(su)',(name,4)),'(u)').unpack()[0]==1
 native=observe('native');assert native['owned'] and native['owner_pid']==os.getpid()
 call('ReleaseName',GLib.Variant('(s)',(name,)),'(u)');assert not observe('unowned')['owned']
 code="from gi.repository import Gio,GLib;import sys;b=Gio.bus_get_sync(Gio.BusType.SESSION,None);b.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',GLib.Variant('(su)',('org.freedesktop.Notifications',4)),GLib.VariantType('(u)'),Gio.DBusCallFlags.NO_AUTO_START,2000,None);print('ready',flush=True);GLib.MainLoop().run()"
 peer=subprocess.Popen([sys.executable,'-c',code],stdout=subprocess.PIPE,text=True)
 assert peer.stdout.readline().strip()=='ready'
 external=observe('external');assert not external['owned'] and external['owner_pid']==peer.pid
 peer.terminate();peer.wait(timeout=3);peer=None
 assert observe('unowned')['available']
 print('PASS: private notification bus unowned/native/external/release transitions, actual owner PIDs, no daemon changes')
finally:
 observer.terminate();observer.wait(timeout=3)
 if peer:peer.terminate();peer.wait(timeout=3)
'''
result = subprocess.run(['dbus-run-session', '--', sys.executable, '-c', scenario,
                         str(root/'shell/quickshell/scripts/notification-owner.py')],
                        capture_output=True, text=True, timeout=20)
print(result.stdout, end='')
if result.returncode:
    raise SystemExit(result.stderr or result.returncode)
