from pathlib import Path
import importlib.util,json,os,tempfile,unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('automatic',Path(__file__).parents[1]/'scripts/osk-automatic.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Automatic(unittest.TestCase):
 def test_strict_boolean_schema_and_no_text(self):
  value={'ok':True,'protocol':1,'physicalKeyboard':False,'textActive':True,'inputMethod':True,'locked':False,'focusEpoch':4,'surroundingText':'private'}
  self.assertNotIn('surroundingText',m.sanitize(value));self.assertTrue(m.sanitize(value)['ok'])
  for k in m.FIELDS:
   changed=dict(value);changed[k]='false';self.assertFalse(m.sanitize(changed)['ok'])
  for epoch in [-1,True,1.5,2**53]:
   changed=dict(value,focusEpoch=epoch);self.assertFalse(m.sanitize(changed)['ok'])
 def test_preference_persistence_and_invalid_fails_closed(self):
  with tempfile.TemporaryDirectory() as d,patch.dict(os.environ,{'XDG_CONFIG_HOME':d}):
   self.assertEqual(m.mode(),'auto');m.save('manual');self.assertEqual(m.mode(),'manual');self.assertEqual(m.preference_path().stat().st_mode&0o777,0o600)
   m.save('auto');self.assertEqual(m.mode(),'auto');m.preference_path().write_text('bad');self.assertEqual(m.mode(),'manual')
   with self.assertRaises(ValueError):m.save('arbitrary')
 def test_state_does_not_trust_unknown_plugin(self):
  with patch.object(m.locks,'request',return_value='{}'):self.assertFalse(m.state()['ok'])
  with patch.object(m.locks,'request',side_effect=OSError):self.assertFalse(m.state()['ok'])
if __name__=='__main__':unittest.main()
