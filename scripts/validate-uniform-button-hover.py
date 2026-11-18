#!/usr/bin/env python3
"""Native Qt hover motion and input checks with inert providers on a private bus."""
from pathlib import Path
import os,re,shutil,signal,subprocess,sys,tempfile
repo=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
out=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else repo/'docs/qa/uniform-button-hover-20261108/isolated'
out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='senomy-hover-qa-') as directory:
 work=Path(directory);shell=work/'shell/quickshell';shutil.copytree(source,shell,symlinks=True)
 for name in ['assets','appearance']:(work/name).symlink_to(source.parents[1]/name,target_is_directory=True)
 shutil.copy2(source/'tests/fixtures/uniform-button-hover.qml',shell/'uniform-button-hover.qml')
 runtime=work/'runtime';runtime.mkdir(mode=0o700)
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),SENOMY_QA_OUT=str(out))
 for key in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(key,None)
 process=subprocess.Popen(['dbus-run-session','--','qs','-p',str(shell/'uniform-button-hover.qml'),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
 try:a,b=process.communicate(timeout=40)
 except subprocess.TimeoutExpired:
  os.killpg(process.pid,signal.SIGTERM);a,b=process.communicate(timeout=3)
  (out/'quality.log').write_text(a+b);raise SystemExit('Private hover fixture timed out')
 log=a+b;(out/'quality.log').write_text(log)
 if process.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign|Cannot assign',log) or 'PASS:' not in log:raise SystemExit(log)
 print(next(line for line in log.splitlines() if 'PASS:' in line))
