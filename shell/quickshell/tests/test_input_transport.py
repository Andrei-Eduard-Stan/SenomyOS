"""Production InputSettings Process transport, private bus/home/offscreen UI.
OSK/IME providers are inert siblings; no session or hardware endpoint exists.
"""
from pathlib import Path
import json,os,shutil,subprocess,tempfile,unittest
ROOT=Path(__file__).parents[1]
FIXTURE='''import QtQuick
import Quickshell
import "services"
Scope {
    id:root
    property int phase:0
    property int ticks:0
    InputSettings { id:settings }
    Component.onCompleted:settings.preferences.active=true
    Timer { interval:25; repeat:true; running:true; onTriggered:{
        root.ticks++;
        const p=settings.preferences;
        if(root.ticks>1500){console.log("FAIL deadline");Qt.quit();return;}
        if(p.busy)return;
        const mode=Quickshell.env("WP02_CASE");
        if(mode==="missing" || mode==="malformed"){
            if(p.state!=="transport-failed" || p.available)console.log("FAIL unavailable");
            else console.log("PASS production transport "+mode);
            Qt.quit();return;
        }
        if(root.phase===0){
            if(!p.available || p.layout!=="gb"){console.log("FAIL initial");Qt.quit();return;}
            root.phase=1;p.edit("sensitivity",0.5);p.applyDraft("pointer");return;
        }
        if(mode==="timeout"){
            if(p.state!=="transport-failed" || root.ticks<1000)console.log("FAIL timeout state");
            else console.log("PASS production transport timeout; navigation/event timer stayed responsive");
        } else if(p.state!=="rejected" || p.sensitivity!==0 || p.draft.sensitivity!==0 || p.message.indexOf("rejected")<0 || p.persistence==="saved")console.log("FAIL false success");
        else console.log("PASS production transport rejection; actual state retained; no saved success");
        Qt.quit();
    }}
}
'''
HELPER='''import os,json,sys,time
mode=os.environ['WP02_CASE'];op=sys.argv[1];identity=sys.argv[2] if op=='get' else json.loads(sys.argv[2])['requestId']
if mode=='malformed':print('{}');raise SystemExit(0)
if mode=='timeout' and op=='apply':time.sleep(40)
v=dict(sensitivity=0,naturalScroll=False,tapToClick=True,layout='gb',variant='',usFallback=True,repeatRate=25,repeatDelay=600,mouseNaturalScroll=False,mouseScrollFactor=1,touchpadScrollFactor=1,disableWhileTyping=True,leftHanded=False)
r=dict(schemaVersion=2,ok=op=='get',state='observed' if op=='get' else 'rejected',message='' if op=='get' else 'Hyprland rejected the change. No preference was saved.',available=True,effective=v,capabilities={k:True for k in v},devices=[],fingerprint='fixture',layouts=['gb','us'],variants={'gb':[''],'us':['']},saved={},persistence='not-saved',firstRun=False,pending=dict(state='none',token=''),requestId=identity)
print(json.dumps(r));raise SystemExit(0 if r['ok'] else 1)
'''

class InputTransportTests(unittest.TestCase):
    def run_case(self,case):
        with tempfile.TemporaryDirectory(prefix='senomy-wp02-transport-') as directory:
            p=Path(directory);(p/'services').mkdir();(p/'scripts').mkdir();(p/'runtime').mkdir(mode=0o700)
            for name in ['InputSettings.qml','InputPreferences.qml']:shutil.copy2(ROOT/'services'/name,p/'services'/name)
            stubs={'OskAutomatic.qml':'import QtQuick\nQtObject {property var controller; function textFocusEvent(active) {}}',
                   'OskController.qml':'import QtQuick\nQtObject {property var provider; property var capabilities; signal releasePrimaryFocusRequested(); function started(serial){} function failed(serial){} function exited(serial,success){} function cancelStart(){} function cancelStop(){}}',
                   'OskAdapter.qml':'import QtQuick\nQtObject {signal textFocusEvent(bool active); signal geometryChanged(); signal providerStarted(int serial); signal providerFailed(int serial); signal providerExited(int serial,bool successful)}'}
            for name,text in stubs.items():(p/'services'/name).write_text(text)
            (p/'scripts/input-settings.py').write_text(HELPER)
            for name in ['osk-capabilities.py','native-input-tools.py']:(p/'scripts'/name).write_text('print(\'{"ok":false,"providerInstalled":false,"protocolState":"unknown","message":"Inert provider"}\')')
            (p/'fixture.qml').write_text(FIXTURE)
            env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(p/'runtime'),XDG_CONFIG_HOME=str(p/'config'),XDG_STATE_HOME=str(p/'state'),WP02_CASE=case)
            for key in ['HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY','DISPLAY','DBUS_SESSION_BUS_ADDRESS']:env.pop(key,None)
            if case=='missing':(p/'empty-bin').mkdir();env['PATH']=str(p/'empty-bin')
            result=subprocess.run(['/usr/bin/dbus-run-session','--dbus-daemon=/usr/bin/dbus-daemon','--','/usr/bin/qs','--path',str(p/'fixture.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=43)
            log=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,log);self.assertIn('PASS production transport',log);self.assertNotIn('FAIL ',log)
            self.assertFalse((p/'config/senomyos/input.json').exists())
            print(next(line for line in log.splitlines() if 'PASS production transport' in line))
    def test_rejection(self):self.run_case('rejected')
    def test_missing_interpreter(self):self.run_case('missing')
    def test_malformed_receipt(self):self.run_case('malformed')
    def test_bounded_unresponsive_helper(self):self.run_case('timeout')

if __name__=='__main__':unittest.main(verbosity=2)
