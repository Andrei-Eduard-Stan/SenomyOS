#!/usr/bin/env python3
"""Profile policy/inventory tests, observed connection results and real UI fixture."""
import os
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
    env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software');env.pop('WAYLAND_DISPLAY',None)
    for name in ['tst_ProfileActions.qml','tst_ConnectionAttempt.qml','tst_NetworkActions.qml']:
        result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(shell/'tests'/name)],env=env,capture_output=True,text=True,timeout=20)
        output=result.stdout+result.stderr
        if result.returncode or 'FAIL!' in output:print(output);raise SystemExit(1)
        print(next(line for line in output.splitlines() if line.startswith('Totals:')))
    copied=root/'shell/quickshell';shutil.copytree(shell,copied,symlinks=True)
    for name in ['appearance','assets']:(root/name).symlink_to(repo/name,target_is_directory=True)
    result=subprocess.run(['qs','--path',str(copied/'network-profiles-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=15)
    output=result.stdout+result.stderr
    if result.returncode or re.search('FAIL:|ERROR|Binding loop|ReferenceError|TypeError',output) or 'PASS: 24 saved profiles' not in output:print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if 'PASS:' in line))

    result=subprocess.run(['qs','--path',str(copied/'network-service-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=10)
    output=result.stdout+result.stderr
    if result.returncode or re.search('FAIL:|ERROR|Binding loop|ReferenceError|TypeError',output) or 'PASS: actual NetworkService' not in output:print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if 'PASS:' in line))
