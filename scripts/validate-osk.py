#!/usr/bin/env python3
"""Read-only probe tests and fake provider lifecycle/schema tests; no OSK launch."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
repo = Path(__file__).resolve().parents[1]
shell = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else repo / "shell/quickshell"
subprocess.run([sys.executable,str(shell / "tests/test_osk_capabilities.py")],check=True)
with tempfile.TemporaryDirectory(prefix="senomy-osk-validation-") as runtime:
    env = dict(os.environ,XDG_RUNTIME_DIR=runtime,QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software")
    env.pop("WAYLAND_DISPLAY",None)
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner","-input",str(shell / "tests/tst_OskController.qml")],env=env,capture_output=True,text=True,timeout=20)
    output = result.stdout+result.stderr
    if result.returncode or "FAIL!" in output or "Totals: 14 passed, 0 failed" not in output:
        print(output);raise SystemExit("OSK controller fixture failed")
    print(next(line for line in output.splitlines() if line.startswith("Totals:")))
    result = subprocess.run(["qs","--path",str(shell / "osk-capability-test.qml"),"--no-color"],env=env,capture_output=True,text=True,timeout=15)
    output = result.stdout+result.stderr
    if result.returncode or any(marker in output for marker in ["FAIL:","ERROR","Binding loop","ReferenceError","TypeError"]) or "PASS: OSK capability schema" not in output:
        print(output);raise SystemExit("OSK capability fixture failed")
    for line in output.splitlines():
        if "PASS:" in line:print(line)
