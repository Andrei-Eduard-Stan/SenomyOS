#!/usr/bin/env python3
"""Fake-provider service guards and actual Performance route coverage; no restart."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import importlib.util
repo=Path(__file__).resolve().parents[1]
shell=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
spec=importlib.util.spec_from_file_location('routes',repo/'scripts/validate-control-routes.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
subprocess.run([sys.executable,str(shell/'tests/test_managed_services.py')],check=True)
with tempfile.TemporaryDirectory(prefix='senomy-services-') as directory:
    root=Path(directory);runtime=root/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
    env.pop('WAYLAND_DISPLAY',None)
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(shell/'tests/tst_ManagedServices.qml')],env=env,capture_output=True,text=True,timeout=20)
    output=result.stdout+result.stderr
    if result.returncode or 'FAIL!' in output: print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if line.startswith('Totals:')))
    copied=root/'shell/quickshell';shutil.copytree(shell,copied,symlinks=True)
    for name in ['appearance','assets']:(root/name).symlink_to(repo/name,target_is_directory=True)
    (copied/'components/DashboardWindow.qml').write_text(m.HOST)
    shutil.copy2(shell/'tests/fixtures/performance-routes.qml',copied/'performance-routes-test.qml')
    result=subprocess.run(['qs','--path',str(copied/'performance-routes-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=30)
    output=result.stdout+result.stderr
    if result.returncode or re.search('FAIL:|ERROR|Binding loop|ReferenceError|TypeError',output) or 'PASS: Performance routes' not in output:
        print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if 'PASS:' in line))

    # Real service object, with an absent source-root helper directory and native
    # user-service queries disabled before activation. No mutation is executed.
    env['SENOMY_SOURCE_ROOT']=str(root/'absent-source')
    result=subprocess.run(['qs','--path',str(shell/'performance-service-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=10)
    output=result.stdout+result.stderr
    if result.returncode or re.search('FAIL:|ERROR|Binding loop|ReferenceError|TypeError',output) or 'PASS: actual PerformanceService' not in output:
        print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if 'PASS:' in line))
