"""Inert provider integration. Generated production Lua runs in plain Lua,
never Hyprland. The API model follows pinned 0.56.2 types/timer behavior.
"""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('input_settings', Path(__file__).parents[1] / 'scripts/input-settings.py')
m = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(m)

LUA_MODEL = r'''
local function encode(v)
    if type(v)=='string' then return '"'..v:gsub('[%z\1-\31\\"]',function(c)
        if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' else return string.format('\\u%04x',string.byte(c)) end end)..'"' end
    if type(v)=='boolean' or type(v)=='number' then return tostring(v) end
    if v==nil then return 'null' end
    local parts={}; for k,x in pairs(v) do parts[#parts+1]=encode(k)..':'..encode(x) end
    return '{'..table.concat(parts,',')..'}'
end
local timers={}
hl={}
function hl.get_config(k) return options[k] end
function hl.config(t)
    local function walk(node,prefix)
        for k,v in pairs(node) do
            local key=prefix=='' and k or prefix..':'..k
            if type(v)=='table' then walk(v,key)
            elseif options[key]==nil then errors[#errors+1]='unknown option'
            elseif rejectAll or rejectKeys[key] then errors[#errors+1]='inert rejected option'
            elseif type(options[key])~=type(v) then errors[#errors+1]='wrong scalar type'
            else options[key]=v end
        end
    end
    walk(t,'')
end
function hl.exec_scheduled_prop_refresh_immediately() refreshes=refreshes+1 end
function hl.timer(fn,opts)
    if timerMissing then error('inert missing timer') end
    assert(type(fn)=='function' and opts.type=='oneshot' and opts.timeout>0)
    timers[#timers+1]=fn
    -- Real HL.Timer exposes set_enabled/is_enabled/set_timeout, not cancel.
    return {set_enabled=function()end,is_enabled=function()return true end}
end
function expire() local copy=timers;timers={};for _,f in ipairs(copy)do f()end end
for path in io.lines() do
    errors={}
    local fn,loadError=loadfile(path)
    local ok,returned=false,nil
    if fn then ok,returned=pcall(fn) end
    io.write(encode({ok=ok,returned=returned,error=loadError or (not ok and tostring(returned) or ''),errors=table.concat(errors,';')}),'\n');io.flush()
end
'''


