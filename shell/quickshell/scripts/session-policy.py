#!/usr/bin/env python3
"""Read and persist the bounded SenomyOS idle policy without restarting it."""
import json
import os
from pathlib import Path
import shutil
import sys

DEFAULTS = {"lockSeconds": 300, "displayOffSeconds": 600}


def config_root():
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))


def preference_file():
    return config_root() / "senomyos" / "session-policy.json"


def hypridle_file():
    return config_root() / "hypr" / "hypridle.conf"


def validate(value):
    if not isinstance(value, dict):
        raise ValueError("Session policy preferences must be an object")
    lock_seconds = value.get("lockSeconds", DEFAULTS["lockSeconds"])
    display_seconds = value.get("displayOffSeconds", DEFAULTS["displayOffSeconds"])
    if not isinstance(lock_seconds, int) or lock_seconds < 60 or lock_seconds > 3600 or lock_seconds % 60:
        raise ValueError("Lock timeout must use whole minutes between 1 and 60")
    if not isinstance(display_seconds, int) or display_seconds < 120 or display_seconds > 7200 or display_seconds % 60:
        raise ValueError("Display-off timeout must use whole minutes between 2 and 120")
    if display_seconds <= lock_seconds:
        raise ValueError("Display-off timeout must be later than the lock timeout")
    return {"lockSeconds": lock_seconds, "displayOffSeconds": display_seconds}


def read_preferences():
    path = preference_file()
    if not path.exists():
        return dict(DEFAULTS)
    return validate(json.loads(path.read_text()))


def render_hypridle(value):
    return f"""general {{
    lock_cmd = pidof hyprlock || $HOME/.local/bin/senomy-lock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
    ignore_dbus_inhibit = false
}}

listener {{
    timeout = {value['lockSeconds']}
    on-timeout = loginctl lock-session
}}

listener {{
    timeout = {value['displayOffSeconds']}
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}}
"""


def atomic_write(path, content):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(content)
    os.chmod(temporary, 0o600)
    os.replace(temporary, path)


def write_preferences(value):
    atomic_write(preference_file(), json.dumps(value, indent=2) + "\n")
    atomic_write(hypridle_file(), render_hypridle(value))


def response(value, saved=False):
    return {
        "ok": True,
        "available": shutil.which("hypridle") is not None,
        "configured": hypridle_file().is_file(),
        "lockSeconds": value["lockSeconds"],
        "displayOffSeconds": value["displayOffSeconds"],
        "suspendEnabled": False,
        "lockBeforeSleep": True,
        "saved": saved,
        "activationRequired": saved,
    }


def main(argv):
    try:
        operation = argv[1] if len(argv) > 1 else "get"
        if operation == "get":
            result = response(read_preferences())
        elif operation == "apply":
            if len(argv) != 3:
                raise ValueError("Missing session policy preference payload")
            value = validate(json.loads(argv[2]))
            write_preferences(value)
            result = response(value, saved=True)
        else:
            raise ValueError("Unsupported session policy operation")
        print(json.dumps(result, separators=(",", ":")))
        return 0
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}, separators=(",", ":")))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
