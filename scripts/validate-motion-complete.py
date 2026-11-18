#!/usr/bin/env python3
"""Actual native hosts with inert providers; optional compositor screenshot sequences.

No service, compositor, device or session action is started/reloaded/mutated. Test
surfaces briefly cover one output, take focus and exit through Qt.quit().
"""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,tempfile,time,threading
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('out',type=Path);p.add_argument('--baseline',action='store_true');p.add_argument('--screen',type=int,default=0);p.add_argument('--capture',action='store_true');a=p.parse_args();a.source=a.source.resolve();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=True)
fixture=Path(__file__).resolve().parents[1]/'shell/quickshell/tests/fixtures/motion-complete.qml'
with tempfile.TemporaryDirectory(prefix='senomy-complete-motion-') as d:
 w=Path(d);s=w/'shell/quickshell';shutil.copytree(a.source,s,symlinks=True)
 for name in ['assets','appearance','scripts']:(w/name).symlink_to(a.source.parents[1]/name,target_is_directory=True)
 code=fixture.read_text()
 if a.baseline:code=code.replace('settingsPreferredWidth:1280;settingsPreferredHeight:860;','')
 (s/'motion-review.qml').write_text(code)
 env=dict(os.environ,QT_QPA_PLATFORM='wayland',QT_QPA_PLATFORMTHEME='',QT_NO_XDG_DESKTOP_PORTAL='1',QT_USE_PORTAL='0',XDG_CONFIG_HOME=str(w/'config'),XDG_STATE_HOME=str(w/'state'),XDG_DATA_HOME=str(w/'data'),SENOMY_QA_SCREEN=str(a.screen),SENOMY_QA_OUT=str(a.out),SENOMY_QA_CAPTURES='1' if a.capture else '0',SENOMY_MOTION_BASELINE='1' if a.baseline else '0')
 proc=subprocess.Popen(['dbus-run-session','--','qs','-p',str(s/'motion-review.qml'),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
 lines=[];phase={};samples=[];clients=[];lastClientPhase=None
 def read():
  for line in proc.stdout:
   lines.append(line)
   if 'SCREEN_PHASE ' in line:
    try:phase.update(json.loads(line.split('SCREEN_PHASE ',1)[1]))
    except ValueError:pass
 thread=threading.Thread(target=read,daemon=True);thread.start();start=time.monotonic();count={}
 while proc.poll() is None and time.monotonic()-start<35:
  row=phase.copy();name=row.get('phase');index=count.get(name,0)
  if name and name.startswith('settings') and row.get('pid'):
   observed=json.loads(subprocess.check_output(['hyprctl','clients','-j'],text=True,timeout=3))
   for client in observed:
    if client.get('pid')==row['pid']:clients.append({'observedAt':time.time(),'phase':name,**{k:client.get(k) for k in ['address','at','size','floating','title','initialTitle','class','initialClass','monitor']}})

  if a.capture and name and index<7:
   path=a.out/(name+'-'+str(index).zfill(3)+'.png');at=time.time();capture=['grim','-o',row['output'],str(path)]
   if name.startswith('settings'):
    owned=[x for x in clients if x['phase']==name and x.get('title')=='SenomyOS Settings']
    if not owned:time.sleep(.04);continue
    x,y=owned[-1]['at'] if isinstance(owned[-1].get('at'),list) else (0,0)
    width,height=owned[-1]['size'];capture=['grim','-g',f'{x},{y} {width}x{height}',str(path)]
   r=subprocess.run(capture,capture_output=True,text=True,timeout=3)
   # Retain whole-output samples only when the inert backdrop covers the
   # desktop. Cross-phase frames and compositor remapping can expose apps.
   valid=r.returncode==0 and phase.get('phase')==name
   if valid and not name.startswith('settings'):
    probes=subprocess.check_output(['magick',str(path),'-format','%[hex:p{0,0}] %[hex:p{10,500}]','info:'],text=True,timeout=3).strip()
    valid=probes=='101218 101218'
   if not valid and path.exists():path.unlink()
   samples.append({'phaseAtStart':name,'phaseAtEnd':phase.get('phase'),'file':path.name,'startedAt':at,'finishedAt':time.time(),'exitCode':r.returncode,'retained':valid});count[name]=index+1
  else:time.sleep(.04)
 code=proc.wait(timeout=5);thread.join(timeout=2);log=''.join(lines)
 trace=re.search(r'MOTION_TRACE (\{.*\})',log)
 if trace:(a.out/'trace.json').write_text(json.dumps(json.loads(trace[1]),indent=2)+'\n');log=log.replace(trace[0],'MOTION_TRACE saved to trace.json')
 (a.out/'native-clients.json').write_text(json.dumps(clients,indent=2)+'\n')
 (a.out/'result.log').write_text(log);(a.out/'compositor-samples.json').write_text(json.dumps(samples,indent=2)+'\n')
 if code or 'PASS:' not in log or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign|Cannot assign',log):raise SystemExit(log[-14000:])
 print(next(line for line in log.splitlines() if 'PASS:' in line))
