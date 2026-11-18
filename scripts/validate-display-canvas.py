#!/usr/bin/env python3
"""Test actual canvas/draft with inert colour-token substitutes, no native plugin."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='senomy-display-canvas-') as tmp:
    base=Path(tmp)
    for directory in ('tests','services','components','config'):(base/directory).mkdir()
    for rel in ['tests/tst_DisplayCanvas.qml','services/DisplayDraft.qml','services/DisplayGeometry.js','components/DisplayCanvas.qml']:
        shutil.copyfile(root/'shell/quickshell'/rel,base/rel)
    (base/'config/qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton DirectoryStyle 1.0 DirectoryStyle.qml\n')
    (base/'config/Theme.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {property color glassRaised:"#101218";property color glassFocus:"#343448";property color surfaceHover:"#202228"}')
    (base/'config/DirectoryStyle.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {property color ink:"white";property color rule:"gray";property color muted:"silver";property string dataFont:"monospace"}')
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software');env.pop('WAYLAND_DISPLAY',None)
    r=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(base/'tests/tst_DisplayCanvas.qml')],env=env)
    raise SystemExit(r.returncode)
