#!/usr/bin/env python3
"""Contextual menus on private Qt/D-Bus hosts; no live shell/device actions."""
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
shell = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else repo / 'shell/quickshell'
out = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else Path(tempfile.mkdtemp(prefix='context-actions-results-'))
out.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='context-actions-') as directory:
    work = Path(directory)
    copied = work / 'shell/quickshell'
    shutil.copytree(shell, copied, symlinks=True)
    for name in ['assets', 'appearance']:
        (work / name).symlink_to(shell.parents[1] / name, target_is_directory=True)
    runtime = work / 'runtime'
    runtime.mkdir(mode=0o700)
    commands = work / 'bin'
    commands.mkdir()
    clipboard = commands / 'wl-copy'
    clipboard.write_text('#!/usr/bin/env bash\ncat > "$SENOMY_CLIPBOARD_FIXTURE"\n')
    clipboard.chmod(0o755)
    env = dict(os.environ, LANG='C.UTF-8', QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(work / 'config'), XDG_STATE_HOME=str(work / 'state'),
               SENOMY_QA_OUT=str(out), SENOMY_CLIPBOARD_FIXTURE=str(work / 'clipboard.txt'),
               PATH=str(commands) + os.pathsep + os.environ['PATH'])
    env.pop('WAYLAND_DISPLAY', None)
    def run(name, fixture):
        shutil.copy2(shell / 'tests/fixtures' / (fixture + '.qml'), copied / (fixture + '-test.qml'))
        process = subprocess.Popen(['/usr/bin/dbus-run-session', '--dbus-daemon=/usr/bin/dbus-daemon', '--', '/usr/bin/qs', '--path', str(copied / (fixture + '-test.qml')), '--no-color'],
                                   env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
        try:
            stdout, stderr = process.communicate(timeout=25)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=3)
            (out / (name + '.log')).write_text(stdout + stderr)
            print(stdout + stderr)
            raise SystemExit('Private fixture timed out')
        log = stdout + stderr
        (out / (name + '.log')).write_text(log)
        if process.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign', log) or 'PASS:' not in log:
            print(log)
            raise SystemExit(1)
        print(next(line for line in log.splitlines() if 'PASS:' in line))
    run('lens-context', 'lens-context')
    if len(sys.argv)>3 and sys.argv[3]=='--motion-only':print('SKIP: unrelated contextual-views fixture references removed labels; not motion coverage')
    else:run('contextual-views', 'contextual-views')
    run('context-actions', 'context-actions')
    assert 'Sanitized fixture' in (work / 'clipboard.txt').read_text()
    for path in (work / 'state/senomyos/component-reports').glob('*.txt'):
        assert path.stat().st_mode & 0o777 == 0o600
    assert not list((work / 'state/senomyos/component-reports').glob('*.png'))
    # Existing Performance export contract, including PNG and mocked clipboard.
    run('performance-exports', 'component-export')
    assert '17%' in (work / 'clipboard.txt').read_text()
    assert len(list((work / 'state/senomyos/component-reports').glob('*.png'))) == 1
    clipboard.write_text('#!/usr/bin/env bash\nexit 9\n')
    env['SENOMY_COPY_FAILURE'] = '1'
    run('clipboard-failure', 'context-actions')
    missing = work / 'no-clipboard'
    missing.mkdir()
    (missing / 'python3').symlink_to(sys.executable)
    env['PATH'] = str(missing)
    env.pop('SENOMY_COPY_FAILURE', None)
    run('clipboard-unavailable', 'context-actions')
print('PASS: private report modes, bounded evidence serialization and unchanged Performance copy/text/PNG contract')
