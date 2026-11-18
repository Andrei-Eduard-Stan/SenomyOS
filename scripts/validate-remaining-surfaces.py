#!/usr/bin/env python3
"""Real native layouts and safe interactions with fake providers/private Qt hosts."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from qa_remaining_hosts import prepare_hosts

# Tray/menu discovery must never attach to the user's StatusNotifier bus.
if os.environ.get('SENOMY_REMAINING_PRIVATE_BUS') != '1':
    if not shutil.which('dbus-run-session'):
        raise SystemExit('dbus-run-session is required for isolated native UI tests')
    child_env=dict(os.environ,SENOMY_REMAINING_PRIVATE_BUS='1')
    raise SystemExit(subprocess.call(['dbus-run-session','--',sys.executable,str(Path(__file__).resolve()),*sys.argv[1:]],env=child_env))

repo=Path(__file__).resolve().parents[1]
shell=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
output=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else None
with tempfile.TemporaryDirectory(prefix='senomy-remaining-qa-') as directory:
    work=Path(directory)
    copied=prepare_hosts(shell,work)
    captures=output or work/'captures'
    captures.mkdir(parents=True,exist_ok=True)
    runtime=work/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),XDG_STATE_HOME=str(work/'state'),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',SENOMY_QA_OUT=str(captures))
    env.pop('WAYLAND_DISPLAY',None)
    for name in ['remaining-controls','remaining-popup','remaining-control','remaining-background']:
        shutil.copy2(shell/('tests/fixtures/'+name+'.qml'),copied/(name+'-test.qml'))
        run_env=dict(env)
        if name=='remaining-background':
            run_env.update(QT_QUICK_BACKEND='rhi',QSG_RHI_BACKEND='opengl')
        result=subprocess.run(['qs','--path',str(copied/(name+'-test.qml')),'--no-color'],env=run_env,capture_output=True,text=True,timeout=40)
        log=result.stdout+result.stderr
        (captures/(name+'.log')).write_text(log)
        if result.returncode or re.search(r'FAIL:|ERROR|Binding loop|ReferenceError|TypeError|Unable to assign|invalid context',log) or 'PASS:' not in log:
            print(log);raise SystemExit(1)
        print(next(line for line in log.splitlines() if 'PASS:' in line))
    # Native GPU capture: the configured image cannot occupy the chamfer's void.
    if not shutil.which('magick'):
        raise SystemExit('ImageMagick is required for background mask pixel validation')
    alpha=subprocess.check_output(['magick',str(captures/'perimeter-background-mask.png'),'-format','%[fx:p{11,11}.a] %[fx:p{160,200}.a]','info:'],text=True)
    outside,inside=map(float,alpha.split())
    assert outside == 0, 'background extends outside the authored cut'
    assert inside > 0, 'background/fill missing inside frame'
    print('PASS: GPU-rendered background corner mask pixels; no configuration writes')
