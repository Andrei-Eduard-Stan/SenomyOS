#!/usr/bin/env python3
"""Exercise the production Audio popup with fake PipeWire and native Qt input.

Only compositor hosting is replaced. Device writes go to fixture objects.
Pass an optional source shell and output directory to review a staged candidate.
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
out = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else repo / 'docs/qa/audio-design-20261023/isolated'
out.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix='senomy-audio-quality-') as directory:
    work = Path(directory)
    shell = prepare_hosts(source, work)
    # Keep the actual native component's size equations, in addition to the
    # body/controls retained by prepare_hosts. This catches content-size drift.
    original = (source / 'components/VolumePopup.qml').read_text()
    sizes = '\n'.join(line for line in original.splitlines()
                      if line.strip().startswith(('implicitWidth:', 'implicitHeight:')))
    host = shell / 'components/VolumePopup.qml'
    host.write_text(host.read_text().replace('    FocusScope {\n        id: card',
                                            sizes + '\n    FocusScope {\n        id: card'))
    shutil.copy2(source / 'tests/fixtures/audio-quick-quality.qml', shell / 'audio-quick-quality.qml')
    runtime = work / 'runtime'
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               XDG_RUNTIME_DIR=str(runtime), XDG_STATE_HOME=str(work / 'state'),
               XDG_CONFIG_HOME=str(work / 'config'), SENOMY_QA_OUT=str(out))
    for key in ['WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE']:
        env.pop(key, None)
    result = subprocess.run(['dbus-run-session', '--', 'qs', '--path', str(shell / 'audio-quick-quality.qml'),
                             '--no-color'], env=env, capture_output=True, text=True, timeout=20)
    log = result.stdout + result.stderr
    (out / 'quality.log').write_text(log)
    if result.returncode or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Unable to assign|Binding loop', log) or 'PASS:' not in log:
        raise SystemExit(log)
    print(next(line for line in log.splitlines() if 'PASS:' in line))
