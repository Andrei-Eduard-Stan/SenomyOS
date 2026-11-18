"""Private-bus integration: real Gio helper, inert exported BlueZ interfaces.

Run via dbus-run-session. Never points at the host system bus or real devices.
"""
import json
import os
import queue
import subprocess
import sys
import threading
import time
import unittest
from pathlib import Path
from gi.repository import Gio, GLib

A='/org/bluez/hci0';D=A+'/dev_AA_BB_CC_DD_EE_FF'
ADAPTER='org.bluez.Adapter1';DEVICE='org.bluez.Device1'
XML='''<node>
<interface name="org.freedesktop.DBus.ObjectManager"><method name="GetManagedObjects"><arg direction="out" type="a{oa{sa{sv}}}"/></method><signal name="InterfacesAdded"><arg type="o"/><arg type="a{sa{sv}}"/></signal><signal name="InterfacesRemoved"><arg type="o"/><arg type="as"/></signal></interface>
<interface name="org.bluez.Adapter1"><method name="StartDiscovery"/><method name="StopDiscovery"/><method name="RemoveDevice"><arg direction="in" type="o"/></method><property name="Powered" type="b" access="readwrite"/><property name="Alias" type="s" access="read"/><property name="Discovering" type="b" access="read"/><property name="Pairable" type="b" access="readwrite"/><property name="Discoverable" type="b" access="readwrite"/><property name="PairableTimeout" type="u" access="readwrite"/><property name="DiscoverableTimeout" type="u" access="readwrite"/></interface>
<interface name="org.bluez.Device1"><method name="Connect"/><method name="Disconnect"/><method name="Pair"/><signal name="Disconnected"><arg type="s"/><arg type="s"/></signal><method name="CancelPairing"/><property name="Adapter" type="o" access="read"/><property name="Alias" type="s" access="readwrite"/><property name="Name" type="s" access="read"/><property name="Address" type="s" access="read"/><property name="RSSI" type="n" access="read"/><property name="WakeAllowed" type="b" access="readwrite"/><property name="Connected" type="b" access="read"/><property name="Paired" type="b" access="read"/><property name="Trusted" type="b" access="readwrite"/><property name="Blocked" type="b" access="readwrite"/><property name="ServicesResolved" type="b" access="read"/></interface>
<interface name="org.bluez.AgentManager1"><method name="RegisterAgent"><arg direction="in" type="o"/><arg direction="in" type="s"/></method></interface></node>'''