class LuaProvider:
    def __init__(self, directory):
        self.directory = Path(directory); self.calls = []; self.refusal = None
        defaults = {d[0]: (False if d[1] is bool else 0.0 if d[1] is float else 25) for d in m.FIELDS.values()}
        defaults.update({'input:repeat_delay': 600, 'input:touchpad:tap-to-click': True,
                         'input:touchpad:disable_while_typing': True, 'input:scroll_factor': 1.0,
                         'input:touchpad:scroll_factor': 1.0, 'input:kb_layout': 'gb,us',
                         'input:kb_variant': ',', 'input:kb_file': '', 'input:accel_profile': ''})
        script = self.directory / 'provider.lua'
        script.write_text('options='+m.lua(defaults)+'; errors={};rejectKeys={};refreshes=0;senomy_input_restore_v2=true\n'+LUA_MODEL)
        self.worker = subprocess.Popen(['lua',str(script)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
        self.devices = [{'name':'fixture-keyboard','sessionId':'kb-1','kind':'keyboard','layout':'gb,us','variant':',','main':True},
                        {'name':'fixture-touchpad','sessionId':'tp-1','kind':'touchpad'},
                        {'name':'fixture-mouse','sessionId':'mouse-1','kind':'pointer'}]
        self.update_keyboard = True
    def close(self):
        self.worker.stdin.close(); self.worker.wait(timeout=3); self.worker.stdout.close()
    def execute(self, source):
        p=self.directory/'request.lua';p.write_text(source)
        self.worker.stdin.write(str(p)+'\n');self.worker.stdin.flush()
        return json.loads(self.worker.stdout.readline())
    def values(self):return self.execute('return options')['returned']
    def get_devices(self):
        devices=[dict(x) for x in self.devices]
        if self.update_keyboard:
            options=self.values()
            for device in devices:
                if device['kind']=='keyboard':device.update(layout=options['input:kb_layout'],variant=options['input:kb_variant'])
        return devices
    def hypr(self,*args):
        self.calls.append(args)
        if args[:2]==('-j','--batch'):
            options=self.values();items=[]
            for key in m.OPTIONS:
                v=options[key];typ='bool' if type(v) is bool else 'int' if type(v) is int else 'float' if type(v) is float else 'str'
                if key in ('input:sensitivity','input:scroll_factor','input:touchpad:scroll_factor'):
                    typ='float';v=float(v)
                items.append(json.dumps({'option':key,typ:v,'set':True}))
            return '\n\n'.join(items)
        if args[0]=='eval' and self.refusal:return self.refusal
        if args[0] in ('eval','repl'):
            reply=self.execute(args[1])
            if not reply['ok'] or reply['errors']:return 'error: '+reply['error']+reply['errors']
            return str(reply.get('returned')) if args[0]=='repl' else 'ok'
        raise AssertionError('Unexpected provider call '+repr(args))


@unittest.skipUnless(shutil.which('lua'),'plain Lua interpreter needed for inert API integration')
class InputSettingsTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.directory=Path(self.temp.name);self.provider=LuaProvider(self.directory)
        self.stack=contextlib.ExitStack();self.stack.enter_context(patch.dict(os.environ,{'XDG_CONFIG_HOME':str(self.directory/'config'),'XDG_STATE_HOME':str(self.directory/'state')}))
        self.stack.enter_context(patch.object(m,'hypr',side_effect=self.provider.hypr))
        self.stack.enter_context(patch.object(m,'catalog',return_value={'gb':['','intl'],'us':['','dvorak'],'de':['','nodeadkeys']}))
        self.stack.enter_context(patch.object(m,'device_info',side_effect=self.provider.get_devices));m.DEADLINE=None
    def tearDown(self):self.stack.close();self.provider.close();self.temp.cleanup()
    def request(self,changes):return {'changes':changes,'fingerprint':m.snapshot()['fingerprint'],'requestId':'fixture'}
    def apply(self,changes=None):return m.preview(self.request(changes or {'sensitivity':0.3}))
    def confirm(self,result):return m.complete(result['pending']['token'],True)
    def test_native_ranges_and_external_precision_are_not_silently_clamped(self):
        for changes in [{'repeatRate':0,'repeatDelay':0},{'repeatRate':200,'repeatDelay':2000},{'repeatDelay':333},{'sensitivity':0.25,'mouseScrollFactor':0.17,'touchpadScrollFactor':0}]:
            with self.subTest(changes=changes):
                p=self.apply(changes);self.assertEqual(p['state'],'preview')
                for key,value in changes.items():self.assertEqual(p['effective'][key],value)
                self.assertTrue(m.complete(p['pending']['token'],False)['ok'])
    def test_get_reads_runtime_not_saved_and_does_not_write(self):
        data=m.snapshot();self.assertEqual(data['effective']['layout'],'gb');self.assertFalse(m.path_config().exists());self.assertFalse(m.path_state().exists())
        self.assertTrue(all(c[0]!='eval' for c in self.provider.calls))
    def test_preview_then_confirm_saves_only_confirmed_fields(self):
        p=self.apply();self.assertTrue(p['ok']);self.assertEqual(p['state'],'preview');self.assertFalse(m.path_config().exists())
        final=self.confirm(p);self.assertEqual(final['state'],'applied-verified');self.assertTrue(final['persisted'])
        self.assertEqual(m.read_json(m.path_config())['preferences'],{'sensitivity':0.3});self.assertEqual(m.path_config().stat().st_mode&0o777,0o600)
    def test_cached_legacy_qml_can_read_actual_values_but_cannot_apply_old_payload(self):
        output=io.StringIO()
        with contextlib.redirect_stdout(output):code=m.main(['input-settings.py','get'])
        data=json.loads(output.getvalue());self.assertEqual(code,0);self.assertEqual(data['preferences'],data['effective'])
        output=io.StringIO()
        with contextlib.redirect_stdout(output):code=m.main(['input-settings.py','apply',json.dumps(data['preferences'])])
        data=json.loads(output.getvalue());self.assertEqual(code,1);self.assertFalse(data['ok']);self.assertTrue(data['error']);self.assertFalse(m.path_config().exists())
    def test_all_scalar_controls_reach_fixed_global_options_and_revert(self):
        changes=dict(sensitivity=0.4,naturalScroll=True,tapToClick=False,repeatRate=30,repeatDelay=700,mouseNaturalScroll=True,mouseScrollFactor=1.3,touchpadScrollFactor=1.4,disableWhileTyping=False,leftHanded=True)
        for key,value in changes.items():
            with self.subTest(key=key):
                previous=self.provider.values();p=self.apply({key:value});self.assertEqual(p['state'],'preview');self.assertEqual(p['effective'][key],value)
                self.assertTrue(m.complete(p['pending']['token'],False)['ok']);self.assertEqual(self.provider.values(),previous)
        self.assertFalse(m.path_config().exists())
    def test_expiry_restores_without_python_or_qml(self):
        self.apply();self.provider.execute('expire()');self.assertEqual(m.snapshot()['effective']['sensitivity'],0.0);self.assertFalse(m.path_config().exists())
    def test_manual_revert_restores_and_never_saves(self):
        p=self.apply();r=m.complete(p['pending']['token'],False);self.assertEqual(r['state'],'rolled-back');self.assertFalse(m.path_config().exists())
    def test_confirmed_timer_expires_as_noop(self):
        self.confirm(self.apply());self.provider.execute('expire()');self.assertEqual(m.snapshot()['effective']['sensitivity'],0.3)
    def test_zero_exit_legacy_refusal_never_saves_or_changes_effective(self):
        previous=self.provider.values();self.provider.refusal="keyword can't work with non-legacy parsers. Use eval."
        r=self.apply();self.assertFalse(r['ok']);self.assertEqual(r['cause'],'rejected');self.assertEqual(r['state'],'rejected');self.assertFalse(m.path_config().exists());self.assertEqual(self.provider.values(),previous)
    def test_partial_backend_rejection_rolls_back_accepted_members(self):
        self.provider.execute('rejectKeys["input:touchpad:tap-to-click"]=true')
        r=self.apply({'sensitivity':0.3,'tapToClick':False});self.assertFalse(r['ok']);self.assertEqual(r['effective']['sensitivity'],0.0);self.assertTrue(r['effective']['tapToClick']);self.assertFalse(m.path_config().exists())
    def test_bad_values_and_lua_injection_rejected_before_submit(self):
        for change in [{'sensitivity':float('nan')},{'repeatRate':True},{'sensitivity':True},{'sensitivity':1.25},{'mouseScrollFactor':-0.1}, {'layout':'us"});os.execute("false")','variant':'','usFallback':False},{'layout':'de','variant':'dvorak','usFallback':True},{'device':'other'}]:
            with self.subTest(change=change),self.assertRaises(m.InputError):m.preview(self.request(change))
        self.assertFalse(any(c[0]=='eval' for c in self.provider.calls))
    def test_layout_variant_and_keyboard_readback(self):
        p=self.apply({'layout':'de','variant':'nodeadkeys','usFallback':True});self.assertEqual(p['effective']['layout'],'de');self.assertEqual(p['effective']['variant'],'nodeadkeys');self.assertTrue(self.confirm(p)['ok'])
    def test_keyboard_actual_layout_mismatch_is_failure(self):
        self.provider.update_keyboard=False;r=self.apply({'layout':'de','variant':'','usFallback':True});self.assertFalse(r['ok']);self.assertEqual(r['cause'],'readback-mismatch');self.assertFalse(m.path_config().exists())
    def test_custom_keymap_is_preserved(self):
        self.provider.execute('options["input:kb_file"]="/fixture/custom.xkb"')
        with self.assertRaisesRegex(m.InputError,'custom keymap'):self.apply({'layout':'de','variant':'','usFallback':True})
    def test_keyboard_device_override_disables_global_layout_edit(self):
        self.provider.devices[0]['layout']='de';self.provider.update_keyboard=False
        self.assertFalse(m.snapshot()['capabilities']['layout'])
    def test_us_fallback_is_canonical(self):
        p=self.apply({'layout':'us','variant':'','usFallback':True});self.assertFalse(p['effective']['usFallback']);r=self.confirm(p);self.assertFalse(r['saved']['usFallback']);self.assertFalse(r['externalConflict'])
    def test_repeat_delay_uses_same_value_refresh_anchor(self):
        p=self.apply({'repeatDelay':700});record=m.read_json(m.path_state()/'preview.json');self.assertEqual(record['proposed']['input:repeat_rate'],25);self.assertEqual(p['effective']['repeatDelay'],700)
    def test_touchpad_only_controls_disabled_on_mouse(self):
        self.provider.devices=[self.provider.devices[2]]
        self.assertFalse(m.snapshot()['capabilities']['tapToClick'])
        with self.assertRaises(m.InputError):self.apply({'tapToClick':False})
    def test_mouse_scroll_does_not_claim_touchpad_only_support(self):
        self.provider.devices=[self.provider.devices[1]];self.assertFalse(m.snapshot()['capabilities']['mouseNaturalScroll'])
    def test_device_disappearance_invalidates_confirmation(self):
        p=self.apply();self.provider.devices.pop();r=self.confirm(p);self.assertFalse(r['ok']);self.assertEqual(r['state'],'external-change');self.assertFalse(m.path_config().exists())
    def test_hotplug_or_external_change_invalidates_old_request(self):
        request=self.request({'sensitivity':0.3});self.provider.execute('options["input:sensitivity"]=0.2')
        with self.assertRaisesRegex(m.InputError,'changed'):m.preview(request)
        self.assertEqual(m.snapshot()['effective']['sensitivity'],0.2)
    def test_external_edit_between_snapshot_and_submit_is_atomically_refused(self):
        original=m.arm_preview
        def changed(*args):
            self.provider.execute('options["input:sensitivity"]=0.7')
            return original(*args)
        with patch.object(m,'arm_preview',side_effect=changed):r=self.apply()
        self.assertEqual(r['state'],'stale');self.assertFalse(r['ok']);self.assertEqual(r['effective']['sensitivity'],0.7);self.assertFalse(m.path_config().exists())
    def test_unknown_version_or_custom_legacy_store_cannot_be_overwritten(self):
        for data in [{'schemaVersion':99,'verified':True,'preferences':{'sensitivity':0.2}},{'custom':'preserve'},[]]:
            m.atomic(m.path_config(),data);before=m.path_config().read_bytes()
            with self.assertRaises(m.InputError):self.apply()
            self.assertEqual(m.path_config().read_bytes(),before)
    def test_custom_preference_metadata_is_preserved(self):
        m.atomic(m.path_config(),dict(schemaVersion=2,verified=True,preferences={'sensitivity':0.2},custom='preserve'))
        before=m.path_config().read_bytes()
        with self.assertRaises(m.InputError):self.apply()
        self.assertEqual(m.path_config().read_bytes(),before)
    def test_external_change_during_preview_not_overwritten(self):
        p=self.apply();self.provider.execute('options["input:sensitivity"]=0.7');self.provider.execute('expire()')
        self.assertEqual(m.snapshot()['effective']['sensitivity'],0.7);self.assertFalse(m.path_config().exists())
        with self.assertRaises(m.InputError):self.confirm(p)
    def test_stale_token_and_multiple_rapid_requests(self):
        p=self.apply()
        with self.assertRaises(m.InputError):self.apply({'sensitivity':0.5})
        with self.assertRaises(m.InputError):m.complete('0'*32,True)
        self.assertEqual(m.snapshot()['effective']['sensitivity'],0.3)
    def test_preview_cannot_apply_without_safety_timer(self):
        self.provider.execute('timerMissing=true');r=self.apply();self.assertFalse(r['ok']);self.assertEqual(r['effective']['sensitivity'],0.0);self.assertFalse(m.path_config().exists())
    def test_readback_mismatch_does_not_persist(self):
        original=m.option_values;calls=0
        def mismatch():
            nonlocal calls
            result=original();calls+=1
            if calls==3:result['input:sensitivity']=0.6
            return result
        with patch.object(m,'option_values',side_effect=mismatch):r=self.apply()
        self.assertFalse(r['ok']);self.assertFalse(m.path_config().exists())
    def test_missing_loaded_restore_hook_never_claims_persistence(self):
        self.provider.execute('senomy_input_restore_v2=nil');p=self.apply();r=self.confirm(p)
        self.assertFalse(r['ok']);self.assertEqual(r['state'],'applied-not-persisted');self.assertFalse(m.path_config().exists());self.assertEqual(r['effective']['sensitivity'],0.3)
    def test_persistence_failure_is_distinct_and_not_success(self):
        p=self.apply();original=m.atomic
        def fail(path,value):
            if path==m.path_config():raise OSError('inert read-only store')
            original(path,value)
        with patch.object(m,'atomic',side_effect=fail):r=self.confirm(p)
        self.assertEqual(r['state'],'applied-persistence-failed');self.assertFalse(r['ok']);self.assertEqual(r['effective']['sensitivity'],0.3);self.assertFalse(m.path_config().exists())
    def test_invalid_preferences_preserved_and_block_apply(self):
        m.atomic(m.path_config(),{'schemaVersion':2,'verified':True,'preferences':{'sensitivity':8}});before=m.path_config().read_bytes()
        with self.assertRaises(m.InputError):self.apply()
        self.assertEqual(m.path_config().read_bytes(),before)
    def test_legacy_false_success_preferences_not_automatically_restored(self):
        m.atomic(m.path_config(),{'sensitivity':0.9,'layout':'us'});r=m.restore();self.assertEqual(r['state'],'not-restored');self.assertEqual(r['effective']['sensitivity'],0.0)
        final=self.confirm(self.apply());self.assertTrue(final['ok']);self.assertTrue(list(m.path_state().glob('legacy-input-*.json')))
    def test_persistence_lifecycle_restores_only_owned_confirmed_fields(self):
        self.confirm(self.apply());self.provider.execute('options["input:sensitivity"]=0.0;options["input:repeat_rate"]=32')
        r=m.restore();self.assertEqual(r['state'],'restored-verified');self.assertEqual(r['effective']['sensitivity'],0.3);self.assertEqual(r['effective']['repeatRate'],32)
    def test_restore_rejection_does_not_rewrite_saved_file(self):
        self.confirm(self.apply());before=m.path_config().read_bytes();self.provider.execute('options["input:sensitivity"]=0.0');self.provider.refusal='error: inert rejection'
        r=m.restore();self.assertFalse(r['ok']);self.assertEqual(m.path_config().read_bytes(),before)
    def test_symlink_preference_never_followed(self):
        m.path_config().parent.mkdir(parents=True);victim=self.directory/'victim';victim.write_text('private');m.path_config().symlink_to(victim)
        with self.assertRaises(m.InputError):self.apply()
        self.assertEqual(victim.read_text(),'private')
    def test_malformed_preview_state_preserved_and_no_mutation(self):
        m.atomic(m.path_state()/'preview.json',[])
        with self.assertRaises(m.InputError):m.snapshot()
        self.assertEqual(m.read_json(m.path_state()/'preview.json'),[])
    def test_restore_hook_on_initial_load_and_reload_once(self):
        self.confirm(self.apply())
        source=str(Path(__file__).parents[3]/'hyprland.lua')
        setup='\ncallbacks={};restoreCount=0\nlocal noop;noop=setmetatable({},{__index=function()return noop end,__call=function()return noop end})\nsetmetatable(hl,{__index=function()return noop end})\nlocal oldconfig=hl.config\nhl.config=function(t)if t.input then local subset={input={}};for k,v in pairs(t.input)do if k=="touchpad" then subset.input.touchpad=v elseif options["input:"..k]~=nil then subset.input[k]=v end end;oldconfig(subset)end end\nhl.on=function(name,fn)callbacks[name]=fn end\nhl.exec_cmd=function(cmd)if cmd:find("senomy-input-settings",1,true) and cmd:sub(-8)==" restore" then restoreCount=restoreCount+1 end end\n'
        self.assertTrue(self.provider.execute(setup)['ok'])
        for count in (1,2):
            self.assertTrue(self.provider.execute('dofile('+m.lua(source)+');callbacks["hyprland.start"]();callbacks["config.reloaded"]()')['ok'])
            self.assertEqual(self.provider.execute('return restoreCount')['returned'],count)
            self.assertTrue(m.snapshot()['persistenceReady'])
            self.assertEqual(m.restore()['state'],'restored-verified')
            self.assertEqual(m.snapshot()['effective']['sensitivity'],0.3)
    def test_reload_helper_path_is_posix_shell_quoted(self):
        import shlex
        source=str(Path(__file__).parents[3]/'hyprland.lua')
        home="/fixture/user name's $(untrusted); path"
        setup='local noop;noop=setmetatable({},{__index=function()return noop end,__call=function()return noop end});setmetatable(hl,{__index=function()return noop end});hl.config=function()end;callbacks={};hl.on=function(n,f)callbacks[n]=f end;hl.exec_cmd=function(cmd)lastCommand=cmd end;local original=os.getenv;os.getenv=function(n)if n=="HOME"then return '+m.lua(home)+' end;return original(n)end'
        self.provider.execute(setup)
        data=self.provider.execute('dofile('+m.lua(source)+');callbacks["config.reloaded"]();return lastCommand')
        self.assertTrue(data['ok']);self.assertEqual(shlex.split(data['returned']),[home+'/.local/bin/senomy-input-settings','restore'])
    def test_direct_executable_entry_returns_structured_failure_without_live_provider(self):
        helper=Path(__file__).parents[1]/'scripts/input-settings.py'
        self.assertTrue(os.access(helper,os.X_OK))
        bindir=self.directory/'bin';bindir.mkdir();(bindir/'python3').symlink_to(shutil.which('python3'))
        fake=bindir/'hyprctl';fake.write_text('#!/usr/bin/python3\nimport sys\nsys.exit(1)\n');fake.chmod(0o755)
        env=dict(os.environ,PATH=str(bindir));[env.pop(k,None) for k in ['HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY','DISPLAY','DBUS_SESSION_BUS_ADDRESS']]
        r=subprocess.run([str(helper),'get'],env=env,capture_output=True,text=True,timeout=5)
        self.assertEqual(r.returncode,1);data=json.loads(r.stdout);self.assertFalse(data['ok']);self.assertFalse(data['available'])
    def test_process_failure_missing_binary_timeout_and_transport(self):
        with patch.object(m.subprocess,'run',return_value=subprocess.CompletedProcess([],1,'','inert failure')):
            with self.assertRaises(m.InputError):m.run(['inert'])
        for failure in (FileNotFoundError(),subprocess.TimeoutExpired('inert',1),OSError()):
            with patch.object(m.subprocess,'run',side_effect=failure),self.assertRaises(m.InputError):m.run(['inert'])
    def test_malformed_or_missing_or_wrong_type_readback(self):
        for text in ['error: no such option','{}','{"option":"input:sensitivity","float":true}','{"option":"input:sensitivity","float":0.3}']:
            with patch.object(m,'hypr',return_value=text),self.assertRaises(m.InputError):m.option_values()
    def test_lua_string_encoder_does_not_execute_data(self):
        value='"; error("injected"); --\nλ'
        self.assertEqual(self.provider.execute('return '+m.lua(value))['returned'],value)
    def test_locked_transaction_refuses_second_writer(self):
        with m.locked(), self.assertRaises(m.InputError):
            with m.locked():pass
    def test_confirmation_after_expiry_rejected(self):
        p=self.apply();self.provider.execute('expire()')
        with self.assertRaises(m.InputError):self.confirm(p)
    def test_float_readback_rounding_does_not_break_rollback(self):
        p=self.apply();self.provider.execute('options["input:sensitivity"]=0.30000001192092896');r=m.complete(p['pending']['token'],False)
        self.assertEqual(r['state'],'rolled-back');self.assertEqual(r['effective']['sensitivity'],0.0)


if __name__=='__main__':unittest.main(verbosity=2)
