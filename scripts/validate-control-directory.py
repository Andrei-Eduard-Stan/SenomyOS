#!/usr/bin/env python3
"""Control Centre route/search/state coverage using isolated Qt and fake providers."""
import os,re,shutil,signal,subprocess,sys,tempfile
from pathlib import Path
from qa_remaining_hosts import prepare_hosts
repo=Path(__file__).resolve().parents[1]
shell=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/'shell/quickshell'
out=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else repo/'docs/qa/control-directory-20261011/isolated'
out.mkdir(parents=True,exist_ok=True)
def run(command,env,timeout):
    p=subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
    try:a,b=p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(p.pid,signal.SIGTERM)
        try:a,b=p.communicate(timeout=3)
        except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);a,b=p.communicate()
        raise RuntimeError('Private QA process timed out: '+a+b)
    return p.returncode,a+b
with tempfile.TemporaryDirectory(prefix='senomy-control-qa-') as directory:
    work=Path(directory);copied=prepare_hosts(shell,work);runtime=work/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),SENOMY_QA_OUT=str(out));env.pop('WAYLAND_DISPLAY',None)
    state=copied/"services/ShellState.qml"
    state.write_text(state.read_text().replace("import Quickshell", "import QtQuick", 1).replace("Scope {", "QtObject {", 1))
    for name,command in [('state',['/usr/lib/qt6/bin/qmltestrunner','-input',str(copied/'tests/tst_ControlNavigation.qml')]),('layout',['qs','--path',str(copied/'control-directory-test.qml'),'--no-color'])]:
        if name=='layout':shutil.copy2(shell/'tests/fixtures/control-directory.qml',copied/'control-directory-test.qml')
        code,log=run(['dbus-run-session','--',*command],env,55)
        (out/(name+'.log')).write_text(log)
        if code or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Unable to assign|Binding loop',log):print(log);raise SystemExit(1)
        print(log if name=='state' else next(line for line in log.splitlines() if 'PASS:' in line))
