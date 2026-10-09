from pathlib import Path
import subprocess,os,json,time,signal,threading,queue
s=Path(__file__).parent;e=dict(os.environ,**json.loads((s/'nested-env.json').read_text()),SENOMY_PRIVATE_POINTER_TEST='1')
def call(*args,env=e):return subprocess.check_output(['hyprctl',*args],env=env,text=True)
def monitors():return json.loads(call('-j','monitors'))[0]
def keyboards():return json.loads(call('-j','devices'))['keyboards']
def caps():return json.loads(call('senomy-caps-state'))
def waitfor(f):
 for _ in range(50):
  if f():return
  time.sleep(.04)
 raise AssertionError('State timeout')
events=[];states=[]
p=subprocess.Popen([str(s/'native/wvkbd-mobintl'),'--senomy-resize','--senomy-lock-sync','--no-popup','--landscape-layers','special'],env=e,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=(s/'native.log').open('w'),text=True,bufsize=1)
bridge=subprocess.Popen(['python3',str(s/'shell/quickshell/scripts/osk-lock-state.py'),'stream'],env=e,stdout=subprocess.PIPE,text=True,bufsize=1)
def native():
 for line in p.stdout:
  obj=json.loads(line);events.append(obj)
  if obj['event']=='caps-toggle':
   result=subprocess.run(['python3',str(s/'shell/quickshell/scripts/osk-lock-state.py'),'toggle'],env=e,capture_output=True,text=True);assert result.returncode==0,(result.stdout,result.stderr)

def state():
 for line in bridge.stdout:
  obj=json.loads(line);states.append(obj)
  if obj.get('available') and p.poll() is None:
   p.stdin.write('caps:'+str(int(obj['capsLock']))+'\n');p.stdin.flush()
threading.Thread(target=native,daemon=True).start();threading.Thread(target=state,daemon=True).start()
def geom():return [x for x in events if x['event']=='geometry'][-1]
def drag(x,y,ex,ey):
 m=monitors();subprocess.run([str(s/'pointer-driver'),str(m['width']),str(m['height']),str(x),str(y),str(ex),str(ey)],env=e,check=True);time.sleep(.15)
try:
 waitfor(lambda:events and caps()['available']);
 if caps()['capsLock']:call('senomy-caps-toggle');time.sleep(.1)
 g=geom();m=monitors();assert m['reserved'][3]==g['height']
 # Center grip moves, edges remain resize handles.
 drag(g['x']+g['width']//2,g['y']+10,g['x']+g['width']//2,g['y']-50);g=geom();assert g['y']<m['height']-g['height'];assert monitors()['reserved'][3]==m['height']-g['y'];print('PASS move grip/reservation',g,flush=True)
 drag(g['x']+g['width']-8,g['y']+g['height']//2,g['x']+g['width']-70,g['y']+g['height']//2);g=geom();assert g['width']<m['width']-80
 drag(g['x']+g['width']//2,g['y']+10,g['x']+g['width']//2+65,g['y']+35);g=geom();assert g['x']>0;print('PASS free horizontal/vertical movement and side resize',g,flush=True)
 # Toggle uses native state, independent of a stale shell visibility observation.
 for expected in [False,True,False,True]:
  p.send_signal(signal.SIGRTMIN);waitfor(lambda:geom()['visible']==expected)
  assert bool(monitors()['reserved'][3])==expected
 print('PASS repeated native visibility toggle',flush=True)
 # Click the actual Caps key in the Special layout (row 3, first column).
 g=geom();kw=(g['width']-48)/10;row=(g['height']-24)//5
 drag(g['x']+24+kw/2,g['y']+24+row*2+row/2,g['x']+24+kw/2,g['y']+24+row*2+row/2)
 waitfor(lambda:caps()['capsLock']);assert all(k['capsLock'] for k in keyboards());print('PASS real OSK Caps click synchronises all compositor keyboard states',flush=True)
 # Send Caps ONLY to the test-owned nested Wayland window. Its AQ keyboard is
 # the nested compositor's physical-input path; parent user apps are not targets.
 owned=int((s/'nested.pid').read_text());targets=[x for x in json.loads(call('-j','clients',env=os.environ)) if x['pid']==owned and x['class']=='aquamarine'];assert len(targets)==1
 print(call('dispatch',"hl.dsp.send_shortcut({mods='',key='Caps_Lock',window='address:"+targets[0]['address']+"'})",env=os.environ).strip(),flush=True)
 waitfor(lambda:not caps()['capsLock']);assert all(not k['capsLock'] for k in keyboards());print('PASS nested physical-input Caps clears OSK Caps across keyboard states',flush=True)
 # Physical path turns on, OSK key turns off again.
 call('dispatch',"hl.dsp.send_shortcut({mods='',key='Caps_Lock',window='address:"+targets[0]['address']+"'})",env=os.environ);waitfor(lambda:caps()['capsLock'])
 g=geom();drag(g['x']+24+kw/2,g['y']+24+row*2+row/2,g['x']+24+kw/2,g['y']+24+row*2+row/2)
 waitfor(lambda:not caps()['capsLock']);assert all(not k['capsLock'] for k in keyboards());print('PASS reverse physical-on/OSK-off sequence and event-driven bridge',flush=True)
 call('-j','monitors');subprocess.run(['grim',str(s/'native.png')],env=e,check=True)
finally:
 bridge.terminate();bridge.wait(timeout=3);p.terminate();p.wait(timeout=3)
 (s/'native-events.json').write_text(json.dumps(events,indent=2));(s/'lock-events.json').write_text(json.dumps(states,indent=2))
assert monitors()['reserved'][3]==0
print('PASS owned exit releases work area',flush=True)
