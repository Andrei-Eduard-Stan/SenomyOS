from pathlib import Path
import os,json,subprocess,time
s=Path(__file__).parent;shell=s/'repo/shell/quickshell';e=dict(os.environ,**json.loads((s/'nested-env.json').read_text()),PATH=str(s)+':'+os.environ['PATH'],SENOMY_PRIVATE_OSK_TEST='1',SENOMY_PRIVATE_POINTER_TEST='1',XDG_CONFIG_HOME=str(s/'testconfig'),QT_IM_MODULE='wayland',QT_WAYLAND_TEXT_INPUT_PROTOCOL='zwp_text_input_v3')
pref=s/'testconfig/senomyos/osk.json';pref.parent.mkdir(parents=True,exist_ok=True);pref.write_text('{"mode":"auto"}')
held=subprocess.Popen([str(s/'wvkbd-mobintl'),'--senomy-resize','--senomy-auto-focus','--no-popup'],env=e,stdin=subprocess.PIPE,stdout=(s/'held-ime.log').open('w'),stderr=subprocess.DEVNULL)
time.sleep(.3)
path=shell/'osk-automatic-session-test.qml';log=(s/'existing-ime-session.log').open('w');p=subprocess.Popen(['qs','--path',str(path)],env=e,stdout=log,stderr=subprocess.STDOUT)
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
 raise AssertionError((label,report(),(s/'existing-ime-session.log').read_text()[-2000:]))
def ipc(*args):return subprocess.check_output(['hyprctl',*args],env=e,text=True)
def edit(active):
 client.stdin.write(b'1' if active else b'0');client.stdin.flush()
try:
 ipc('eval','hl.config({input={follow_mouse=0}})');ipc('eval','hl.device({name="wl_keyboard",enabled=false})')
 wait(lambda r:(r.get('snapshot') or {}).get('inputMethod') and not r.get('owned'),'existing input method keeps ownership; no unnecessary OSK pre-arm')
 edit(True);wait(lambda r:r.get('owned') and r.get('visible'),'existing input method focus opens managed OSK')
 assert held.poll() is None
 edit(False);wait(lambda r:not r.get('visible'),'existing input method disable hides managed OSK')
 p.terminate();p.wait(timeout=5);time.sleep(.1)
 assert held.poll() is None and json.loads(ipc('senomy-osk-auto-state'))['inputMethod']
 print('PASS owned OSK exit preserves existing input method',flush=True)
 (s/'existing-ime-evidence.json').write_text(json.dumps(evidence,indent=2))
finally:
 for process in [p,client,held]:
  if process.poll() is None:process.terminate();process.wait(timeout=5)
 log.close()
