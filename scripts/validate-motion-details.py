#!/usr/bin/env python3
"""Capture actual native QML details in a private offscreen Qt host."""
from pathlib import Path
import os,re,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=True)
fixture=Path(__file__).resolve().parents[1]/'shell/quickshell/tests/fixtures/motion-details.qml'
with tempfile.TemporaryDirectory(prefix='senomy-motion-details-') as d:
 w=Path(d);s=w/'shell/quickshell';shutil.copytree(source,s,symlinks=True)
 for name in ['assets','appearance','scripts']:(w/name).symlink_to(source.parents[1]/name,target_is_directory=True)
 shutil.copy2(fixture,s/'motion-details.qml');runtime=w/'runtime';runtime.mkdir(mode=0o700)
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(w/'config'),XDG_STATE_HOME=str(w/'state'),SENOMY_QA_OUT=str(out))
 for key in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(key,None)
 r=subprocess.run(['dbus-run-session','--','qs','-p',str(s/'motion-details.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=12);log=r.stdout+r.stderr;(out/'result.log').write_text(log)
 if r.returncode or 'PASS:' not in log or re.search('FAIL:|ERROR|TypeError|ReferenceError|Binding loop',log):raise SystemExit(log)
 print(next(l for l in log.splitlines() if 'PASS:' in l))