class FakeBluez:
    def __init__(self):
        self.bus=Gio.bus_get_sync(Gio.BusType.SESSION,None)
        self.bus.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',GLib.Variant('(su)',('org.bluez',0)),None,Gio.DBusCallFlags.NONE,2000,None)
        self.xml=Gio.DBusNodeInfo.new_for_xml(XML)
        self.ids=[];self.calls=[];self.mode='fail';self.held=None;self.agent=None;self.removed=False
        self.props={A:{'Powered':True,'Alias':'Private test adapter','Discovering':True,'Pairable':False,'Discoverable':False,'PairableTimeout':0,'DiscoverableTimeout':0},D:{'Adapter':A,'Alias':'Test earbuds','Name':'Test earbuds','Address':'AA:BB:CC:DD:EE:FF','Connected':False,'Paired':True,'Trusted':True,'Blocked':False,'ServicesResolved':False}}
        for path,interface in [('/','org.freedesktop.DBus.ObjectManager'),(A,ADAPTER),(D,DEVICE),('/org/bluez','org.bluez.AgentManager1')]:
            info=self.xml.lookup_interface(interface)
            self.ids.append(self.bus.register_object(path,info,self.method,self.get,self.set))
    def variant(self,path,key,value):
        return GLib.Variant('n' if key=='RSSI' else 'o' if key=='Adapter' else 'u' if key.endswith('Timeout') else 'b' if type(value) is bool else 's',value)
    def interfaces(self,path):
        return {ADAPTER if path==A else DEVICE:{key:self.variant(path,key,value) for key,value in self.props[path].items()}}
    def get(self,bus,sender,path,interface,prop):return self.variant(path,prop,self.props[path][prop])
    def set(self,bus,sender,path,interface,prop,value):self.change(path,**{prop:(self.props[path]['Name'] if prop=='Alias' and value.unpack()=='' else value.unpack())});return True
    def change(self,path,**values):
        self.props[path].update(values)
        self.bus.emit_signal(None,path,'org.freedesktop.DBus.Properties','PropertiesChanged',GLib.Variant('(sa{sv}as)',(ADAPTER if path==A else DEVICE,{k:self.variant(path,k,v) for k,v in values.items()},[])))
    def method(self,bus,sender,path,interface,method,params,inv):
        self.calls.append((method,path,sender))
        if method=='GetManagedObjects':
            inv.return_value(GLib.Variant('(a{oa{sa{sv}}})',({p:self.interfaces(p) for p in self.props if p!=D or not self.removed},)));return
        if method=='RegisterAgent':self.agent=(sender,params.unpack()[0]);inv.return_value(None);return
        if method=='Connect':
            if self.mode=='fail':inv.return_dbus_error('org.bluez.Error.Failed','br-connection-page-timeout')
            elif self.mode=='hold':self.held=inv
            else:self.change(D,Connected=True,ServicesResolved=True);inv.return_value(None)
            return
        if method in ('Disconnect','CancelPairing'):
            if self.held:self.held.return_dbus_error('org.bluez.Error.Canceled','Cancelled by private fake');self.held=None
            self.change(D,Connected=False);inv.return_value(None);return
        if method=='Pair':
            self.held=inv
            def answer(connection,result):
                try:
                    connection.call_finish(result)
                    if self.held:self.change(D,Paired=True);self.held.return_value(None);self.held=None
                except GLib.Error:
                    if self.held:self.held.return_dbus_error('org.bluez.Error.AuthenticationRejected','Rejected in private test');self.held=None
            agent_method,agent_params = ('RequestPinCode',GLib.Variant('(o)',(D,))) if self.mode=='pin' else ('RequestPasskey',GLib.Variant('(o)',(D,))) if self.mode=='passkey' else ('RequestConfirmation',GLib.Variant('(ou)',(D,123456)))
            self.bus.call(self.agent[0],self.agent[1],'org.bluez.Agent1',agent_method,agent_params,None,Gio.DBusCallFlags.NONE,5000,None,answer)
            return
        if method=='RemoveDevice':
            self.removed=True;self.bus.emit_signal(None,'/','org.freedesktop.DBus.ObjectManager','InterfacesRemoved',GLib.Variant('(oas)',(D,[DEVICE])));inv.return_value(None);return
        # Discovering is already true due to an unrelated fake caller. Our
        # StopDiscovery must leave it true and use the same owner as Start.
        inv.return_value(None)
    def close(self):
        for ident in self.ids:self.bus.unregister_object(ident)
        self.bus.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','ReleaseName',GLib.Variant('(s)',('org.bluez',)),None,Gio.DBusCallFlags.NONE,2000,None)


