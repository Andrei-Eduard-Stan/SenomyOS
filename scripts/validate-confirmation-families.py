#!/usr/bin/env python3
"""Fake action providers only; substitutes the session compositor window host."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
shell = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else repo / "shell/quickshell"
with tempfile.TemporaryDirectory(prefix="senomy-confirmation-families-") as directory:
    work = Path(directory)
    copied = work / "shell/quickshell"
    shutil.copytree(shell, copied, symlinks=True)
    for name in ("appearance", "assets"):
        (work / name).symlink_to(shell.parents[1] / name, target_is_directory=True)
    runtime = work / "runtime"
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
    env.pop("WAYLAND_DISPLAY", None)
    def run(fixture, marker):
        result = subprocess.run(["qs", "--path", str(copied / fixture), "--no-color"], env=env,
                                capture_output=True, text=True, timeout=20)
        output = result.stdout + result.stderr
        bad = ("FAIL:", "ERROR", "Binding loop", "ReferenceError", "TypeError")
        if result.returncode or any(value in output for value in bad) or marker not in output:
            print(output)
            raise SystemExit("confirmation fixture failed")
        for line in output.splitlines():
            if "PASS:" in line:
                print(line)
        if "WARN" in output:
            print("Passed with Qt diagnostics; not warning-free.")
    run("confirmation-focus-test.qml", "PASS: selection, network/Bluetooth, notification and display confirmation")
    power = copied / "components/PowerPopup.qml"
    source = power.read_text().replace("import Quickshell.Hyprland", "import QtQuick.Window").replace("PopupWindow {", "Window {", 1)
    source = source.replace("    implicitWidth:", "    width:").replace("    implicitHeight:", "    height:")
    source = "\n".join(line for line in source.splitlines() if not line.strip().startswith(("anchor.", "grabFocus:"))) + "\n"
    start = source.index("    HyprlandFocusGrab {")
    end = source.index("    Timer {", start)
    source = source[:start] + source[end:]
    power.write_text(source)
    run("power-focus-test.qml", "PASS: session confirmation defaults Cancel")
