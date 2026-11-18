#!/usr/bin/env python3
"""Actual message/frame rendering with inert providers, private bus and state."""
from pathlib import Path
import argparse,os,re,shutil,subprocess,tempfile
p=argparse.ArgumentParser();p.add_argument('--native',action='store_true');p.add_argument('--out',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1];a.out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='senomy-frame-qa-') as directory:
 temp=Path(directory);shell=temp/'shell/quickshell';shutil.copytree(root/'shell/quickshell',shell,symlinks=True)
 for name in ['assets','appearance']:(temp/name).symlink_to(root/name,target_is_directory=True)
 name='frame-native' if a.native else 'frame-layout';shutil.copy2(shell/'tests/fixtures'/(name+'.qml'),shell/(name+'.qml'))
 if a.native:
  path=shell/'components/DirectorySurfaceWindow.qml';path.write_text(path.read_text().replace('senomy-v2-primary','senomy-frame-fixture'))
 runtime=temp/'runtime';runtime.mkdir(mode=0o700)
 env=dict(os.environ,LANG='C.UTF-8',LC_ALL='C.UTF-8',QT_QPA_PLATFORM='wayland' if a.native else 'offscreen',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/'config'),XDG_STATE_HOME=str(temp/'state'),SENOMY_QA_OUT=str(a.out.resolve()))
 env.pop('HYPRLAND_INSTANCE_SIGNATURE',None)
 if a.native:
  display=os.environ['WAYLAND_DISPLAY'];env['WAYLAND_DISPLAY']=display if display.startswith('/') else str(Path(os.environ['XDG_RUNTIME_DIR'])/display)
 else:env.pop('WAYLAND_DISPLAY',None);env['QT_QUICK_BACKEND']='software'
 result=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/(name+'.qml')),'--no-color'],env=env,capture_output=True,text=True,timeout=25)
 log=result.stdout+result.stderr;(a.out/'test.log').write_text(log)
 if result.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign|Cannot assign',log) or 'PASS:' not in log:raise SystemExit(log)
 print(next(line for line in log.splitlines() if 'PASS:' in line))
