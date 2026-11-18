#!/usr/bin/env python3
"""Build the local Hyprland Caps component; no installation or plugin loading."""
import hashlib
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys
repo=Path(__file__).resolve().parents[1]
def build(destination):
    flags=shlex.split(subprocess.check_output(['pkg-config','--cflags','hyprland'],text=True))
    include=next((Path(flag[2:])/'src/version.h' for flag in flags if flag.startswith('-I') and (Path(flag[2:])/'src/version.h').is_file()),None)
    if include is None:raise ValueError('Missing Hyprland SDK headers')
    version=include.read_text();match=re.search(r'#define GIT_COMMIT_HASH\s+"([a-f0-9]{40})"',version)
    if not match:raise ValueError('Missing exact Hyprland SDK identity')
    destination.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run(['c++','-std=c++23','-shared','-fPIC','-O2','-Wall','-Wextra',*flags,str(repo/'components/input/osk/hyprland/caps-sync.cpp'),'-o',str(destination)],check=True)
    destination.with_suffix('.json').write_text(json.dumps({'commit':match[1],'sha256':hashlib.sha256(destination.read_bytes()).hexdigest()},indent=2)+'\n')
if __name__=='__main__':
    if len(sys.argv)!=2:raise SystemExit('usage: build-osk-caps-sync.py OUTPUT_LIBRARY.so')
    build(Path(sys.argv[1]).absolute())
