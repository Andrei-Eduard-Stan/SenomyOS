#!/usr/bin/env python3
"""Read-only Hyprland inventory. Never collect serials, addresses or key events."""
import json
import subprocess


def collect(command, normalize):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=3, check=True)
        return {"available": True, "items": normalize(json.loads(result.stdout)), "error": ""}
    except FileNotFoundError:
        error = "Hyprland control tool is unavailable."
    except subprocess.TimeoutExpired:
        error = "Hyprland inventory request timed out."
    except subprocess.CalledProcessError:
        error = "Hyprland inventory request failed."
    except (ValueError, TypeError, KeyError):
        error = "Hyprland returned an unsupported inventory response."
    return {"available": False, "items": [], "error": error}


def displays(data):
    if not isinstance(data, list) or any(not isinstance(item, dict) for item in data):
        raise ValueError("Expected display list")
    keys = ("name", "make", "model", "width", "height", "refreshRate", "scale", "x", "y", "transform", "disabled", "dpmsStatus", "focused", "mirrorOf", "availableModes")
    return [{key: item.get(key) for key in keys} for item in data]


def inputs(data):
    if not isinstance(data, dict) or not any(key in data for key in ("keyboards", "mice", "touch", "tablets", "switches")):
        raise ValueError("Expected input groups")
    result = []
    for group, kind in (("keyboards", "Keyboard"), ("mice", "Pointer"), ("touch", "Touch"), ("tablets", "Tablet"), ("switches", "Switch")):
        items = data.get(group, [])
        if not isinstance(items, list):
            raise ValueError("Expected device list")
        for item in items:
            if not isinstance(item, dict):
                raise ValueError("Expected device object")
            result.append({"kind": kind, "name": item.get("name"),
                           "layout": item.get("active_keymap") if group == "keyboards" else None})
    return result


if __name__ == "__main__":
    from display_core import snapshot
    try:
        result = snapshot()
        result["displays"] = {"available": True, "items": result["displays"], "error": ""}
        result["inputs"] = collect(["hyprctl", "-j", "devices"], inputs)
        print(json.dumps(result, separators=(",", ":")))
    except Exception as error:
        print(json.dumps({"displays": {"available": False, "items": [], "error": str(error)[:300]},
                          "inputs": {"available": False, "items": [], "error": "Inventory unavailable"}}))
