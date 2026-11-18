#!/usr/bin/env python3
"""Production DeviceInventory with inert workers, no real compositor transport."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='senomy-display-transport-') as directory:
    temp=Path(directory);shell=temp/'shell/quickshell'
    shutil.copytree(root/'shell/quickshell',shell,symlinks=True,ignore=shutil.ignore_patterns('__pycache__'))
    for name in ('appearance','assets'):(temp/name).symlink_to(root/name,target_is_directory=True)
    fixture=(shell/'tests/fixtures/display-transport.qml').read_text().replace('"../../services"','"services"')
    (shell/'display-transport-test.qml').write_text(fixture)
    fake=shell/'tests/fixtures/display-transport-fake.py'
    for name in ('device-inventory.py','display-action.py'):shutil.copyfile(fake,shell/'scripts'/name)
    runtime=temp/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/'config'),XDG_STATE_HOME=str(temp/'state'),
             SENOMY_PRIVATE_DISPLAY_FIXTURE='1',QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
    for name in ('WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DISPLAY'):env.pop(name,None)
    result=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/'display-transport-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=15)
    output=result.stdout+result.stderr
    print(output)
    if result.returncode or re.search(r'FAIL|TypeError|ReferenceError|Binding loop|Failed to load configuration',output) or 'PASS: actual display transport' not in output:raise SystemExit(1)
