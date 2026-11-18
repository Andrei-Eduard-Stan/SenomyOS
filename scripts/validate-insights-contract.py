#!/usr/bin/env python3
"""Insights request policy and all eight actual UI routes using fake providers."""
from qa_directory_host import directory_host, insights_workspace_host, performance_workspace_host
from qa_performance_fixture import performance_environment
import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
repo=Path(__file__).resolve().parents[1]
shell=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
spec=importlib.util.spec_from_file_location('routes',repo/'scripts/validate-control-routes.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
with tempfile.TemporaryDirectory(prefix='senomy-insights-') as directory:
    root=Path(directory);runtime=root/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software');env.pop('WAYLAND_DISPLAY',None)
    result=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(shell/'tests/tst_InsightsRequests.qml')],env=env,capture_output=True,text=True,timeout=20)
    output=result.stdout+result.stderr
    if result.returncode or 'FAIL!' in output:print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if line.startswith('Totals:')))
    copied=root/'shell/quickshell';shutil.copytree(shell,copied,symlinks=True)
    for name in ['appearance','assets']:(root/name).symlink_to(repo/name,target_is_directory=True)
    (copied/'components/PrimarySurfaceWindow.qml').write_text(m.HOST)
    (copied/'components/DirectorySurfaceWindow.qml').write_text(directory_host(shell))
    (copied/'components/PerformanceWorkspaceWindow.qml').write_text(performance_workspace_host(shell))
    (copied/'components/InsightsWorkspaceWindow.qml').write_text(insights_workspace_host(shell))
    shutil.copy2(shell/'tests/fixtures/insights-workspace-quality.qml',copied/'insights-routes-test.qml')
    result=subprocess.run(['qs','--path',str(copied/'insights-routes-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=30)
    output=result.stdout+result.stderr
    if result.returncode or re.search('FAIL:|ERROR|Binding loop|ReferenceError|TypeError',output) or 'PASS: all eight Insights routes' not in output:
        print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if 'PASS:' in line))

    helpers=root/'source/scripts';helpers.mkdir(parents=True)
    helper_code="""#!/usr/bin/env python3
import json,os,sys,time
from pathlib import Path
route='console' if 'console' in sys.argv[0] else 'diagnostics'
mode=sys.argv[1];now=int(time.time())
if mode=='catalog': payload={'ok':True,'observed_at':now,'data':{'tasks':[{'id':'safe-task'}]}}
else:
    payload={'ok':route=='console','observed_at':now,'data':{'task_id':'safe-task','state':'ready' if route=='console' else 'failed','finished_at':now,'output':[], 'correctRoot':Path(sys.argv[0]).parents[1].is_dir()},'error':None if route=='console' else {'message':'Fixture failure'}}
    cache=Path(sys.argv[0]).with_suffix('.json')
    if mode=='run': cache.write_text(json.dumps(payload))
    elif cache.exists(): payload=json.loads(cache.read_text())
if route=='console' and mode=='run':sys.exit(0)
print(json.dumps(payload))
"""
    for name in ['console-status.sh','diagnostics-status.sh']:
        path=helpers/name;path.write_text(helper_code);path.chmod(0o755)
    env['SENOMY_SOURCE_ROOT']=str(helpers.parent)
    result=subprocess.run(['qs','--path',str(shell/'insights-service-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=15)
    output=result.stdout+result.stderr
    if result.returncode or re.search('FAIL:|ERROR|Binding loop|ReferenceError|TypeError',output) or 'PASS: actual InsightsService' not in output:
        print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if 'PASS:' in line))

    (copied/'components/DashboardWindow.qml').write_text(m.HOST)
    (copied/'components/DirectorySurfaceWindow.qml').write_text(directory_host(shell))
    (copied/'components/PerformanceWorkspaceWindow.qml').write_text(performance_workspace_host(shell))
    (copied/'components/InsightsWorkspaceWindow.qml').write_text(insights_workspace_host(shell))
    shutil.copy2(shell/'tests/fixtures/performance-workspace-quality.qml',copied/'performance-shared-test.qml')
    result=subprocess.run(['qs','--path',str(copied/'performance-shared-test.qml'),'--no-color'],env=performance_environment(shell,root,env),capture_output=True,text=True,timeout=30)
    output=result.stdout+result.stderr
    if result.returncode or re.search('FAIL:|ERROR|Binding loop|ReferenceError|TypeError',output) or 'PASS: shared Performance' not in output:
        print(output);raise SystemExit(1)
    print(next(line for line in output.splitlines() if 'PASS:' in line))
