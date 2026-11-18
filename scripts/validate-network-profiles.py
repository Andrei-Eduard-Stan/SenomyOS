#!/usr/bin/env python3
"""Profile policy/inventory tests, observed connection results and real UI fixture."""
import os

def private_command(argv):
    return ['dbus-run-session','--','bash','-c','export DBUS_SYSTEM_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS"; exec "$@"','network-fixture',*argv]

from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
repo=Path(__file__).resolve().parents[1]
shell=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
subprocess.run([sys.executable,str(shell/'tests/test_network_profiles.py')],check=True)
with tempfile.TemporaryDirectory(prefix='senomy-network-profiles-') as directory:
    root=Path(directory);runtime=root/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(root/'config'),XDG_STATE_HOME=str(root/'state'),PYTHONDONTWRITEBYTECODE='1',QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
    for key in ['WAYLAND_DISPLAY','DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS','DBUS_SYSTEM_BUS_ADDRESS']:env.pop(key,None)
    for name in ['tst_ProfileActions.qml','tst_ConnectionAttempt.qml','tst_NetworkActions.qml']:
        result=subprocess.run(private_command(['/usr/lib/qt6/bin/qmltestrunner','-input',str(shell/'tests'/name)]),env=env,capture_output=True,text=True,timeout=20)
        output=result.stdout+result.stderr
        if result.returncode or 'FAIL!' in output:print(output);raise SystemExit(1)
        print(next(line for line in output.splitlines() if line.startswith('Totals:')))
    copied=root/'shell/quickshell';shutil.copytree(shell,copied,symlinks=True)
    for name in ['appearance','assets']:(root/name).symlink_to(repo/name,target_is_directory=True)
    result=subprocess.run(private_command(['qs','--path',str(copied/'network-profiles-test.qml'),'--no-color']),env=env,capture_output=True,text=True,timeout=15)
    output=result.stdout+result.stderr
    clean=output.replace(' ERROR quickshell.network: Network will not work. Could not find an available backend.','')
    if result.returncode or re.search('FAIL:|ERROR|Binding loop|ReferenceError|TypeError',clean) or 'PASS: 24 saved profiles' not in output:print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if 'PASS:' in line))

    result=subprocess.run(private_command(['qs','--path',str(copied/'network-service-test.qml'),'--no-color']),env=env,capture_output=True,text=True,timeout=10)
    output=result.stdout+result.stderr
    clean=output.replace(' ERROR quickshell.network: Network will not work. Could not find an available backend.','')
    if result.returncode or re.search('FAIL:|ERROR|Binding loop|ReferenceError|TypeError',clean) or 'PASS: actual NetworkService' not in output:print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if 'PASS:' in line))

    # The production service is retained; only ordinary-app launching is inert.
    (copied/'services/ApplicationLaunch.qml').write_text('import QtQuick\nQtObject { signal finished(bool accepted,string detail); function request(kind,target,args){console.log("FAKE_NETWORK_LAUNCH "+JSON.stringify([kind,target,args]));return true;} }\n')
    (root/'fixture').mkdir();env['SENOMY_PRIVATE_NETWORK_FIXTURE']=str(root/'fixture')
    for name in ['network-runtime','network-recovery']:
        shutil.copy2(shell/'tests/fixtures'/(name+'.qml'),copied/(name+'-test.qml'))
        result=subprocess.run(private_command(['qs','--path',str(copied/(name+'-test.qml')),'--no-color']),env=env,capture_output=True,text=True,timeout=12)
        output=result.stdout+result.stderr
        clean=output.replace(' ERROR quickshell.network: Network will not work. Could not find an available backend.','')
        if result.returncode or re.search('FAIL:|ERROR|Binding loop|ReferenceError|TypeError|Unable to assign',clean) or 'PASS:' not in output:print(output);raise SystemExit(1)
        if name=='network-runtime':
            if 'wifi-auth-interface' not in output or 'wlan-fixture-2' not in output:raise SystemExit('Authentication did not retain the selected interface')
        else:
            pid=int((root/'fixture/pid').read_text())
            if Path('/proc',str(pid)).exists():raise SystemExit('Private observer leaked after fixture exit')
        print(next(line for line in output.splitlines() if 'PASS:' in line))
