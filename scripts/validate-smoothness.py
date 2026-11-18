#!/usr/bin/env python3
"""Private Qt checks for rendering cadence, frame observation and rapid popup lifetime."""
from pathlib import Path
import argparse,json,os,re,shutil,signal,subprocess,tempfile,time
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('shell',nargs='?',type=Path,default=root/'shell/quickshell')
parser.add_argument('out',nargs='?',type=Path,default=root/'docs/qa/smoothness-20261108/isolated')
parser.add_argument('--baseline',type=Path)
args=parser.parse_args();source=args.shell.resolve();out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
def run(argv,env,name,timeout=20):
    process=subprocess.Popen(argv,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
    try:a,b=process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid,signal.SIGTERM)
        try:a,b=process.communicate(timeout=3)
        except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);a,b=process.communicate()
        (out/(name+'.log')).write_text(a+b);raise SystemExit('Private fixture timed out: '+name)
    log=a+b;(out/(name+'.log')).write_text(log)
    if process.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign',log):raise SystemExit(log)
    return log
with tempfile.TemporaryDirectory(prefix='senomy-smoothness-tests-') as directory:
    work=Path(directory);shell=work/'shell/quickshell';shutil.copytree(source,shell,symlinks=True)
    for name in ['assets','appearance']:(work/name).symlink_to(source.parents[1]/name,target_is_directory=True)
    runtime=work/'runtime';runtime.mkdir(mode=0o700)
    env=dict(os.environ,LANG='C.UTF-8',QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),SENOMY_QA_OUT=str(out))
    for name in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(name,None)
    # qmltestrunner cannot load Quickshell's executable-owned plugin. Isolate only
    # the unchanged Qt-only metrics singleton; the actual UI runs below use qs.
    module=shell/'tests/metrics';module.mkdir();shutil.copy2(source/'config/RenderMetrics.qml',module/'RenderMetrics.qml')
    (module/'qmldir').write_text('singleton RenderMetrics 1.0 RenderMetrics.qml\n')
    unit=shell/'tests/tst_RenderMetrics.qml';unit.write_text(unit.read_text().replace('import "../config" as Config','import "metrics" as Config'))
    log=run(['dbus-run-session','--','/usr/lib/qt6/bin/qmltestrunner','-input',str(shell/'tests/tst_RenderMetrics.qml')],env,'metrics-unit')
    print(next(line for line in log.splitlines() if 'Totals:' in line))
    # Keep the real popup lifetime logic and replace only native Wayland placement/grab.
    popup=shell/'components/interaction/QuickPopoverWindow.qml';code=popup.read_text()
    code=code.replace('PopupWindow {','Window {',1).replace('import Quickshell.Hyprland','')
    code=code.replace('    grabFocus: false\n','').replace('    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Resize\n','')
    code=code.replace('    id: root','    id: root\n    property QtObject anchor: QtObject { function updateAnchor() {} }',1).replace('HyprlandFocusGrab {','FakeFocusGrab {')
    popup.write_text(code)
    (popup.parent/'FakeFocusGrab.qml').write_text('import QtQuick\nItem { property bool active:false; property var windows:[]; signal cleared() }\n')
    for name in ['frame-observer','sheen-lifecycle','rapid-popovers']:
        shutil.copy2(source/'tests/fixtures'/(name+'.qml'),shell/(name+'-test.qml'))
        log=run(['dbus-run-session','--','qs','-p',str(shell/(name+'-test.qml')),'--no-color'],env,name)
        print(next(line for line in log.splitlines() if 'PASS:' in line))
    observations={}
    for label,path in [('candidate',source)]+([('baseline',args.baseline.resolve())] if args.baseline else []):
        for mode in ['idle','engaged']:
            target=work/(label+'-'+mode)/'shell/quickshell';shutil.copytree(path,target,symlinks=True)
            for name in ['assets','appearance']:(target.parents[1]/name).symlink_to(source.parents[1]/name,target_is_directory=True)
            shutil.copy2(source/'tests/fixtures/idle-sheen.qml',target/'idle-sheen-test.qml')
            log=run(['dbus-run-session','--','qs','-p',str(target/'idle-sheen-test.qml'),'--no-color'],env|{'SENOMY_SHEEN_MODE':mode},label+'-'+mode)
            result=json.loads(next(line.split('RESULT ',1)[1] for line in log.splitlines() if 'RESULT ' in line));observations[label+'-'+mode]=result
            if label=='candidate':
                # Rail hover is now a finite border trace; held hover must settle too.
                assert result['phaseChanges']==0 and result['activeClients']==0
                assert result['presentedFrames']==0
            print(label,mode,result)
    (out/'idle-rendering.json').write_text(json.dumps(observations,indent=2)+'\n')
print('PASS: bounded passive metrics and idle/held-hover rendering settles; offscreen Qt evidence, not physical GPU latency')
