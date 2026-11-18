#!/usr/bin/env python3
"""Detect optional input tools; launch only the fixed Fcitx5 configuration editor."""
import json
import shutil
import subprocess
import sys
from pathlib import Path

def launch_tool(tool, args=()):
    # Read-only provider functions remain available if deployment is incomplete.
    sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "scripts"))
    try:
        from senomy_app_launch import launch_tool as independent_launch
    except ImportError:
        return {"ok":False,"state":"unavailable","message":"The independent application launcher is unavailable; no application was started."}
    return independent_launch(tool, args)



def detect():
    return {"ok": True, "editorAvailable": bool(shutil.which("fcitx5-configtool")),
            "engineInstalled": bool(shutil.which("fcitx5")),
            "oskIntegrated": False,
            "oskMessage": "On-screen keyboard integration is not configured or validated."}


def launch_editor():
    editor = shutil.which("fcitx5-configtool")
    if not editor:
        return {"ok": False, "state": "unavailable", "message": "Fcitx5 settings is not installed."}
    try:
        result=launch_tool("ime")
        if not result["ok"]:return result
    except OSError:
        return {"ok": False, "state": "failed", "message": "Fcitx5 settings could not be started."}
    return {"ok": True, "state": "started",
            "message": "Fcitx5 settings process started. Input-method setup and text entry remain unverified."}


def main(args):
    if args == ["detect"]:
        result = detect()
    elif args == ["open-ime"]:
        result = launch_editor()
    else:
        result = {"ok": False, "state": "failed", "message": "Unsupported input-tool action."}
    print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
