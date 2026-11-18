#!/usr/bin/env python3
"""Exercise installed TLP's two decision functions with ALL I/O helpers inert.
No tlp executable, service, actual source change or kernel write is invoked.
"""
from pathlib import Path
import hashlib
import subprocess
import unittest
SOURCE=Path('/usr/share/tlp/tlp-func-base')

@unittest.skipUnless(SOURCE.is_file(),'Installed TLP source absent')
class InstalledTlp(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source=SOURCE.read_text()
        if hashlib.sha256(source.encode()).hexdigest() != 'cebcccbc791a5808aeecb9f1c4190532ea286e12231576d956b5331d86c74107':
            raise unittest.SkipTest('Review changed TLP source before executing isolated function copies')
        start=source.index('assigned_profile () {');end=source.index('\nnotify_profile_daemon () {',start);cls.functions=source[start:end]
        # Allow only these two functions; their I/O dependencies are stubs.
        assert cls.functions.count('\nget_next_power_profile () {')==1
    def decision(self,command,source,last_source,last):
        script='''PS_AC=0; PS_BAT=1; PS_UNKNOWN=128; PP_PRF=0; PP_BAL=1; PP_SAV=2; PP_NONE=255
TLP_AUTO_SWITCH=2; TLP_PROFILE_AC=PRF; TLP_PROFILE_BAT=BAL; TLP_PROFILE_DEFAULT=; TLP_PERSISTENT_DEFAULT=0
id2pp(){ case "$1" in PRF) echo 0;; BAL) echo 1;; SAV) echo 2;; *) echo 255;; esac; }
echo_debug(){ :; }
is_laptop(){ return 0; }
get_sys_power_supply(){ _syspwr=$fixture_source; }
read_saved_power_profile(){ _ps_last=$fixture_last_source; _pp_last=$fixture_last; }
get_manual_mode(){ return 1; }
clear_manual_mode(){ fixture_manual=cleared; }
set_manual_mode(){ fixture_manual=$1; }
'''+self.functions+'''\nfixture_source=$2; fixture_last_source=$3; fixture_last=$4
get_next_power_profile "$1"
printf '%s/%s' "$_pp_next" "${fixture_manual:-unchanged}"
'''
        p=subprocess.run(['/bin/bash','--noprofile','--norc','-c',script,'fixture',command,str(source),str(last_source),str(last)],text=True,capture_output=True,timeout=3,env={'PATH':'/usr/bin:/bin','LC_ALL':'C'})
        self.assertEqual(p.returncode,0,p.stderr);return p.stdout
    def test_default_battery_to_ac(self):self.assertEqual(self.decision('auto',0,1,1),'0/unchanged')
    def test_default_ac_to_battery(self):self.assertEqual(self.decision('auto',1,0,0),'1/unchanged')
    def test_saver_override_survives_ac_event(self):self.assertEqual(self.decision('auto',0,1,2),'2/unchanged')
    def test_same_source_keeps_selection(self):self.assertEqual(self.decision('auto',0,0,1),'1/unchanged')
    def test_resume_with_source_change(self):self.assertEqual(self.decision('resume',1,0,0),'1/unchanged')
    def test_init_reestablishes_source_default(self):self.assertEqual(self.decision('init',0,1,2),'0/cleared')
    def test_start_reestablishes_source_default(self):self.assertEqual(self.decision('start',1,0,2),'1/cleared')
    def test_profile_selection_clears_manual(self):self.assertEqual(self.decision('performance',0,0,1),'0/cleared')
    def test_care_is_neutral_to_profile(self):self.assertEqual(self.decision('setcharge',1,1,1),'1/unchanged')

if __name__=='__main__':
    print('Installed source SHA256:',hashlib.sha256(SOURCE.read_bytes()).hexdigest()if SOURCE.exists()else 'absent');unittest.main(verbosity=2)
