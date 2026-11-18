import importlib.util
from pathlib import Path
import pwd
import tempfile
import struct
import zlib
import subprocess
import unittest
from unittest.mock import patch

path=Path(__file__).resolve().parents[1]/"scripts/account-settings.py"
spec=importlib.util.spec_from_file_location("account_settings",path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class AccountSafety(unittest.TestCase):
    def account(self,uid=2001,admin=True,locked=False,current=False,signed=False):
        a={"uid":uid,"username":"fixture"+str(uid),"name":"Fixture","avatar":"","administrator":admin,"locked":locked,"current":current,"signedIn":signed,"managed":True,"providerIdentity":"fixture-owner","viableAdministrator":admin and not locked}
        a["token"]=module.token(a);return a
    def state(self,*accounts,**kwargs):
        state=dict(available=True,complete=True,accounts=list(accounts),passwordAvailable=True,providerIdentity="fixture-owner",**kwargs)
        state["token"]=module.token(state);return state
    def check(self,operation,a,value,state):return module.validate(operation,a["uid"],value,a["token"],state)
    def test_active_account_cannot_lose_access(self):
        a=self.account(current=True)
        for operation,value in [("remove",""),("type","0"),("lock","true")]:
            with self.subTest(operation=operation),self.assertRaises(ValueError):self.check(operation,a,value,self.state(a,self.account(2002)))
    def test_last_viable_admin_is_protected(self):
        a=self.account()
        for operation,value in [("remove",""),("type","0"),("lock","true")]:
            with self.subTest(operation=operation),self.assertRaises(ValueError):self.check(operation,a,value,self.state(a,self.account(2002,locked=True)))
    def test_signed_in_account_cannot_be_removed(self):
        a=self.account(signed=True)
        with self.assertRaises(ValueError):self.check("remove",a,"",self.state(a,self.account(2002)))
    def test_standard_account_can_be_reviewed_for_removal(self):
        a=self.account(admin=False)
        self.assertEqual(self.check("remove",a,"",self.state(a,self.account(2002))),a)
    def test_stale_identity_rejected(self):
        a=self.account();s=self.state(a)
        with self.assertRaises(ValueError):module.validate("name",a["uid"],"Name","stale-token",s)
    def test_incomplete_inventory_refuses_destructive_actions(self):
        a=self.account(admin=False);s=self.state(a);s["complete"]=False
        with self.assertRaises(ValueError):self.check("remove",a,"",s)
    def test_password_handoff_own_account_only(self):
        a=self.account(current=True);self.assertEqual(self.check("password",a,"",self.state(a)),a)
        a=self.account()
        with self.assertRaises(ValueError):self.check("password",a,"",self.state(a))
    def test_unknown_operations_and_invalid_arguments(self):
        a=self.account();s=self.state(a,self.account(2002))
        for op,val in [("arbitrary",""),("lock","maybe"),("type","9"),("name","bad\nname"),("avatar","relative.png")]:
            with self.subTest(op=op),self.assertRaises(ValueError):self.check(op,a,val,s)
    def test_create_is_standard_account_and_validates_username(self):
        s=self.state(self.account())
        for name in ["root", "bad;command", "-flag", "a"*32, "UPPER"]:
            with self.subTest(name=name),self.assertRaises(ValueError):module.validate("create",-1,name,s["token"],s)
        with patch.object(module.pwd,"getpwnam",side_effect=KeyError):self.assertIsNone(module.validate("create",-1,"new_fixture",s["token"],s))
    def test_missing_provider_projects_real_normal_accounts_without_password_fields(self):
        entry=pwd.struct_passwd(("fixture","x",2001,2001,"Fixture","/home/fixture","/bin/bash"))
        with patch.object(module,"Backend",side_effect=module.Unavailable("absent")):
            state=module.snapshot(entries=[entry],current=2001)
        self.assertFalse(state["available"]);self.assertFalse(state["complete"])
        self.assertEqual(state["accounts"][0]["username"],"fixture")
        self.assertIsNone(state["accounts"][0]["administrator"])
        self.assertNotIn("password",state["accounts"][0]);self.assertNotIn("pw_passwd",str(state))
    def test_authorized_other_password_handoff_is_literal_and_not_success(self):
        a=self.account();state=self.state(a);state["administrativePasswordAvailable"]=True
        with patch.object(module,"snapshot",return_value=state),patch.object(module.shutil,"which",return_value="/usr/bin/kitty"),patch.object(module,"launch_tool",return_value={"ok":True}) as process:
            result=module.apply("password",a["uid"],"",a["token"])
        self.assertEqual(result["state"],"handed-off")
        process.assert_called_once_with("password",[a["username"]])
    def test_native_readback_confirms_name_and_preserves_unavailable(self):
        entry=pwd.struct_passwd(("fixture2001","x",2001,2001,"Fixture","/home/fixture","/bin/bash"))
        class Provider:
            def __init__(self):self.name="Fixture"
            def ensure_available(self):pass
            def identity(self):return "fixture-owner"
            def authorize(self,*args):pass
            def call(self,*args):return ([],)
            def sessions(self):return set()
            def properties(self,uid):return {"Uid":uid,"UserName":"fixture2001","RealName":self.name,"AccountType":0,"Locked":False,"SystemAccount":False}
            def mutate(self,operation,account,value):self.name=value
        provider=Provider()
        with patch.object(module.pwd,"getpwall",return_value=[entry]):
            original=module.snapshot(provider)["accounts"][0]
            result=module.apply("name",2001,"New fixture",original["token"],provider)
        self.assertTrue(result["ok"]);self.assertEqual(result["snapshot"]["accounts"][0]["name"],"New fixture")
    def test_remove_never_deletes_home_files(self):
        class Fake(module.Backend):
            def __init__(self):self.calls=[]
            def call(self,*args):self.calls.append(args);return ()
        b=Fake();b.mutate("remove",self.account(),"")
        self.assertEqual(b.calls[0],(module.ROOT,module.BUS,"DeleteUser","(xb)",(2001,False),False))
    def png(self,path,width=1,height=1):
        def chunk(kind,payload):return struct.pack(">I",len(payload))+kind+payload+struct.pack(">I",zlib.crc32(kind+payload))
        path.write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",width,height,8,2,0,0,0))+chunk(b"IDAT",zlib.compress(b"\0\xff\0\0"))+chunk(b"IEND",b""))
    def test_avatar_bounded_dimensions_and_header(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"avatar.png";self.png(p);self.assertEqual(len(module.avatar_digest(str(p))),64)
            self.png(p,65535,65535)
            with self.assertRaises(ValueError):module.avatar_digest(str(p))
            p.write_bytes(b"not a PNG"*8)
            with self.assertRaises(ValueError):module.avatar_digest(str(p))
    def test_avatar_readback_accepts_provider_copied_content(self):
        with tempfile.TemporaryDirectory() as d:
            original=Path(d)/"selected.png";stored=Path(d)/"provider-copy.png";self.png(original);stored.write_bytes(original.read_bytes())
            a=self.account();before=self.state(a);changed=dict(a,avatar=str(stored));after=self.state(changed)
            provider=type("Provider",(),{"mutate":lambda *args:None,"authorize":lambda *args:None})()
            with patch.object(module,"snapshot",side_effect=[before,before,after]):result=module.apply("avatar",a["uid"],str(original),a["token"],provider)
            self.assertTrue(result["ok"])
    def test_readback_provider_loss_cannot_confirm_remove(self):
        a=self.account(admin=False);before=self.state(a);after=dict(available=False,complete=False,accounts=[])
        provider=type("Provider",(),{"mutate":lambda *args:None,"authorize":lambda *args:None})()
        with patch.object(module,"snapshot",side_effect=[before,before,after]):result=module.apply("remove",a["uid"],"",a["token"],provider)
        self.assertFalse(result["ok"]);self.assertEqual(result["state"],"unverified")
    def test_setup_handoff_is_fixed_terminal_command_and_not_success(self):
        with patch.object(module,"snapshot",return_value=dict(available=False,accounts=[])),patch.object(module.shutil,"which",return_value="/usr/bin/kitty"),patch.object(module,"launch_tool",return_value={"ok":True}) as proc:
            result=module.apply("setup",-1,"","")
        self.assertEqual(result["state"],"handed-off");proc.assert_called_once_with("provider-setup",["accounts"])
        for uid,value,expected in [(1000,"",""),(-1,"extra",""),(-1,"","extra")]:
            with self.subTest(uid=uid,value=value),self.assertRaises(ValueError):module.validate("setup",uid,value,expected,{})
    def test_setup_cli_refuses_noninteractive_or_unreviewed_install(self):
        helper=module.provider_setup_command()[0]
        for args,code in [(["install","accounts"],64),(["install","other","--confirmed"],64),(["install","accounts","--confirmed"],69)]:
            result=subprocess.run([helper,*args],input="",capture_output=True,text=True)
            self.assertEqual(result.returncode,code,result.stdout+result.stderr)

class AccountCompletion(unittest.TestCase):
    account=AccountSafety.account
    state=AccountSafety.state
    check=AccountSafety.check
    def provider(self,authorize=None):
        from unittest.mock import Mock
        b=Mock();b.authorize.side_effect=authorize;return b
    def test_authentication_delay_target_change_refuses_submission(self):
        a=self.account(admin=False);before=self.state(a);changed=dict(a,name="External");changed['token']=module.token(changed);fresh=self.state(changed);b=self.provider()
        with patch.object(module,'snapshot',side_effect=[before,fresh]):
            with self.assertRaises(ValueError):module.apply('name',a['uid'],'Proposed',a['token'],b)
        b.authorize.assert_called_once();b.mutate.assert_not_called()
    def test_authentication_delay_quorum_or_session_change_refuses(self):
        target=self.account();other=self.account(2002)
        for fresh in [self.state(target,self.account(2002,locked=True)),self.state(dict(target,signedIn=True),other)]:
            b=self.provider()
            with patch.object(module,'snapshot',side_effect=[self.state(target,other),fresh]):
                with self.assertRaises(ValueError):module.apply('remove',target['uid'],'',target['token'],b)
            b.mutate.assert_not_called()
    def test_authentication_delay_provider_change_refuses(self):
        a=self.account(admin=False);before=self.state(a);fresh=dict(before,providerIdentity='replacement');b=self.provider()
        with patch.object(module,'snapshot',side_effect=[before,fresh]):
            with self.assertRaises(ValueError):module.apply('name',a['uid'],'Proposed',a['token'],b)
        b.mutate.assert_not_called()
    def test_creation_inventory_changed_during_auth_refuses(self):
        before=self.state(self.account());fresh=self.state(self.account(),self.account(2002));b=self.provider()
        with patch.object(module.pwd,'getpwnam',side_effect=KeyError),patch.object(module,'snapshot',side_effect=[before,fresh]):
            with self.assertRaises(ValueError):module.apply('create',-1,'new_fixture',before['token'],b)
        b.mutate.assert_not_called()
    def test_denial_and_cancellation_are_distinct_without_mutation(self):
        import sys,json
        a=self.account(admin=False);before=self.state(a)
        for state in ['denied','cancelled']:
            b=self.provider(module.Unavailable('Local authorization stopped',state))
            with patch.object(module,'snapshot',return_value=before),patch.object(module,'Backend',return_value=b),patch.object(sys,'argv',['helper','apply','name',str(a['uid']),'Proposed',a['token'],'--confirmed']),patch('builtins.print') as out:
                self.assertEqual(module.main(),1);self.assertEqual(json.loads(out.call_args.args[0])['state'],state)
            b.mutate.assert_not_called()
    def test_provider_loss_after_write_never_claims_success(self):
        a=self.account(admin=False);before=self.state(a);lost=dict(before,available=False,complete=False);b=self.provider()
        with patch.object(module,'snapshot',side_effect=[before,before,lost]):r=module.apply('name',a['uid'],'Changed',a['token'],b)
        self.assertFalse(r['ok']);self.assertEqual(r['state'],'unverified');b.mutate.assert_called_once()
    def test_signed_in_account_cannot_be_locked_or_demoted(self):
        a=self.account(signed=True);before=self.state(a,self.account(2002))
        for operation,value in [('lock','true'),('type','0')]:
            with self.assertRaises(ValueError):self.check(operation,a,value,before)
    def fixture_provider(self,sessions_fail=False):
        class Provider:
            def ensure_available(self):pass
            def identity(self):return 'fixture-owner'
            def call(self,*args):return ([],)
            def sessions(self):
                if sessions_fail:raise module.Unavailable('logind missing')
                return set()
            def properties(self,uid):return {'Uid':uid,'UserName':'fixture'+str(uid),'RealName':'Fixture','AccountType':1,'Locked':False,'SystemAccount':False}
        return Provider()
    def entries(self):return [pwd.struct_passwd(('fixture2001','x',2001,2001,'Fixture','/home/fixture','/bin/bash')),pwd.struct_passwd(('fixture2002','x',2002,2002,'Fixture','/home/fixture','/usr/bin/nologin'))]
    def test_nonlogin_admin_is_not_recovery_quorum(self):
        s=module.snapshot(self.fixture_provider(),entries=self.entries(),current=3000);self.assertTrue(s['complete']);self.assertTrue(s['accounts'][0]['viableAdministrator']);self.assertFalse(s['accounts'][1]['viableAdministrator'])
        with self.assertRaises(ValueError):module.validate('remove',2001,'',s['accounts'][0]['token'],s)
    def test_session_outage_keeps_provider_metadata_readable(self):
        s=module.snapshot(self.fixture_provider(True),entries=self.entries(),current=2001);self.assertTrue(s['available']);self.assertFalse(s['complete']);self.assertTrue(s['accounts'][0]['managed']);self.assertTrue(s['accounts'][0]['administrator'])
    def test_invalid_provider_types_disable_administration(self):
        b=self.fixture_provider();original=b.properties;b.properties=lambda uid:dict(original(uid),AccountType='1')
        s=module.snapshot(b,entries=self.entries(),current=2001);self.assertFalse(s['complete']);self.assertFalse(s['accounts'][0]['managed'])

if __name__=="__main__":unittest.main()
