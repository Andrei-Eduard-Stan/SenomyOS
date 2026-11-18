#!/usr/bin/env python3
"""Actual calendar service/UI using a private bus, socket and event database."""
from qa_remaining_hosts import prepare_hosts
from pathlib import Path
import argparse,os,shutil,subprocess,tempfile,re
parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);parser.add_argument('--python',default=str(Path(os.environ.get('XDG_DATA_HOME',Path.home()/'.local/share'))/'senomyos/calendar/runtime/bin/python'));parser.add_argument('--backend',choices=['software','rhi'],default='software');parser.add_argument('--out',type=Path,required=True);args=parser.parse_args();root=args.root.resolve();out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
owner=(root/'shell/quickshell/shell.qml').read_text()
assert 'id:calendarServiceOwner' in owner and 'calendarService:calendarServiceOwner' in owner, 'Global calendar provider must use an unambiguous ID at the Rail binding'
assert 'calendarService:calendarService\n' not in owner, 'Rail property cannot bind to itself'
unit=subprocess.run([args.python,'-m','unittest','discover','-s',str(root/'components/calendar/tests'),'-v'],capture_output=True,text=True);(out/'backend-tests.log').write_text(unit.stdout+unit.stderr)
if unit.returncode: print(unit.stdout+unit.stderr);raise SystemExit(1)
with tempfile.TemporaryDirectory(prefix='senomy-calendar-organizer-qa-') as directory:
 work=Path(directory);runtime=work/'runtime';runtime.mkdir(mode=0o700);copied=work/'shell/quickshell';shutil.copytree(root/'shell/quickshell',copied,symlinks=True)
 for name in ['appearance','assets']:(work/name).symlink_to(root/name,target_is_directory=True)
 shutil.copy2(copied/'tests/fixtures/calendar-organizer.qml',copied/'calendar-organizer-test.qml')
 (work/'control').mkdir()
 control=prepare_hosts(root/'shell/quickshell',work/'control')
 for name in ['appearance','assets']:
  target=work/'control'/name
  if not target.exists():target.symlink_to(root/name,target_is_directory=True)
 shutil.copy2(control/'tests/fixtures/calendar-control.qml',control/'calendar-control-test.qml')
 env=dict(os.environ,PYTHONPATH=str(root/'components/calendar'),XDG_RUNTIME_DIR=str(runtime),XDG_STATE_HOME=str(work/'state'),XDG_CONFIG_HOME=str(work/'config'),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND=args.backend,QSG_RHI_BACKEND='opengl',SENOMY_QA_OUT=str(out),SENOMY_NOTIFICATION_OWNER='none')
 env.pop('WAYLAND_DISPLAY',None)
 harness=work/'harness.py';harness.write_text('''import subprocess,sys,time,os,pathlib
backend=subprocess.Popen([sys.argv[1],'-m','senomy_calendar.daemon','--runtime',os.environ['XDG_RUNTIME_DIR']+'/senomyos-calendar'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
try:
 for _ in range(100):
  if pathlib.Path(os.environ['XDG_RUNTIME_DIR']+'/senomyos-calendar/calendar.sock').exists():break
  if backend.poll() is not None:raise RuntimeError('private backend failed')
  time.sleep(0.02)
 result=subprocess.run(['qs','--path',sys.argv[2],'--no-color'],capture_output=True,text=True,timeout=50)
 print(result.stdout+result.stderr)
 if result.returncode:sys.exit(result.returncode)
 result=subprocess.run(['qs','--path',sys.argv[3],'--no-color'],capture_output=True,text=True,timeout=50)
 print(result.stdout+result.stderr);sys.exit(result.returncode)
finally:
 backend.terminate();backend.wait(timeout=5)
''')
 result=subprocess.run(['dbus-run-session','--','python3',str(harness),args.python,str(copied/'calendar-organizer-test.qml'),str(control/'calendar-control-test.qml')],env=env,capture_output=True,text=True,timeout=110)
 log=result.stdout+result.stderr;(out/'organizer-ui.log').write_text(log)
 if result.returncode or re.search(r'FAIL:|ERROR|ReferenceError|TypeError|Binding loop|invalid context|Unable to assign',log) or 'PASS:' not in log:print(log);raise SystemExit(1)
 print(next(line for line in log.splitlines() if 'PASS:' in line))
print('PASS: private calendar backend unit and production UI checks')
