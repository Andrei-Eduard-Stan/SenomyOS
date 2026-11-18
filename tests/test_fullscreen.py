from pathlib import Path
import copy,importlib.util,json,os,re,stat,subprocess,tempfile,unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('senomy_fullscreen',ROOT/'components/desktop/scripts/senomy_fullscreen.py');m=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(m)
def window(address='0xabc',state=(0,0),monitor=0):return dict(address=address,pid=os.getpid(),initialTitle=address,initialClass='fixture',fullscreen=state[0],fullscreenClient=state[1],mapped=True,hidden=False,monitor=monitor)
class Fake(m.Fullscreen):
 def __init__(self,runtime,rows=None):
  super().__init__(runtime=runtime,session='fixture-session');self.rows=rows if rows is not None else [window()];self.active='0xabc';self.calls=[];self.provider='lua';self.fail=False;self.no_effect=False;self.changed_focus=False;self.verify_seconds=0
 def query(self,name):
  if name=='activewindow':return copy.deepcopy(next((w for w in self.rows if w['address']==self.active),{}))
  if name=='status':
   if self.changed_focus:self.active='0xdef'
   return {'configProvider':self.provider}
  if name=='clients':return copy.deepcopy(self.rows)
  raise AssertionError(name)
 def command(self,*args):
  if args[0]!='eval':raise AssertionError(args)
  pattern=r'window="address:(0x[0-9a-fA-F]+)",internal=([0-3]),client=([0-3]),action="set"'
  match=re.search(pattern,args[1]);assert match,args
  address,a,b=match.groups();self.calls.append((address,[int(a),int(b)]))
  if self.fail:raise m.FullscreenError('Rejected fixture request')
  if not self.no_effect:
   w=next(w for w in self.rows if w['address']==address);w['fullscreen']=int(a);w['fullscreenClient']=int(b)
  return 'ok'
