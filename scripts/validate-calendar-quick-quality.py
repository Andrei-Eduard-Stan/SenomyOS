#!/usr/bin/env python3
"""Production calendar composition, native Qt input and fake calendar requests.

Only compositor hosting is substituted for screenshots. Separately compile the
actual PopupWindow without opening it. No live calendar or display is mutated.
"""
from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tempfile

from qa_remaining_hosts import prepare_hosts

repo = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else repo / 'shell/quickshell'
out = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else repo / 'docs/qa/calendar-design-20261024/isolated'
out.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix='senomy-calendar-quick-quality-') as directory:
    work = Path(directory)
    shell = prepare_hosts(source, work)
    original = (source / 'components/CalendarPopup.qml').read_text()
    sizes = '\n'.join(line for line in original.splitlines()
                      if line.strip().startswith(('implicitWidth:', 'implicitHeight:')))
    host = shell / 'components/CalendarPopup.qml'
    # The existing host adapter retains composition/animation and exposes test
    # work-area bounds. Retain the actual production size equations as well.
    host.write_text(host.read_text().replace('    FocusScope {\n        id: card',
                                            sizes + '\n    FocusScope {\n        id: card'))
    shutil.copy2(source / 'tests/fixtures/calendar-quick-quality.qml', shell / 'calendar-quick-quality.qml')
    runtime = work / 'runtime'
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               XDG_RUNTIME_DIR=str(runtime), XDG_STATE_HOME=str(work / 'state'),
               XDG_CONFIG_HOME=str(work / 'config'), SENOMY_QA_OUT=str(out))
    for key in ['WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE']:
        env.pop(key, None)
    result = subprocess.run(['dbus-run-session', '--', 'qs', '--path', str(shell / 'calendar-quick-quality.qml'),
                             '--no-color'], env=env, capture_output=True, text=True, timeout=30)
    log = result.stdout + result.stderr
    (out / 'quality.log').write_text(log)
    if result.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Unable to assign|Binding loop', log) or 'PASS:' not in log:
        raise SystemExit(log)
    print(next(line for line in log.splitlines() if 'PASS:' in line))

    shutil.copy2(source / 'tests/fixtures/calendar-quick-service.qml', shell / 'calendar-quick-service.qml')
    calendar_python = Path(os.environ.get('SENOMY_CALENDAR_PYTHON', str(Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'senomyos/calendar/runtime/bin/python')))
    if not calendar_python.is_file():
        raise SystemExit('Calendar test runtime unavailable; install the optional calendar runtime or set SENOMY_CALENDAR_PYTHON to its Python interpreter.')
    env.update(PYTHONPATH=str(source.parents[1] / 'components/calendar'), SENOMY_NOTIFICATION_OWNER='none')
    harness = '''import os,pathlib,subprocess,sys,time
backend=subprocess.Popen([sys.argv[1],'-m','senomy_calendar.daemon','--runtime',os.environ['XDG_RUNTIME_DIR']+'/senomyos-calendar'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
try:
 for _ in range(100):
  if pathlib.Path(os.environ['XDG_RUNTIME_DIR']+'/senomyos-calendar/calendar.sock').exists():break
  if backend.poll() is not None:raise RuntimeError('private calendar failed to start')
  time.sleep(0.02)
 result=subprocess.run(['qs','--path',sys.argv[2],'--no-color'],capture_output=True,text=True,timeout=20)
 print(result.stdout+result.stderr);sys.exit(result.returncode)
finally:
 backend.terminate();backend.wait(timeout=5)
'''
    result = subprocess.run(['dbus-run-session','--', 'python3', '-c', harness, str(calendar_python), str(shell / 'calendar-quick-service.qml')],
                            env=env, capture_output=True, text=True, timeout=30)
    log = result.stdout + result.stderr
    (out / 'private-service.log').write_text(log)
    if result.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Unable to assign|Binding loop', log) or 'PASS:' not in log:
        raise SystemExit(log)
    print(next(line for line in log.splitlines() if 'PASS:' in line))

    # Compile the unchanged native host against installed Quickshell/Qt APIs.
    native = work / 'native/shell/quickshell'
    shutil.copytree(source, native)
    for name in ['assets', 'appearance']:
        (work / 'native' / name).symlink_to(source.parents[1] / name, target_is_directory=True)
    (native / 'calendar-compile.qml').write_text('''import QtQuick
import Quickshell
import "components"
Scope { CalendarPopup {anchorItem:null; requestedOpen:false}
Timer {interval:150;running:true;onTriggered:{console.log("PASS: native CalendarPopup compiles");Qt.quit();}} }
''')
    result = subprocess.run(['dbus-run-session', '--', 'qs', '--path', str(native / 'calendar-compile.qml'), '--no-color'],
                            env=env, capture_output=True, text=True, timeout=10)
    log = result.stdout + result.stderr
    (out / 'native-compile.log').write_text(log)
    if result.returncode or re.search(r'ERROR|TypeError|ReferenceError|Unable to assign|Binding loop', log) or 'PASS:' not in log:
        raise SystemExit(log)
    print(next(line for line in log.splitlines() if 'PASS:' in line))