class NativeBluezProtocol(unittest.TestCase):
    def setUp(self):
        self.assertTrue(os.environ.get('DBUS_SESSION_BUS_ADDRESS'))
        self.loop=GLib.MainLoop();self.fake=FakeBluez();self.thread=threading.Thread(target=self.loop.run,daemon=True);self.thread.start()
        script=Path(__file__).resolve().parents[1]/'scripts/bluetooth-controller.py'
        env=dict(os.environ,SENOMY_BLUETOOTH_TEST_BUS=os.environ['DBUS_SESSION_BUS_ADDRESS'])
        self.proc=subprocess.Popen([sys.executable,'-B',str(script)],env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
        self.events=queue.Queue();self.reader=threading.Thread(target=lambda:[self.events.put(json.loads(line)) for line in self.proc.stdout],daemon=True);self.reader.start()
        self.state=None;self.wait(lambda s:s['available']);self.send(command='context',active=True)
    def tearDown(self):
        self.proc.stdin.close();self.proc.wait(timeout=4)
        errors=self.proc.stderr.read();self.assertNotIn('Traceback',errors)
        self.proc.stdout.close();self.proc.stderr.close();self.fake.close();self.loop.quit();self.thread.join(timeout=1)
    def send(self,**data):self.proc.stdin.write(json.dumps(data)+'\n');self.proc.stdin.flush()
    def wait(self,predicate,seconds=4):
        deadline=time.monotonic()+seconds
        while time.monotonic()<deadline:
            try:event=self.events.get(timeout=0.1)
            except queue.Empty:continue
            if event.get('type')=='state':
                self.state=event['state']
                if predicate(self.state):return self.state
        self.fail('State not observed: '+str(self.state))
    def request(self,action='connect',path=D,value=None):
        obj=next(x for x in self.state['devices']+self.state['adapters'] if x['id']==path)
        self.send(command='request',action=action,path=path,token=obj['token'],adapterToken=self.state['adapters'][0]['token'],expected=obj['expected'],value=value,requestId='test')
    def test_connect_failure_retry_and_external_state(self):
        self.request();self.wait(lambda s:s['operations'].get(D,{}).get('phase')=='failed')
        self.assertEqual(self.state['operations'][D]['errorDetail'],'br-connection-page-timeout')
        self.fake.mode='success';self.request();self.wait(lambda s:s['operations'].get(D,{}).get('phase')=='succeeded')
        self.assertTrue(self.state['devices'][0]['connected'])
        self.fake.change(D,Connected=False);self.wait(lambda s:not s['devices'][0]['connected'])
        self.assertEqual([x[0] for x in self.fake.calls].count('Connect'),2)
    def test_real_disconnect_interrupts_pending_connect(self):
        self.fake.mode='hold';self.request();self.wait(lambda s:s['operations'].get(D,{}).get('phase')=='running')
        ident=self.state['operations'][D]['id'];self.send(command='cancel',path=D,id=ident)
        self.wait(lambda s:s['operations'][D]['phase']=='cancelled')
        self.assertIn('Disconnect',[x[0] for x in self.fake.calls]);self.assertFalse(self.state['devices'][0]['connected'])
        self.fake.mode='success';self.request();self.wait(lambda s:s['operations'][D]['phase']=='succeeded')
    def test_pairing_agent_confirmation_and_cancel(self):
        self.fake.change(D,Paired=False);self.wait(lambda s:not s['devices'][0]['paired'])
        self.request('pair');self.wait(lambda s:bool(s['prompt']))
        self.assertEqual(self.state['prompt']['code'],'123456')
        self.send(command='answer',id=self.state['prompt']['id'],accept=True,value='')
        self.wait(lambda s:s['operations'][D]['phase']=='succeeded')
        self.assertTrue(self.state['devices'][0]['paired'])
        self.assertNotIn('RequestDefaultAgent',[x[0] for x in self.fake.calls])
        self.fake.change(D,Paired=False);self.wait(lambda s:not s['devices'][0]['paired'])
        self.request('pair');self.wait(lambda s:bool(s['prompt']))
        self.send(command='cancel',path=D,id=self.state['operations'][D]['id'])
        self.wait(lambda s:s['operations'][D]['phase']=='cancelled')
        self.assertIn('CancelPairing',[x[0] for x in self.fake.calls])
    def test_discovery_ownership_and_deliberate_scan(self):
        time.sleep(0.05);self.assertNotIn('StartDiscovery',[x[0] for x in self.fake.calls])
        self.send(command='scan',path=A);self.wait(lambda s:s['scan']['state']=='running')
        self.send(command='stopScan');self.wait(lambda s:s['scan']['state']=='idle')
        start=next(x for x in self.fake.calls if x[0]=='StartDiscovery');stop=next(x for x in self.fake.calls if x[0]=='StopDiscovery')
        self.assertEqual(start[2],stop[2]);self.assertTrue(self.state['adapters'][0]['discovering'])
    def test_pin_and_passkey_are_explicit_and_not_logged(self):
        for mode,kind,value in [('pin','RequestPinCode','7251'),('passkey','RequestPasskey','004273')]:
            self.fake.mode=mode;self.fake.change(D,Paired=False,Trusted=False);self.wait(lambda s:not s['devices'][0]['paired'])
            self.request('pair');self.wait(lambda s:bool(s['prompt']))
            self.assertEqual(self.state['prompt']['kind'],kind)
            self.send(command='answer',id=self.state['prompt']['id'],accept=True,value=value)
            self.wait(lambda s:s['operations'][D]['phase']=='succeeded')
            self.assertFalse(self.state['devices'][0]['trusted'])
    def test_unrecognized_agent_caller_cannot_replace_prompt(self):
        self.fake.change(D,Paired=False);self.wait(lambda s:not s['devices'][0]['paired']);self.request('pair');self.wait(lambda s:bool(s['prompt']))
        original=self.state['prompt']['id']
        third=Gio.DBusConnection.new_for_address_sync(os.environ['DBUS_SESSION_BUS_ADDRESS'],Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT|Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,None,None)
        with self.assertRaises(GLib.Error):
            third.call_sync(self.fake.agent[0],self.fake.agent[1],'org.bluez.Agent1','RequestConfirmation',GLib.Variant('(ou)',(D,999999)),None,Gio.DBusCallFlags.NONE,2000,None)
        third.close_sync(None)
        self.assertEqual(original,self.state['prompt']['id'])
        self.send(command='answer',id=original,accept=False,value='');self.wait(lambda s:s['operations'][D]['phase']=='cancelled')
    def test_service_restart_reconstructs_without_stale_operation(self):
        self.fake.mode='hold';self.request();self.wait(lambda s:s['operations'].get(D,{}).get('phase')=='running')
        token=self.state['devices'][0]['token'];self.fake.close();self.wait(lambda s:not s['available'])
        self.fake=FakeBluez();self.wait(lambda s:s['available'] and bool(s['devices']))
        self.assertNotEqual(token,self.state['devices'][0]['token']);self.assertEqual(self.state['operations'][D]['phase'],'failed')
        self.fake.mode='success';self.request();self.wait(lambda s:s['operations'][D]['phase']=='succeeded')
    def test_external_new_advertisement_is_fresh_without_owning_scan(self):
        other=A+'/dev_11_22_33_44_55_66'
        self.fake.props[other]=dict(self.fake.props[D],Paired=False,Address='11:22:33:44:55:66',RSSI=-49)
        self.fake.ids.append(self.fake.bus.register_object(other,self.fake.xml.lookup_interface(DEVICE),self.fake.method,self.fake.get,self.fake.set))
        self.fake.bus.emit_signal(None,'/','org.freedesktop.DBus.ObjectManager','InterfacesAdded',GLib.Variant('(oa{sa{sv}})',(other,self.fake.interfaces(other))))
        self.wait(lambda s:any(d['id']==other and d['recent'] for d in s['devices']))
        self.assertEqual(len(self.state['devices']),2);self.assertFalse(self.state['scan']['owned']);self.assertNotIn('StartDiscovery',[x[0] for x in self.fake.calls])
    def test_disconnection_reason_and_wake_readback(self):
        self.fake.change(D,WakeAllowed=False);self.wait(lambda s:s['devices'][0]['wakeAllowed'] is False)
        self.request('wake',value=True);self.wait(lambda s:s['operations'].get(D,{}).get('phase')=='succeeded');self.assertTrue(self.state['devices'][0]['wakeAllowed'])
        self.fake.bus.emit_signal(None,D,DEVICE,'Disconnected',GLib.Variant('(ss)',('org.bluez.Reason.Remote','Remote device ended the connection')))
        self.wait(lambda s:bool(s['devices'][0]['lastDisconnect']));self.assertEqual(self.state['devices'][0]['lastDisconnect']['reason'],'org.bluez.Reason.Remote')
    def test_unpaired_cache_removal_works_with_power_off(self):
        self.fake.change(D,Paired=False);self.fake.change(A,Powered=False);self.wait(lambda s:not s['devices'][0]['paired'] and not s['adapters'][0]['powered'])
        self.request('remove');self.wait(lambda s:not s['devices']);self.assertEqual(self.state['operations'][D]['phase'],'succeeded')
    def test_forget_and_property_write_use_real_methods(self):
        self.request('untrust');self.wait(lambda s:s['operations'].get(D,{}).get('phase')=='succeeded');self.assertFalse(self.state['devices'][0]['trusted'])
        self.request('rename',value='Private alias');self.wait(lambda s:s['devices'][0]['name']=='Private alias' and s['operations'][D]['phase']=='succeeded')
        self.request('rename',value='');self.wait(lambda s:s['devices'][0]['name']=='Test earbuds' and s['operations'][D]['phase']=='succeeded')
        self.request('forget');self.wait(lambda s:s['operations'][D]['phase']=='succeeded' and not s['devices'])
        self.assertIn('RemoveDevice',[x[0] for x in self.fake.calls])

if __name__=='__main__':unittest.main()