class FullscreenTests(unittest.TestCase):
 def setUp(self):self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name);self.fake=Fake(self.root)
 def tearDown(self):self.temp.cleanup()
 def test_normal_roundtrips(self):
  for mode in ['fullscreen','immersive']:
   with self.subTest(mode=mode):
    entered=self.fake.toggle(mode);self.assertEqual(entered['state'],[2,2 if mode=='fullscreen' else 0]);self.assertFalse(entered['restored']);self.assertEqual(self.fake.toggle(mode)['state'],[0,0])
 def test_maximized_restored_for_each_mode(self):
  for mode in ['fullscreen','immersive']:
   self.fake.rows=[window(state=(1,1))];self.fake.toggle(mode);self.assertEqual(self.fake.toggle(mode)['state'],[1,1])
 def test_direct_mode_switch_keeps_original_restore(self):
  self.fake.rows=[window(state=(1,1))]
  self.assertEqual(self.fake.toggle('fullscreen')['state'],[2,2]);self.assertEqual(self.fake.toggle('immersive')['state'],[2,0]);self.assertEqual(self.fake.toggle('fullscreen')['state'],[2,2]);self.assertEqual(self.fake.toggle('fullscreen')['state'],[1,1])
 def test_state_machine_all_native_states(self):
  for i in range(4):
   for c in range(4):
    for mode in ['fullscreen','immersive']:
     desired,base,leave=m.transition([i,c],mode)
     self.assertEqual(base,[i&1,c&1] if i&2 else [i,c]);self.assertEqual(leave,bool(i&2) and bool(c&2)==(mode=='fullscreen'));self.assertEqual(desired,base if leave else [2,2 if mode=='fullscreen' else 0])
 def test_separate_output_windows_keep_separate_restore(self):
  self.fake.rows=[window(),window('0xdef',(1,1),1)]
  self.fake.toggle('fullscreen');self.fake.active='0xdef';self.fake.toggle('immersive');self.fake.active='0xabc';self.fake.toggle('fullscreen');self.assertEqual(m.states(self.fake.rows[1]),[2,0]);self.fake.active='0xdef';self.assertEqual(self.fake.toggle('immersive')['state'],[1,1])
 def test_window_moving_outputs_keeps_restore(self):
  self.fake.rows=[window(state=(1,1))];self.fake.toggle('immersive');self.fake.rows[0]['monitor']=1;self.assertEqual(self.fake.toggle('immersive')['state'],[1,1])
 def test_focus_race_targets_original_window(self):
  self.fake.rows=[window(),window('0xdef',monitor=1)];self.fake.changed_focus=True;self.fake.toggle('fullscreen');self.assertEqual(self.fake.calls,[('0xabc',[2,2])]);self.assertEqual(m.states(self.fake.rows[1]),[0,0])
 def test_explicit_window_does_not_need_focus(self):
  self.fake.rows.append(window('0xdef',monitor=1));self.fake.toggle('immersive','0xdef');self.assertEqual(self.fake.calls,[('0xdef',[2,0])]);self.assertEqual(self.fake.active,'0xabc')
 def test_external_exit_retires_previous_restore(self):
  self.fake.rows=[window(state=(1,1))];self.fake.toggle('fullscreen');self.fake.rows[0].update(fullscreen=0,fullscreenClient=0);self.fake.toggle('immersive');self.assertEqual(self.fake.toggle('immersive')['state'],[0,0])
 def test_reused_address_does_not_restore_old_window(self):
  self.fake.rows=[window(state=(1,1))];self.fake.toggle('fullscreen');self.fake.rows[0]['initialTitle']='new object';self.assertEqual(self.fake.toggle('fullscreen')['state'],[0,0])
 def test_native_external_fullscreen_and_combined_bits(self):
  for current,restored in [((2,2),[0,0]),((3,3),[1,1]),((2,0),[0,0])]:
   self.fake.rows=[window(state=current)];mode='fullscreen' if current[1]&2 else 'immersive';self.assertEqual(self.fake.toggle(mode)['state'],restored)
 def test_bad_target_and_injection_have_no_dispatch(self):
  for address in ['0x0','bad','0xabc\");os.execute("bad")']:
   with self.assertRaises(m.FullscreenError):self.fake.toggle('fullscreen',address)
  self.fake.active='missing'
  with self.assertRaises(m.FullscreenError):self.fake.toggle('fullscreen')
  self.assertFalse(self.fake.calls)
 def test_missing_window_does_not_fall_back_to_focus(self):
  with self.assertRaises(m.FullscreenError):self.fake.toggle('fullscreen','0xdef')
  self.assertFalse(self.fake.calls)
 def test_unsupported_provider_fails_closed(self):
  self.fake.provider='hyprlang'
  with self.assertRaises(m.FullscreenError):self.fake.toggle('fullscreen')
  self.assertFalse(self.fake.calls)
 def test_invalid_state_fails_closed(self):
  for value in [None,False,'2',-1,9]:
   self.fake.rows[0]['fullscreen']=value
   with self.assertRaises(m.FullscreenError):self.fake.toggle('fullscreen')
  self.assertFalse(self.fake.calls)
 def test_denied_and_unverified_requests_do_not_report_success(self):
  self.fake.fail=True
  with self.assertRaises(m.FullscreenError):self.fake.toggle('fullscreen')
  self.fake.fail=False;self.fake.no_effect=True
  with self.assertRaises(m.FullscreenError):self.fake.toggle('fullscreen')
  self.assertEqual(m.states(self.fake.rows[0]),[0,0])
 def test_private_corrupt_and_symlink_restore_state(self):
  self.fake.toggle('fullscreen');p=self.fake.store.path;self.assertEqual(stat.S_IMODE(p.stat().st_mode),0o600);self.fake.calls=[];p.write_text('{broken')
  with self.assertRaises(ValueError):self.fake.toggle('fullscreen')
  self.assertFalse(self.fake.calls);self.assertEqual(p.read_text(),'{broken');p.unlink();outside=self.root/'outside';outside.write_text('keep');p.symlink_to(outside)
  with self.assertRaises(OSError):self.fake.toggle('fullscreen')
  self.assertEqual(outside.read_text(),'keep');self.assertFalse(self.fake.calls)
 def test_symlink_directory_rejected_before_writes(self):
  other=self.root/'other';other.mkdir();(self.root/'senomyos').symlink_to(other,target_is_directory=True)
  with self.assertRaises(m.FullscreenError):self.fake.toggle('fullscreen')
  self.assertFalse(list(other.iterdir()));self.assertFalse(self.fake.calls)
 def test_stale_closed_window_entries_pruned(self):
  self.fake.toggle('fullscreen');self.fake.rows=[window('0xdef')];self.fake.active='0xdef';self.fake.toggle('immersive');self.assertEqual(set(self.fake.store.read()),{'0xdef'})
 def test_cli_launcher_process_and_persistent_mode_switch(self):
  client=self.root/'client.json';client.write_text(json.dumps(window()))
  executable=self.root/'hyprctl';executable.write_text('''#!/usr/bin/env python3
import sys,os,json,re
from pathlib import Path
p=Path(os.environ['FIXTURE_CLIENT']);w=json.loads(p.read_text())
a=sys.argv[1:]
if a==['-j','activewindow']:print(json.dumps(w))
elif a==['-j','clients']:print(json.dumps([w]))
elif a==['-j','status']:print('{"configProvider":"lua"}')
elif a[0]=='eval':
 m=re.search(r'window="address:(0x[0-9a-f]+)",internal=([0-3]),client=([0-3]),action="set"',a[1]);assert m and m[1]==w['address'];w.update(fullscreen=int(m[2]),fullscreenClient=int(m[3]));p.write_text(json.dumps(w));print('ok')
else:raise SystemExit(7)
''');executable.chmod(0o755)
  env=dict(os.environ,SENOMY_HYPRCTL_BIN=str(executable),XDG_RUNTIME_DIR=str(self.root),HYPRLAND_INSTANCE_SIGNATURE='cli',FIXTURE_CLIENT=str(client))
  for args,expected in [([], [2,2]),(['immersive'],[2,0]),(['immersive'],[0,0])]:
   result=subprocess.run(['bash',str(ROOT/'components/desktop/scripts/senomy-fullscreen'),*args],text=True,capture_output=True,env=env);self.assertEqual(result.returncode,0,result.stderr);self.assertEqual(m.states(json.loads(client.read_text())),expected)
if __name__=='__main__':unittest.main()
