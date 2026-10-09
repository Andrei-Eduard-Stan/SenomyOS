#!/usr/bin/env python3
"""Fixed-argv confirmed OSK exec and read-only readiness observation. No signals."""
import ctypes
import errno
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import sys
spec = importlib.util.spec_from_file_location("osk_capabilities",Path(__file__).with_name("osk-capabilities.py"))
capabilities = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capabilities)


def arm_parent_death_signal():
    parent = os.getppid()
    if parent <= 1:
        raise OSError("Shell parent is no longer available")
    libc = ctypes.CDLL(None,use_errno=True)
    libc.prctl.argtypes = [ctypes.c_int,ctypes.c_ulong,ctypes.c_ulong,ctypes.c_ulong,ctypes.c_ulong]
    libc.prctl.restype = ctypes.c_int
    if libc.prctl(1,signal.SIGTERM,0,0,0) != 0:
        raise OSError("Cannot establish owned-child shutdown")
    if os.getppid() != parent:
        raise OSError("Shell parent changed during startup")


def launch(name):
    if name not in capabilities.PROVIDERS:
        return {"ok":False,"message":"Unsupported keyboard provider."}
    result = capabilities.detect()
    binary = shutil.which(name)
    if not result["manualCandidate"] or not binary:
        return {"ok":False,"message":"Keyboard provider or required protocols are unavailable."}
    try:
        # Same PID becomes the keyboard; never detached, and no pressed-key logging.
        if os.stat(binary).st_mode & 0o6000:
            raise OSError("Privileged provider binaries are unsupported")
        try:
            file_capabilities = os.getxattr(binary,"security.capability")
        except OSError as error:
            if error.errno not in [errno.ENODATA,errno.ENOTSUP]:
                raise
            file_capabilities = b""
        if file_capabilities:
            raise OSError("Provider file capabilities are unsupported")
        arm_parent_death_signal()
        # Pinned Senomy build opts in; ordinary upstream binaries retain fixed argv.
        try:
            with open(binary,"rb") as executable:
                metadata=executable.read(4*1024*1024)
            resize=b"--senomy-resize" in metadata and b"geometry-only telemetry" in metadata
        except OSError:resize=False
        argv=[binary,"--senomy-resize","--no-popup"] if resize else [binary]
        os.execv(binary,argv)
    except OSError:
        return {"ok":False,"message":"Keyboard provider could not be executed."}


def observe(pid,name):
    if name not in capabilities.PROVIDERS or not pid.isdecimal() or int(pid) < 1:
        return {"ok":False,"ready":False}
    binary = shutil.which(name)
    if not binary:
        return {"ok":True,"ready":False}
    try:
        proc = Path("/proc") / pid
        executable = (proc / "exe").resolve(strict=True)
        if executable != Path(binary).resolve(strict=True):
            return {"ok":True,"ready":False}
        masks = {}
        for line in (proc / "status").read_text().splitlines():
            key,_,value = line.partition(":")
            if key in ["SigBlk","SigCgt"]:
                masks[key] = int(value.strip(),16)
        handled = masks.get("SigBlk",0) | masks.get("SigCgt",0)
        required = (1 << (signal.SIGUSR1 - 1)) | (1 << (signal.SIGUSR2 - 1))
        return {"ok":True,"ready":handled & required == required}
    except (OSError,ValueError,RuntimeError):
        return {"ok":True,"ready":False}


def main(args):
    if len(args)==2 and args[0]=="launch-confirmed":
        result=launch(args[1])
    elif len(args)==3 and args[0]=="observe":
        result=observe(args[1],args[2])
    else:
        result={"ok":False,"message":"Unsupported keyboard operation."}
    print(json.dumps(result))
    return 0 if result["ok"] else 1
if __name__ == "__main__":raise SystemExit(main(sys.argv[1:]))
