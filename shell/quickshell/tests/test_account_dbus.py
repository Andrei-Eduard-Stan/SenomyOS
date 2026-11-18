"""Exercise actual Gio calls on a private fixture bus, never the system bus."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import threading
import unittest
import sys,json,select,time,os

spec=importlib.util.spec_from_file_location("accounts",Path(__file__).resolve().parents[1]/"scripts/account-settings.py")
accounts=importlib.util.module_from_spec(spec);spec.loader.exec_module(accounts)
try:
    from gi.repository import Gio,GLib
except ImportError:
    Gio=GLib=None

@unittest.skipUnless(Gio and shutil.which("dbus-daemon"),"private Gio/DBus fixture dependencies unavailable")
class NativeAccountBus(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.daemon=subprocess.Popen(["dbus-daemon","--session","--nofork","--print-address=1"],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        address=cls.daemon.stdout.readline().strip();cls.address=address
        flags=Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT|Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION
        cls.server=Gio.DBusConnection.new_for_address_sync(address,flags,None,None)
        cls.connection=Gio.DBusConnection.new_for_address_sync(address,flags,None,None)
        cls.calls=[];cls.real_name="Fixture";cls.user_path=accounts.ROOT+"/User2001"
        xml='''<node><interface name="org.freedesktop.Accounts">
          <method name="ListCachedUsers"><arg direction="out" type="ao"/></method>
          <method name="FindUserById"><arg direction="in" type="x"/><arg direction="out" type="o"/></method>
          <method name="CreateUser"><arg direction="in" type="s"/><arg direction="in" type="s"/><arg direction="in" type="i"/><arg direction="out" type="o"/></method>
          <method name="DeleteUser"><arg direction="in" type="x"/><arg direction="in" type="b"/></method>
        </interface><interface name="org.freedesktop.Accounts.User">
          <property name="Uid" type="t" access="read"/><property name="UserName" type="s" access="read"/>
          <property name="RealName" type="s" access="read"/><property name="AccountType" type="i" access="read"/>
          <property name="Locked" type="b" access="read"/><property name="SystemAccount" type="b" access="read"/>
          <method name="SetRealName"><arg direction="in" type="s"/></method>
        </interface><interface name="org.freedesktop.login1.Manager">
          <method name="ListSessions"><arg direction="out" type="a(susso)"/></method>
        </interface><interface name="org.freedesktop.PolicyKit1.Authority">
          <method name="CheckAuthorization"><arg direction="in" type="(sa{sv})"/><arg direction="in" type="s"/><arg direction="in" type="a{ss}"/><arg direction="in" type="u"/><arg direction="in" type="s"/><arg direction="out" type="(bba{ss})"/></method>
        </interface></node>'''
        info=Gio.DBusNodeInfo.new_for_xml(xml)
        def handle(connection,sender,path,interface,method,parameters,invocation):
            args=parameters.unpack();cls.calls.append((interface,method,args,invocation.get_message().get_flags()))
            if method=="CheckAuthorization":result=GLib.Variant("((bba{ss}))",((cls.authorized,False,{"polkit.dismissed":"true"}if cls.dismissed else {}),))
            elif method=="ListCachedUsers":result=GLib.Variant("(ao)",([cls.user_path],))
            elif method in ("FindUserById","CreateUser"):result=GLib.Variant("(o)",(cls.user_path,))
            elif method=="ListSessions":result=GLib.Variant("(a(susso))",([("f1",2001,"fixture","seat0","/org/freedesktop/login1/session/f1")],))
            else:
                if method=="SetRealName":cls.real_name=args[0]
                result=GLib.Variant("()",())
            invocation.return_value(result)
        def get_property(connection,sender,path,interface,name):
            values={"Uid":("t",2001),"UserName":("s","fixture"),"RealName":("s",cls.real_name),"AccountType":("i",0),"Locked":("b",False),"SystemAccount":("b",False)}
            signature,value=values[name];return GLib.Variant(signature,value)
        cls.info=info;cls.handle=handle;cls.get_property=get_property;cls.authorized=True;cls.dismissed=False
        cls.registrations=[]
        for interface,path in [(info.interfaces[0],accounts.ROOT),(info.interfaces[1],cls.user_path),(info.interfaces[2],"/org/freedesktop/login1"),(info.interfaces[3],"/org/freedesktop/PolicyKit1/Authority")]:
            cls.registrations.append(cls.server.register_object(path,interface,handle,get_property,None))
        for name in [accounts.BUS,"org.freedesktop.login1","org.freedesktop.PolicyKit1"]:
            cls.server.call_sync("org.freedesktop.DBus","/org/freedesktop/DBus","org.freedesktop.DBus","RequestName",GLib.Variant("(su)",(name,0)),None,Gio.DBusCallFlags.NONE,2000,None)
        cls.loop=GLib.MainLoop();cls.worker=threading.Thread(target=cls.loop.run,daemon=True);cls.worker.start()
    @classmethod
    def tearDownClass(cls):
        cls.loop.quit();cls.worker.join(timeout=2)
        cls.connection.close_sync(None);cls.server.close_sync(None)
        cls.daemon.terminate();cls.daemon.communicate(timeout=3)
    def setUp(self):
        type(self).authorized=True;type(self).dismissed=False;type(self).real_name="Fixture";self.calls.clear()
    def backend(self):
        b=accounts.Backend.__new__(accounts.Backend);b.Gio=Gio;b.GLib=GLib;b.connection=self.connection;return b
    def test_native_property_unpack_and_logind_session_signature(self):
        b=self.backend();properties=b.properties(2001)
        self.assertEqual(properties["Uid"],2001);self.assertIs(properties["Locked"],False)
        self.assertEqual(b.sessions(),{2001})
    def test_write_marshalling_requests_authorization_and_retains_home(self):
        b=self.backend();b.mutate("name",{"uid":2001},"Native fixture")
        self.assertEqual(b.properties(2001)["RealName"],"Native fixture")
        b.mutate("create",None,"new_fixture");b.mutate("remove",{"uid":2001},"")
        relevant=[row for row in self.calls if row[1] in ["SetRealName","CreateUser","DeleteUser"]]
        self.assertTrue(all(not(row[3]&Gio.DBusMessageFlags.ALLOW_INTERACTIVE_AUTHORIZATION) for row in relevant))
        self.assertEqual(relevant[-2][2],("new_fixture","new_fixture",0))
        self.assertEqual(relevant[-1][2],(2001,False))

    def test_polkit_subject_and_action_are_exact(self):
        b=self.backend();b.authorize('name',{'current':True});row=next(r for r in self.calls if r[1]=='CheckAuthorization')
        self.assertEqual(row[2][0],('system-bus-name',{'name':self.connection.get_unique_name()}));self.assertEqual(row[2][1],'org.freedesktop.accounts.change-own-user-data');self.assertEqual(row[2][2],{});self.assertEqual(row[2][3],1)
        b.authorize('create',None);self.assertEqual(self.calls[-1][2][1],'org.freedesktop.accounts.user-administration')
    def test_polkit_denial_and_cancellation_are_distinct(self):
        b=self.backend();type(self).authorized=False
        for dismissed,state in [(False,'denied'),(True,'cancelled')]:
            type(self).dismissed=dismissed
            with self.assertRaises(accounts.Unavailable) as caught:b.authorize('create',None)
            self.assertEqual(caught.exception.state,state)
        self.assertFalse(any(row[1]in('CreateUser','DeleteUser','SetRealName')for row in self.calls))
    def test_readonly_watch_external_change_and_provider_return(self):
        # Patch only the child fixture's NSS/current UID and bus connection.
        code='''import sys,importlib.util,pwd
from gi.repository import Gio,GLib
spec=importlib.util.spec_from_file_location('fixture_accounts',sys.argv[1]);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
b=m.Backend.__new__(m.Backend);b.Gio=Gio;b.GLib=GLib;b.owner='';b.in_mutation=False
b.connection=Gio.DBusConnection.new_for_address_sync(sys.argv[2],Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT|Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,None,None)
m.Backend=lambda:b;m.pwd.getpwall=lambda:[pwd.struct_passwd(('fixture','x',2001,2001,'Fixture','/home/fixture','/bin/bash'))];m.os.getuid=lambda:2001
sys.argv=['fixture','watch'];raise SystemExit(m.main())
'''
        child=subprocess.Popen([sys.executable,'-B','-c',code,accounts.__file__,self.address],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0);buffer=b'';replacement=None
        def read_until(predicate):
            nonlocal buffer
            deadline=time.monotonic()+4
            while True:
                while b'\n'not in buffer:
                    remaining=deadline-time.monotonic()
                    if remaining<=0 or not select.select([child.stdout],[],[],remaining)[0]:self.fail('private observer response timed out')
                    chunk=os.read(child.stdout.fileno(),65536)
                    if not chunk:self.fail('private observer stopped')
                    buffer+=chunk
                line,buffer=buffer.split(b'\n',1);state=json.loads(line)
                if predicate(state):return state
        try:
            initial=read_until(lambda s:s.get('available'));self.assertTrue(initial['complete'])
            type(self).real_name='External fixture'
            self.server.emit_signal(None,self.user_path,accounts.USER,'Changed',GLib.Variant('()',()))
            changed=read_until(lambda s:s['accounts'][0]['name']=='External fixture');self.assertNotEqual(changed['accounts'][0]['token'],initial['accounts'][0]['token'])
            self.server.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','ReleaseName',GLib.Variant('(s)',(accounts.BUS,)),None,Gio.DBusCallFlags.NONE,2000,None)
            lost=read_until(lambda s:not s.get('available'));self.assertFalse(lost['complete'])
            replacement=Gio.DBusConnection.new_for_address_sync(self.address,Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT|Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,None,None)
            for interface,path in [(self.info.interfaces[0],accounts.ROOT),(self.info.interfaces[1],self.user_path)]:replacement.register_object(path,interface,type(self).handle,type(self).get_property,None)
            replacement.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',GLib.Variant('(su)',(accounts.BUS,0)),None,Gio.DBusCallFlags.NONE,2000,None)
            returned=read_until(lambda s:s.get('available'));self.assertNotEqual(returned['providerIdentity'],initial['providerIdentity'])
            child.stdin.write(b'refresh\n');read_until(lambda s:s.get('available'))
            child.stdin.close();child.wait(timeout=4);self.assertEqual(child.returncode,0)
            self.assertFalse(any(row[1]in('CreateUser','DeleteUser','SetRealName','CheckAuthorization')for row in self.calls))
        finally:
            if child.poll()is None:child.stdin.close();child.wait(timeout=4)
            child.stdout.close();child.stderr.close()
            if replacement:replacement.close_sync(None)
            self.server.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',GLib.Variant('(su)',(accounts.BUS,0)),None,Gio.DBusCallFlags.NONE,2000,None)

if __name__=="__main__":unittest.main()
