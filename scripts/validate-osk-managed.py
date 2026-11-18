#!/usr/bin/env python3
"""Actual Quickshell process lifecycle with an isolated C stub; emits no input."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
repo = Path(__file__).resolve().parents[1]
shell = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo / "shell/quickshell"
def alive(pid):
    try:
        status=Path("/proc",str(pid),"status").read_text()
        state=next(line for line in status.splitlines() if line.startswith("State:"))
        return state.split()[1] != "Z"
    except (FileNotFoundError,ProcessLookupError):
        return False

with tempfile.TemporaryDirectory(prefix="senomy-osk-managed-") as directory:
    root=Path(directory);copied=root/"shell/quickshell"
    shutil.copytree(shell,copied,symlinks=True)
    for name in ["assets","appearance"]:(root/name).symlink_to(shell.parents[1]/name,target_is_directory=True)
    tools=root/"tools";tools.mkdir();binary=tools/"wvkbd-mobintl"
    subprocess.run(["cc","-Wall","-Wextra","-Werror",str(shell/"tests/fixtures/osk-stub.c"),"-o",str(binary)],check=True)
    probe=tools/"wayland-info"
    protocols={"wl_compositor":6,"wl_shm":1,"wl_seat":1,"zwlr_layer_shell_v1":1,"xdg_wm_base":1,"zwp_virtual_keyboard_manager_v1":1}
    text="\n".join("interface: '%s', version: %d, name: 1"%(name,version) for name,version in protocols.items())
    probe.write_text("#!"+sys.executable+"\nprint("+repr(text)+")\n");probe.chmod(0o700)
    runtime=root/"runtime";runtime.mkdir(mode=0o700);record=root/"events";log=root/"quickshell.log"
    env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software",WAYLAND_DISPLAY="nonexistent-stub-session",PATH=str(tools)+os.pathsep+os.environ.get("PATH",""),SENOMY_OSK_STUB_RECORD=str(record))
    original_fixture=(copied/"osk-managed-test.qml").read_text()
    with log.open("w") as output:
        process=subprocess.Popen(["qs","--path",str(copied/"osk-managed-test.qml"),"--no-color"],env=env,stdout=output,stderr=subprocess.STDOUT)
        try:
            deadline=time.monotonic()+15;pid=None
            while time.monotonic()<deadline:
                data=log.read_text()
                if any(marker in data for marker in ["FAIL:","ERROR","ReferenceError","TypeError"]):raise RuntimeError(data)
                match=re.search(r"READY: managed stub PID (\d+)",data)
                if match:pid=int(match.group(1));break
                if process.poll() is not None:raise RuntimeError(data)
                time.sleep(0.05)
            if pid is None:raise RuntimeError("Managed stub did not become ready: "+log.read_text())
            if Path("/proc") .joinpath(str(pid),"exe").resolve()!=binary.resolve():raise RuntimeError("Fixture child identity mismatch")
            (copied/"osk-managed-test.qml").write_text("import QtQuick\nimport Quickshell\nScope { }\n")
            deadline=time.monotonic()+5
            while time.monotonic()<deadline and alive(pid):time.sleep(0.05)
            if alive(pid):raise RuntimeError("Managed fixture child survived configuration reload")
            (copied/"osk-managed-test.qml").write_text(original_fixture)
            deadline=time.monotonic()+15;shutdown_pid=None
            while time.monotonic()<deadline:
                matches=re.findall(r"READY: managed stub PID (\d+)",log.read_text())
                if matches and int(matches[-1]) != pid:shutdown_pid=int(matches[-1]);break
                if process.poll() is not None:raise RuntimeError(log.read_text())
                time.sleep(0.05)
            if shutdown_pid is None:raise RuntimeError("Reloaded fixture did not become ready")
            if Path("/proc",str(shutdown_pid),"exe").resolve()!=binary.resolve():raise RuntimeError("Shutdown fixture identity mismatch")
            process.terminate();process.wait(timeout=5)
            deadline=time.monotonic()+3
            while time.monotonic()<deadline and alive(shutdown_pid):time.sleep(0.05)
            if alive(shutdown_pid):raise RuntimeError("Managed fixture child survived shell exit")
            events=[line.split() for line in record.read_text().splitlines()]
            if not any(event=="10" for _,event in events) or not any(event=="12" for _,event in events):raise RuntimeError("Owned show/hide was not observed")
            if len({event_pid for event_pid,event in events if event=="0"})!=4:raise RuntimeError("Expected exactly four sequential owned fixture children")
            print("PASS: actual managed-process startup/readiness, owned show/hide, panel survival, confirmed exit, reload cleanup and shell-exit cleanup; disposable stub only")
        finally:
            if process.poll() is None:process.terminate()
            process.wait(timeout=5)
