#!/usr/bin/env python3
"""Render production workspace/tray components with inert objects on a private bus."""
import argparse,os,re,shutil,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='senomy-rail-tray-qa-') as temporary:
 work=Path(temporary);shell=work/'shell/quickshell';shutil.copytree(a.root/'shell/quickshell',shell,symlinks=True)
 for name in ['appearance','assets']:(work/name).symlink_to(a.root/name,target_is_directory=True)
 shutil.copy2(shell/'tests/fixtures/rail-tray.qml',shell/'rail-tray-test.qml')
 runtime=work/'runtime';runtime.mkdir(mode=0o700)
 env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',SENOMY_QA_OUT=str(a.out.resolve()))
 env.pop('WAYLAND_DISPLAY',None)
 result=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/'rail-tray-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=25)
 log=result.stdout+result.stderr;(a.out/'rail-tray.log').write_text(log)
 if result.returncode or re.search(r'FAIL:|ERROR|ReferenceError|TypeError|Binding loop|Unable to assign',log) or 'PASS:' not in log:print(log);raise SystemExit(1)
 print(next(line for line in log.splitlines() if 'PASS:' in line))
