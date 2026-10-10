from pathlib import Path
import os,json,subprocess,time
s=Path(__file__).parent;shell=s/'repo/shell/quickshell';e=dict(os.environ,**json.loads((s/'nested-env.json').read_text()),PATH=str(s)+':'+os.environ['PATH'],SENOMY_PRIVATE_OSK_TEST='1',SENOMY_PRIVATE_POINTER_TEST='1',XDG_CONFIG_HOME=str(s/'testconfig'),QT_IM_MODULE='wayland',QT_WAYLAND_TEXT_INPUT_PROTOCOL='zwp_text_input_v3')
pref=s/'testconfig/senomyos/osk.json';pref.parent.mkdir(parents=True,exist_ok=True);pref.write_text('{"mode":"auto"}')
path=shell/'osk-automatic-session-test.qml';log=(s/'session.log').open('w');p=subprocess.Popen(['qs','--path',str(path)],env=e,stdout=log,stderr=subprocess.STDOUT)
client=subprocess.Popen([str(s/'text-client')],env=e,stdin=subprocess.PIPE,stdout=subprocess.DEVNULL,stderr=(s/'client.log').open('w'))
evidence=[]
def report():
 try:return json.loads(subprocess.check_output(['qs','ipc','--path',str(path),'call','test','report'],env=e,text=True,stderr=subprocess.DEVNULL))
 except Exception:return {}
def wait(fn,label):
 for _ in range(150):
  r=report()
  if fn(r):evidence.append({'case':label,'state':r});print('PASS',label,flush=True);return r
  time.sleep(.04)
 raise AssertionError((label,report(),(s/'session.log').read_text()[-2000:]))
def ipc(*args):return subprocess.check_output(['hyprctl',*args],env=e,text=True)
def edit(active):
 client.stdin.write(b'1' if active else b'0');client.stdin.flush()
try:
 ipc('eval','hl.config({input={follow_mouse=0}})')
 ipc('eval','hl.device({name="wl_keyboard",enabled=false})')
 r=wait(lambda r:r.get('owned') and r.get('snapshot',{}).get('inputMethod') and not r.get('visible'),'keyboard-free session prearms hidden provider')
 edit(True)
 r=wait(lambda r:r.get('visible') and r.get('snapshot',{}).get('textActive'),'text-input-v3 enable automatically shows owned keyboard');pid=r['pid']
 edit(False);wait(lambda r:not r.get('visible') and not r.get('snapshot',{}).get('textActive'),'text-input-v3 disable automatically hides keyboard')
 edit(True);wait(lambda r:r.get('visible') and r.get('pid')==pid,'second focus reuses same owned keyboard')
 subprocess.run(['qs','ipc','--path',str(path),'call','test','hide'],env=e,check=True)
 wait(lambda r:not r.get('visible'),'manual hide respected');time.sleep(.4);assert not report()['visible']
 edit(False);edit(True);wait(lambda r:r.get('visible'),'next text focus opens after dismissal')
 ipc('reload');ipc('eval','hl.config({input={follow_mouse=0}})')
 wait(lambda r:not r.get('visible') and r.get('snapshot',{}).get('physicalKeyboard'),'physical keyboard becoming usable hides automatic OSK')
 ipc('eval','hl.device({name="wl_keyboard",enabled=false})')
 wait(lambda r:r.get('visible') and not r.get('snapshot',{}).get('physicalKeyboard'),'keyboard becoming unavailable resumes automatic OSK')
 subprocess.run(['qs','ipc','--path',str(path),'call','test','mode','manual'],env=e,check=True)
 wait(lambda r:r.get('mode')=='manual' and not r.get('visible'),'manual preference disables automatic opening')
 subprocess.run(['qs','ipc','--path',str(path),'call','test','manualOpen'],env=e,check=True)
 wait(lambda r:r.get('visible'),'manual show remains available');edit(False)
 time.sleep(.3);assert report()['visible'];print('PASS manual keyboard survives text blur',flush=True)
 (s/'session-evidence.json').write_text(json.dumps(evidence,indent=2))
finally:
 p.terminate();p.wait(timeout=5);client.terminate();client.wait(timeout=5);log.close()
