#!/usr/bin/env python3
"""Isolated wallpaper lifecycle checks; never connects to the desktop."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def until(predicate):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.1)
    raise AssertionError("wallpaper update timed out")


with tempfile.TemporaryDirectory(prefix="senomy-wallpaper-test-") as tmp:
    root = Path(tmp)
    image = root / "image with spaces.png"
    image.write_text("first")
    default = root / "default.png"
    default.write_text("default")
    config = root / "wallpaper.json"
    config.write_text(json.dumps({"schema_version": 1, "source": str(image)}))
    log = root / "provider.log"
    provider = root / "provider"
    provider.write_text('''#!/usr/bin/env python3
import os, pathlib, signal, sys, time
image=pathlib.Path(sys.argv[-1]).read_text()
if image == 'invalid': sys.exit(1)
with open(os.environ['TEST_LOG'],'a') as f: f.write(str(os.getpid())+' '+image+'\\n')
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
while True: time.sleep(1)
''')
    provider.chmod(0o755)
    env = dict(os.environ, XDG_RUNTIME_DIR=tmp, TEST_LOG=str(log))
    argv = ['python3', str(ROOT / 'components/desktop/scripts/senomy-wallpaper-watch.py'), str(provider), str(default), 'fill', str(config)]
    owner = subprocess.Popen(argv, env=env)
    def lines(): return log.read_text().splitlines() if log.exists() else []
    try:
        until(lambda: len(lines()) == 1)
        duplicate = subprocess.run(argv, env=env, timeout=2)
        assert duplicate.returncode == 0
        image.write_text('edited')
        until(lambda: len(lines()) == 2)
        replacement = root / 'replacement'
        replacement.write_text('replaced')
        replacement.replace(image)
        until(lambda: len(lines()) == 3)
        image.write_text('invalid')
        time.sleep(1.5)
        assert len(lines()) == 3
        os.kill(int(lines()[-1].split()[0]), 0)
        config.write_text('{')
        time.sleep(1)
        assert len(lines()) == 3
        config.write_text(json.dumps({'schema_version': 1, 'source': str(default), 'mode': 'fit'}))
        until(lambda: len(lines()) == 4)
        # Idle owner does not repeatedly launch providers.
        time.sleep(1.2)
        assert len(lines()) == 4
    finally:
        owner.terminate()
        owner.wait(timeout=4)
    for row in lines():
        try: os.kill(int(row.split()[0]), 0)
        except ProcessLookupError: pass
        else: raise AssertionError('provider leaked after owner shutdown')
print('Wallpaper: edits, atomic replacement, invalid input retention, selection, single owner and cleanup passed.')
