#!/usr/bin/env python3
"""Desktop preferences and portal reads; all write tests use private XDG roots."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
repo=Path(__file__).resolve().parents[1]
shell=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
for name in ['test_desktop_settings.py','test_desktop_capabilities.py']:subprocess.run([sys.executable,str(shell/'tests'/name)],check=True)
with tempfile.TemporaryDirectory(prefix='senomy-desktop-') as directory:
    root=Path(directory);runtime=root/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software');env.pop('WAYLAND_DISPLAY',None)
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(shell/'tests/tst_DesktopPreferenceActions.qml')],env=env,capture_output=True,text=True,timeout=20)
    output=result.stdout+result.stderr
    if result.returncode or 'FAIL!' in output:print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if line.startswith('Totals:')))
    copied=root/'shell/quickshell';shutil.copytree(shell,copied,symlinks=True)
    for name in ['appearance','assets']:(root/name).symlink_to(repo/name,target_is_directory=True)
    for name,marker in [('desktop-settings-test.qml','PASS: default/autostart/portal views'),('desktop-service-test.qml','PASS: actual DesktopSettings')]:
        result=subprocess.run(['qs','--path',str(copied/name),'--no-color'],env=env,capture_output=True,text=True,timeout=20)
        output=result.stdout+result.stderr
        if result.returncode or re.search('FAIL:|ERROR|Binding loop|ReferenceError|TypeError',output) or marker not in output:print(output);raise SystemExit(1)
        print(next(line for line in output.splitlines() if 'PASS:' in line))
