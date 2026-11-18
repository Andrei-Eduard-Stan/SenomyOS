from pathlib import Path
import importlib.util,unittest,tempfile,os,json,stat,subprocess,hashlib
from unittest.mock import patch
S=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('wiki_tools',S/'scripts/wiki-tools.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class WikiTools(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name);self.env=patch.dict(os.environ,{'XDG_DATA_HOME':str(self.root/'data'),'XDG_CONFIG_HOME':str(self.root/'config')});self.env.start()
 def tearDown(self):self.env.stop();self.temp.cleanup()
 def test_unicode_roundtrip_edit_favorite_remove(self):
  text="𓆩♡𓆪 🦋\n(つ≧▽≦)つ `$(touch /tmp/never)` <b>literal</b>"
  result=m.mutate('save',dict(name='Test',category='Personal',text=text));e=next(e for e in result['entries'] if e['custom']);self.assertEqual(e['text'],text)
  p=m.data_root()/'emoticons.json';self.assertEqual(stat.S_IMODE(p.stat().st_mode),0o600)
  self.assertTrue(next(x for x in m.mutate('favorite',{'id':e['id']})['entries'] if x['id']==e['id'])['favorite'])
  e['text']='edited\nexact';m.mutate('save',e);self.assertEqual(m.read_store()['entries'][0]['text'],e['text'])
  m.mutate('remove',{'id':e['id']});self.assertEqual(m.read_store()['entries'],[])
 def test_corruption_preserved_and_symlink_rejected(self):
  r=m.data_root();r.mkdir(parents=True);p=r/'emoticons.json';p.write_text('{bad');before=p.read_bytes()
  with self.assertRaises(ValueError):m.mutate('save',{'name':'x','text':'x'})
  self.assertEqual(p.read_bytes(),before);p.unlink();target=self.root/'outside';target.write_text('preserve');p.symlink_to(target)
  with self.assertRaises(ValueError):m.read_store()
  self.assertEqual(target.read_text(),'preserve')
 def test_bounds(self):
  for e in [{'name':'x','text':''},{'name':'x','text':'a'*2001},{'name':'x','text':'bad\x00'},{'name':'x','text':'okay','id':'../../bad'}]:
   with self.assertRaises(ValueError):m.validate_entry(e)
 def test_static_labels_loops_do_not_execute(self):
  p=self.root/'config.lua';p.write_text('''local mainMod = "SUPER"
local terminal = "kitty"
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
for workspace = 1, 3 do
 local key = workspace % 10
 hl.bind(mainMod .. " + " .. key, hl.dsp.focus({workspace = workspace}))
end
os.execute("touch /tmp/senomy-wiki-must-not-run")
''');labels=m.source_labels(p);self.assertEqual(labels[((64,'Q'),'exec_cmd')][0],'Open terminal');self.assertEqual(labels[((64,'3'),'focus')][0],'Focus workspace 3')
 def test_runtime_all_rows_flags_and_unknown(self):
  fixture=[dict(modmask=65,key='2',dispatcher='HL.Dispatcher(exec_cmd)',arg='99',submap='resize',release=True,repeat=True),dict(modmask=0,key='',keycode=33,dispatcher='other',arg='')]
  with patch.object(m.shutil,'which',return_value='/usr/bin/hyprctl'),patch.object(m.subprocess,'run',return_value=subprocess.CompletedProcess([],0,json.dumps(fixture),'')):
   d=m.shortcuts()
  self.assertEqual(d['count'],2);r=next(e for e in d['bindings'] if e['key']=='2');self.assertIn('On release',r['flags']);self.assertIn('Repeats',r['flags']);self.assertEqual(r['submap'],'resize');self.assertIn('Super + Shift + 2',r['chord']);self.assertEqual(r['labelSource'],'Runtime dispatcher')
 def test_clipboard_preserves_exact_text_without_shell(self):
  bindir=self.root/'bin';bindir.mkdir();fake=bindir/'wl-copy';fake.write_text('#!/usr/bin/env python3\nimport sys,os\nfrom pathlib import Path\nPath(os.environ["COPY_DEST"]).write_bytes(sys.stdin.buffer.read())\n');fake.chmod(0o755)
  text='𓆩♡𓆪\n$(literal) `literal`';dest=self.root/'copy'
  env=dict(os.environ,PATH=str(bindir)+':'+os.environ['PATH'],COPY_DEST=str(dest))
  r=subprocess.run(['python3','-B',str(S/'scripts/wiki-tools.py'),'copy'],input=json.dumps({'text':text}),text=True,capture_output=True,env=env)
  self.assertEqual(r.returncode,0,r.stdout);self.assertEqual(dest.read_text(),text)
if __name__=='__main__':unittest.main()
