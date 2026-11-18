#!/usr/bin/env python3
"""Focused shared controls and inert service regressions; no real device access."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile

root=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
names=sys.argv[2:] or ['wp07-controls','wp07-transports']
for name in names:
    if name not in ('wp07-controls','wp07-transports'):raise SystemExit('Unknown fixture')
    with tempfile.TemporaryDirectory(prefix='senomy-wp07-') as directory:
        temp=Path(directory);shell=temp/'shell/quickshell'
        shutil.copytree(root/'shell/quickshell',shell,symlinks=True,ignore=shutil.ignore_patterns('__pycache__'))
        for item in ('appearance','assets'):(temp/item).symlink_to(root/item,target_is_directory=True)
        source=(shell/'tests/fixtures'/f'{name}.qml').read_text().replace('"../../components"','"components"').replace('"../../config"','"config"').replace('"../../services"','"services"')
        (shell/f'{name}.qml').write_text(source)
        if name=='wp07-transports':
            for item in ('desktop-settings.py','desktop-capabilities.py','osk-automatic.py','native-input-tools.py','osk-capabilities.py'):
                shutil.copyfile(shell/'tests/fixtures/wp07-fake.py',shell/'scripts'/item)
        runtime=temp/'runtime';runtime.mkdir(mode=0o700)
        env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/'config'),XDG_STATE_HOME=str(temp/'state'),SENOMY_PRIVATE_WP07='1',QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
        for item in ('WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DISPLAY'):env.pop(item,None)
        result=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/f'{name}.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=15)
        output=result.stdout+result.stderr
        print(output)
        if result.returncode or re.search(r'FAIL:|TypeError|ReferenceError|Binding loop|Failed to load configuration',output) or 'RESULT:' not in output:raise SystemExit(1)
