#!/usr/bin/env python3
"""Read-only probe tests and fake provider lifecycle/schema tests; no OSK launch."""
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
repo = Path(__file__).resolve().parents[1]
shell = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else repo / "shell/quickshell"
subprocess.run([sys.executable,str(shell / "tests/test_osk_capabilities.py")],check=True)
subprocess.run([sys.executable,str(shell / "tests/test_osk_provider.py")],check=True)
subprocess.run([sys.executable,str(shell / "tests/test_osk_lock_state.py")],check=True)
subprocess.run([sys.executable,str(shell / "tests/test_osk_automatic.py")],check=True)
with tempfile.TemporaryDirectory(prefix="senomy-osk-validation-") as runtime:
    env = dict(os.environ,XDG_RUNTIME_DIR=runtime,QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software")
    env.pop("WAYLAND_DISPLAY",None)
    result = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner","-input",str(shell / "tests/tst_OskController.qml")],env=env,capture_output=True,text=True,timeout=20)
    output = result.stdout+result.stderr
    if result.returncode or "FAIL!" in output or not re.search(r"Totals: \d+ passed, 0 failed",output):
        print(output);raise SystemExit("OSK controller fixture failed")
    print(next(line for line in output.splitlines() if line.startswith("Totals:")))
    for fixture,marker in [("osk-capability-test.qml","PASS: OSK capability schema"),("osk-adapter-test.qml","PASS: OSK adapter ownership/readiness")]:
        result = subprocess.run(["qs","--path",str(shell / fixture),"--no-color"],env=env,capture_output=True,text=True,timeout=15)
        output = result.stdout+result.stderr
        if result.returncode or any(value in output for value in ["FAIL:","ERROR","Binding loop","ReferenceError","TypeError"]) or marker not in output:
            print(output);raise SystemExit("OSK fixture failed")
        for line in output.splitlines():
            if "PASS:" in line:print(line)
        if "WARN" in output:print("Passed with Qt diagnostics; not warning-free.")

with tempfile.TemporaryDirectory(prefix="senomy-osk-auto-validation-") as runtime:
    env=dict(os.environ,XDG_RUNTIME_DIR=runtime,QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software")
    env.pop("WAYLAND_DISPLAY",None)
    result=subprocess.run(["/usr/lib/qt6/bin/qmltestrunner","-input",str(shell/"tests/tst_OskAutomatic.qml")],env=env,capture_output=True,text=True,timeout=20)
    output=result.stdout+result.stderr
    if result.returncode or "FAIL!" in output or not re.search(r"Totals: \d+ passed, 0 failed",output):print(output);raise SystemExit("Automatic OSK policy failed")
    print(next(line for line in output.splitlines() if line.startswith("Totals:")))
