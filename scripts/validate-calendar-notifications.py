#!/usr/bin/env python3
"""Production date and notification interactions, with inert private providers."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from qa_remaining_hosts import prepare_hosts

repo = Path(__file__).resolve().parents[1]
shell = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else repo / "shell/quickshell"
output = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else None
with tempfile.TemporaryDirectory(prefix="senomy-calendar-entry-qa-") as directory:
    work = Path(directory)
    copied = prepare_hosts(shell, work)
    fixture = copied / "calendar-notifications-entry-test.qml"
    shutil.copy2(shell / "tests/fixtures/calendar-notifications-entry.qml", fixture)
    captures = output or work / "captures"
    captures.mkdir(parents=True, exist_ok=True)
    runtime = work / "runtime"
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
               XDG_RUNTIME_DIR=str(runtime), XDG_STATE_HOME=str(work / "state"),
               XDG_CONFIG_HOME=str(work / "config"), SENOMY_QA_OUT=str(captures))
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["dbus-run-session", "--", "qs", "--path", str(fixture), "--no-color"],
                            env=env, capture_output=True, text=True, timeout=25)
    log = result.stdout + result.stderr
    (captures / "calendar-notifications-entry.log").write_text(log)
    if result.returncode or re.search(r"FAIL:|ERROR|ReferenceError|TypeError|Binding loop|invalid context", log) or "PASS:" not in log:
        print(log)
        raise SystemExit(1)
    print(next(line for line in log.splitlines() if "PASS:" in line))
