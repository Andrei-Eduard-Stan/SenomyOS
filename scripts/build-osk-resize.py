#!/usr/bin/env python3
"""Build the pinned SenomyOS wvkbd extension without installing/replacing tools."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
repo=Path(__file__).resolve().parents[1]
extension=repo/'components/input/osk'
def build(source,destination):
    metadata=json.loads((extension/'upstream.json').read_text())
    for name,digest in metadata['files'].items():
        if hashlib.sha256((source/name).read_bytes()).hexdigest()!=digest:
            raise ValueError('Upstream source differs from the pinned reviewed version: '+name)
    with tempfile.TemporaryDirectory(prefix='senomy-osk-build-') as directory:
        work=Path(directory)/'source';shutil.copytree(source,work,ignore=shutil.ignore_patterns('build-*','wvkbd-mobintl','wvkbd-deskintl','.git'))
        subprocess.run(['git','apply','--unidiff-zero',str(extension/'wvkbd-resize.patch')],cwd=work,check=True)
        shutil.copy2(extension/'senomy-resize.h',work/'senomy-resize.h')
        subprocess.run(['make','-j2','LAYOUT=mobintl','wvkbd-mobintl'],cwd=work,check=True)
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(work/'wvkbd-mobintl',destination)
if __name__=='__main__':
    if len(sys.argv)!=3:raise SystemExit('usage: build-osk-resize.py PINNED_UPSTREAM_DIRECTORY OUTPUT_BINARY')
    build(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).absolute())
