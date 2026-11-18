#!/usr/bin/env python3
"""Own swaybg and refresh a selected local image after stable file changes."""
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

MODES = {"fill", "fit", "stretch", "center", "tile"}


def stamp(path):
    try:
        s = path.stat()
        return (s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns)
    except OSError:
        return None


def selection(config, default, mode):
    if not config.exists():
        return default, mode
    data = json.loads(config.read_text())
    if not isinstance(data, dict) or data.get("schema_version") != 1:
        raise ValueError("wallpaper settings require schema_version 1")
    source = data.get("source", "")
    mode = data.get("mode", mode)
    if not isinstance(source, str) or mode not in MODES:
        raise ValueError("invalid wallpaper source or mode")
    path = Path(source).expanduser() if source else default
    if not path.is_absolute():
        path = config.parent / path
    if not path.is_file():
        raise ValueError("selected wallpaper is unavailable")
    return path, mode


def stop(child):
    if child is not None and child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=2)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()


def main():
    provider, default, mode, config = sys.argv[1:]
    default, config = Path(default), Path(config)
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", str(config.parent)))
    runtime.mkdir(parents=True, exist_ok=True)
    lock = (runtime / "senomy-wallpaper.lock").open("w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("SenomyOS wallpaper: already running", file=sys.stderr)
        return 0
    running = True

    def shutdown(*_):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    child = None
    applied = pending = failed = None
    last_error = None
    retry_at = 0
    try:
        while running:
            try:
                path, selected_mode = selection(config, default, mode)
                last_error = None
            except (ValueError, OSError, TypeError) as error:
                if str(error) != last_error:
                    print(f"SenomyOS wallpaper: {error}; retaining current image", file=sys.stderr, flush=True)
                    last_error = str(error)
                if child is not None and child.poll() is None:
                    time.sleep(.5)
                    continue
                path, selected_mode = default, mode
            signature = (str(path), selected_mode, stamp(path))
            if child is not None and child.poll() is not None:
                child = None
                applied = None
                retry_at = time.monotonic() + 5
            # Two matching samples debounce writes and catch atomic replacements.
            # Only stat/read a tiny config while idle; never decode or spawn then.
            if signature == pending and signature != applied and signature != failed and time.monotonic() >= retry_at:
                candidate = subprocess.Popen([provider, "-c", "#08090b", "-m", selected_mode, "-i", str(path)])
                try:
                    candidate.wait(timeout=.3)
                except subprocess.TimeoutExpired:
                    stop(child)
                    child, applied = candidate, signature
                    print(f"SenomyOS wallpaper: loaded {path}", flush=True)
                else:
                    failed = signature
                    print("SenomyOS wallpaper: image failed to load; retaining current image", file=sys.stderr, flush=True)
            if signature != pending:
                failed = None
            pending = signature
            time.sleep(.5)
    finally:
        stop(child)
        lock.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
