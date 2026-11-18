#!/usr/bin/env python3
"""Isolated input tools checks: mocked launches and fake UI provider only."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
repo = Path(__file__).resolve().parents[1]
shell = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else repo / "shell/quickshell"
subprocess.run([sys.executable,str(shell / "tests/test_native_input_tools.py")],check=True)
with tempfile.TemporaryDirectory(prefix="senomy-native-input-") as runtime:
    env = dict(os.environ,XDG_RUNTIME_DIR=runtime,QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software")
    env.pop("WAYLAND_DISPLAY",None)
    result = subprocess.run(["qs","--path",str(shell / "native-input-test.qml"),"--no-color"],env=env,capture_output=True,text=True,timeout=15)
    output = result.stdout + result.stderr
    if result.returncode or any(marker in output for marker in ["FAIL:","ERROR","Binding loop","ReferenceError","TypeError"]) or "PASS: detected input-method handoff" not in output:
        print(output)
        raise SystemExit("input tools fixture failed")
    for line in output.splitlines():
        if "PASS:" in line: print(line)
    if "WARN" in output: print("Passed with Qt diagnostics; not warning-free.")
