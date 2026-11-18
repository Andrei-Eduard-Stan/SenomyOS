#!/usr/bin/env python3
"""Exercise actual notification rows on an isolated native Qt host."""
from pathlib import Path
import os,re,shutil,subprocess,sys,tempfile
root=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'shell/quickshell'
with tempfile.TemporaryDirectory(prefix='senomy-notification-motion-') as name:
 work=Path(name);shell=work/'shell/quickshell';shutil.copytree(source,shell,symlinks=True)
 for folder in ['assets','appearance']:(work/folder).symlink_to(source.parents[1]/folder,target_is_directory=True)
 shutil.copy2(root/'shell/quickshell/tests/fixtures/motion-notifications.qml',shell/'motion-notifications.qml')
 runtime=work/'runtime';runtime.mkdir(mode=0o700)
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'))
 for key in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(key,None)
 result=subprocess.run(['dbus-run-session','--','qs','-p',str(shell/'motion-notifications.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=10)
 log=result.stdout+result.stderr
 if result.returncode or 'PASS:' not in log or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign',log):raise SystemExit(log)
 print(next(line for line in log.splitlines() if 'PASS:' in line))
