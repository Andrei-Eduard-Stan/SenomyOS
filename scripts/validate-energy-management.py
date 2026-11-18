#!/usr/bin/env python3
"""Private buses, offscreen Quickshell and inert writes only; no live actions."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
root=a.root.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='senomy-energy-qa-') as directory:
    work=Path(directory);shell=work/'shell/quickshell';shutil.copytree(root/'shell/quickshell',shell,symlinks=True)
    for name in ('assets','appearance'):
        if (root/name).exists():(work/name).symlink_to(root/name,target_is_directory=True)
    runtime=work/'runtime';runtime.mkdir(mode=0o700)
    fixture=work/'fixture';fixture.mkdir()
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',PYTHONDONTWRITEBYTECODE='1',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),SENOMY_PRIVATE_ENERGY_FIXTURE=str(fixture))
    for key in ('WAYLAND_DISPLAY','DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS','DBUS_SYSTEM_BUS_ADDRESS'):env.pop(key,None)
    def run(argv,name,private=False):
        if private:
            argv=['dbus-run-session','--','python3','-B','-c','import os,sys;os.environ["DBUS_SYSTEM_BUS_ADDRESS"]=os.environ["DBUS_SESSION_BUS_ADDRESS"];os.environ["SENOMY_PRIVATE_ENERGY_TEST"]="1";os.execvp(sys.argv[1],sys.argv[1:])',*argv]
        result=subprocess.run(argv,env=env,capture_output=True,text=True,timeout=30,cwd=root)
        (out/name).write_text(result.stdout+result.stderr)
        if result.returncode:raise SystemExit((out/name).read_text())
    run(['python3','-B',str(shell/'tests/test_energy_provider.py')],'backend.log')
    run(['python3','-B',str(shell/'tests/test_energy_dbus.py')],'private-dbus.log',True)
    for name in ('energy-service-test','energy-transport-test','energy-page-test','battery-service-test'):
        run(['qs','--path',str(shell/(name+'.qml')),'--no-color'],name+'.log',True)
    pid=int((fixture/'watcher.pid').read_text())
    try:
        os.kill(pid,0)
    except ProcessLookupError:pass
    else:raise SystemExit('Fixture watcher leaked after Quickshell exit: '+str(pid))
    run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(shell/'tests/tst_SelectionActions.qml')],'selection-regression.log')
    run(['/usr/lib/qt6/bin/qmllint','-I',str(shell),*[str(shell/name) for name in ('services/EnergyService.qml','services/BatteryService.qml','components/control/ControlPowerPage.qml','components/control/ControlSettingsPage.qml')]],'qmllint.log')
print('PASS: policy/transport, private D-Bus, native shared UI state, battery/selection regression, watcher cleanup and lint. No live mutation.')
