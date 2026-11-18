#!/usr/bin/env python3
"""Read-only bounded OSK probe. No keyboard startup, signals or configuration writes."""
import json
import os
import re
import shutil
import subprocess
import sys

PROVIDERS = ("wvkbd-mobintl", "wvkbd-deskintl")
# Base protocol requirements; actual provider-version and text-entry acceptance
# remain separate. Input-method-v2 is optional for the manual-control path.
REQUIRED = {"wl_compositor": 6, "wl_shm": 1, "wl_seat": 1,
            "zwlr_layer_shell_v1": 1, "xdg_wm_base": 1,
            "zwp_virtual_keyboard_manager_v1": 1}
LIMIT = 256 * 1024


def parse_protocols(output):
    if len(output) > LIMIT:
        raise ValueError("oversized probe output")
    interfaces = {}
    for name, version in re.findall(r"interface:\s*'([a-zA-Z0-9_]+)'\s*,\s*version:\s*(\d+)", output):
        interfaces[name] = max(interfaces.get(name, 0), int(version))
    if not interfaces:
        raise ValueError("unrecognized probe output")
    return interfaces


def detect():
    provider = next((name for name in PROVIDERS if shutil.which(name)), "")
    result = {"ok": True, "providerInstalled": bool(provider), "provider": provider,
              "protocolState": "unknown", "manualCandidate": False,
              "integrated": False, "missingProtocols": [],
              "autoInputMethodAdvertised": False, "message": ""}
    if not os.environ.get("WAYLAND_DISPLAY"):
        result["message"] = "Wayland session is not available; protocol support is unknown."
        return result
    probe = shutil.which("wayland-info")
    if not probe:
        result["message"] = "Wayland protocol inspection tool is unavailable; compatibility is unknown."
        return result
    try:
        completed = subprocess.run([probe], capture_output=True, text=True, timeout=5, check=True)
        interfaces = parse_protocols(completed.stdout)
    except (OSError, subprocess.SubprocessError, ValueError):
        result["message"] = "Wayland protocol inspection failed; compatibility is unknown."
        return result
    result["missingProtocols"] = [name for name, minimum in REQUIRED.items() if interfaces.get(name, 0) < minimum]
    result["protocolState"] = "incompatible" if result["missingProtocols"] else "advertised"
    result["autoInputMethodAdvertised"] = interfaces.get("zwp_input_method_manager_v2", 0) >= 1
    result["manualCandidate"] = bool(provider) and not result["missingProtocols"]
    result["message"] = ("Required manual-control protocols are advertised; provider-version, lifecycle and text entry remain unverified."
                         if not result["missingProtocols"] else "Required OSK protocols are missing or below their minimum version.")
    return result


def main(args):
    if args != ["detect"]:
        print(json.dumps({"ok": False, "message": "Unsupported OSK probe action."}))
        return 1
    print(json.dumps(detect()))
    return 0

if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
