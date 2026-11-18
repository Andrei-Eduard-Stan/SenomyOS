#!/usr/bin/env python3
"""Build the scoped native GTK3 Thunar module on this host; no installation."""
from pathlib import Path
import os
import shlex
import shutil
import subprocess
import sys
import tempfile

root=Path(__file__).resolve().parent.parent
source=root/'components/file-manager/thunar/native/senomy-thunar.c'
target=source.with_name('libsenomy-thunar.so')
for executable in ['cc','pkg-config']:
    if not shutil.which(executable):
        sys.exit(f'{executable} is required to build the native GTK3 module; no package was installed.')
flags=subprocess.run(['pkg-config','--cflags','--libs','gtk+-3.0','thunarx-3'],capture_output=True,text=True,check=True).stdout
with tempfile.TemporaryDirectory(prefix='senomy-thunar-build-') as work:
    output=Path(work)/target.name
    subprocess.run(['cc','-O2','-Wall','-Wextra','-Wno-unused-parameter','-shared','-fPIC',str(source),str(source.with_name('senomy-workspace.c')),'-o',str(output),*shlex.split(flags)],check=True)
    staged=target.with_suffix('.so.tmp')
    shutil.copyfile(output,staged);staged.chmod(0o644);staged.replace(target)
print(target)
