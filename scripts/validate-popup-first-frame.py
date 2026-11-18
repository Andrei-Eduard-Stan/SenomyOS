#!/usr/bin/env python3
"""Exercise popup first-frame lifetime on private offscreen Qt windows."""
from pathlib import Path
import os, re, shutil, subprocess, sys, tempfile
repo = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo / "shell/quickshell"
with tempfile.TemporaryDirectory(prefix="senomy-popup-frame-") as directory:
    work=Path(directory); shell=work/"shell/quickshell"
    shutil.copytree(source,shell,symlinks=True)
    for name in ["assets","appearance"]:
        (work/name).symlink_to(source.parents[1]/name,target_is_directory=True)
    popup=shell/"components/interaction/QuickPopoverWindow.qml"
    code=popup.read_text().replace("PopupWindow {","Window {",1).replace("import Quickshell.Hyprland", "")
    code=code.replace("    mask: Region { x: 0; y: 0; width: root.requestedOpen ? root.width : 0; height: root.requestedOpen ? root.height : 0 }\n", "")
    code=code.replace("    grabFocus: false\n", "").replace("    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Resize\n", "")
    code=code.replace("    id: root", "    id: root\n    property QtObject anchor: QtObject { function updateAnchor() {} }",1).replace("HyprlandFocusGrab {", "FakeFocusGrab {")
    popup.write_text(code)
    (popup.parent/"FakeFocusGrab.qml").write_text("import QtQuick\nItem {property bool active:false;property var windows:[];signal cleared()}\n")
    shutil.copy2(source/"tests/fixtures/popup-first-frame.qml",shell/"popup-first-frame.qml")
    runtime=work/"runtime";runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software",XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/"config"),XDG_STATE_HOME=str(work/"state"))
    for key in ["WAYLAND_DISPLAY","HYPRLAND_INSTANCE_SIGNATURE"]:env.pop(key,None)
    result=subprocess.run(["dbus-run-session","--","qs","-p",str(shell/"popup-first-frame.qml"),"--no-color"],env=env,capture_output=True,text=True,timeout=15)
    log=result.stdout+result.stderr
    if result.returncode or re.search(r"FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign",log) or "PASS:" not in log:
        raise SystemExit(log)
    print(next(line for line in log.splitlines() if "PASS:" in line))
