#!/usr/bin/env python3
"""Audio-specific fake provider UI and adapter tests; private session bus."""
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile

def private_run(command, env, timeout):
    process=subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
    try:stdout,stderr=process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid,signal.SIGTERM)
        try:stdout,stderr=process.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid,signal.SIGKILL);stdout,stderr=process.communicate()
        print(stdout+stderr);raise SystemExit('Isolated audio fixture timed out; its process group was stopped')
    return subprocess.CompletedProcess(command,process.returncode,stdout,stderr)

repo=Path(__file__).resolve().parents[1]
shell=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
out=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else repo/'docs/qa/audio-revamp-20261011/isolated'
out.mkdir(parents=True,exist_ok=True)
result=subprocess.run([sys.executable,'-m','unittest','discover','-s',str(shell/'tests'),'-p','test_audio_graph.py','-v'],capture_output=True,text=True)
(out/'adapter-tests.log').write_text(result.stdout+result.stderr)
if result.returncode:print(result.stdout+result.stderr);raise SystemExit(1)
runner='/usr/lib/qt6/bin/qmltestrunner' if Path('/usr/lib/qt6/bin/qmltestrunner').is_file() else shutil.which('qmltestrunner')
if not runner:raise SystemExit('Qt 6 qmltestrunner is required')
for fixture in ['tst_AudioGraphActions.qml','tst_SelectionActions.qml']:
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software');env.pop('WAYLAND_DISPLAY',None)
    result=private_run(['dbus-run-session','--',runner,'-input',str(shell/'tests'/fixture)],env,20)
    (out/(fixture+'.log')).write_text(result.stdout+result.stderr)
    if result.returncode:print(result.stdout+result.stderr);raise SystemExit(1)
with tempfile.TemporaryDirectory(prefix='senomy-audio-qa-') as directory:
    work=Path(directory);copied=work/'shell/quickshell';shutil.copytree(shell,copied,symlinks=True)
    for name in ['assets','appearance']:(work/name).symlink_to(shell.parents[1]/name,target_is_directory=True)
    runtime=work/'runtime';runtime.mkdir(mode=0o700)
    shutil.copy2(shell/'tests/fixtures/audio-revamp.qml',copied/'audio-revamp-test.qml')
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_STATE_HOME=str(work/'state'),XDG_CONFIG_HOME=str(work/'config'),SENOMY_QA_OUT=str(out))
    env.pop('WAYLAND_DISPLAY',None)
    for name in ['audio-revamp','audio-media-service','audio-recovery','bluetooth-audio-identity']:
        shutil.copy2(shell/('tests/fixtures/'+name+'.qml'),copied/(name+'-test.qml'))
        env['SENOMY_PRIVATE_AUDIO_TEST_ROOT']=str(work)
        result=private_run(['dbus-run-session','--','qs','--path',str(copied/(name+'-test.qml')),'--no-color'],env,35)
        log=result.stdout+result.stderr;(out/(name+'.log')).write_text(log)
        if result.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Unable to assign|Binding loop',log) or 'PASS:' not in log:print(log);raise SystemExit(1)
        if name=='audio-recovery':
            pid=int((work/'last-pid').read_text())
            if Path('/proc',str(pid)).exists():raise SystemExit('Isolated audio watcher leaked after fixture exit')
        print(next(line for line in log.splitlines() if 'PASS:' in line))
print('PASS: audio adapter safety, inventory privacy and versioned preferences; no live device mutation')
