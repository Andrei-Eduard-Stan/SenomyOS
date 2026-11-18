#!/usr/bin/env python3
"""Actual native Control Centre composition/input checks with inert providers."""
from pathlib import Path
import os,re,shutil,subprocess,sys,tempfile
from qa_remaining_hosts import prepare_hosts
repo=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
with tempfile.TemporaryDirectory(prefix='senomy-control-workspace-') as temporary:
 work=Path(temporary);shell=prepare_hosts(source,work);out=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else work/'captures';out.mkdir(parents=True,exist_ok=True);runtime=work/'runtime';runtime.mkdir(mode=0o700)
 shutil.copy2(source/'tests/fixtures/control-workspace-quality.qml',shell/'control-workspace-quality.qml')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),SENOMY_QA_OUT=str(out))
 for key in ['WAYLAND_DISPLAY','DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS','DBUS_SYSTEM_BUS_ADDRESS']:env.pop(key,None)
 result=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/'control-workspace-quality.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=110);log=result.stdout+result.stderr
 if len(sys.argv)>2:(out/'quality.log').write_text(log)
 if result.returncode or 'PASS: actual Control Centre composition/paths' not in log or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign|Cannot assign',log):print(log);raise SystemExit(1)
 print(next(line for line in log.splitlines() if 'PASS:' in line))
