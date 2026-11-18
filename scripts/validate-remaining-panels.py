#!/usr/bin/env python3
"""Native remaining-panel/deeper-form checks; private bus/XDG and inert providers."""
from pathlib import Path
import os,re,shutil,subprocess,sys,tempfile
from qa_remaining_panels import prepare_remaining_panel_hosts
repo=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
with tempfile.TemporaryDirectory(prefix='senomy-remaining-panels-') as temporary:
    work=Path(temporary);shell=prepare_remaining_panel_hosts(source,work);out=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else work/'captures';out.mkdir(parents=True,exist_ok=True);runtime=work/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),SENOMY_REMAINING_VARIANT='candidate')
    for key in ['WAYLAND_DISPLAY','DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS','DBUS_SYSTEM_BUS_ADDRESS']:env.pop(key,None)
    for phase in ['remaining-panels-quality','remaining-editors-quality']:
        shutil.copy2(source/'tests/fixtures'/(phase+'.qml'),shell/(phase+'.qml'));captures=out/phase;captures.mkdir(exist_ok=True);phaseEnv=dict(env,SENOMY_QA_OUT=str(captures))
        result=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/(phase+'.qml')),'--no-color'],env=phaseEnv,capture_output=True,text=True,timeout=110);log=result.stdout+result.stderr
        if len(sys.argv)>2:(out/(phase+'.log')).write_text(log)
        if result.returncode or 'PASS:' not in log or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign|Cannot assign',log):print(log);raise SystemExit(1)
        print(next(line for line in log.splitlines() if 'PASS:' in line))
