#!/usr/bin/env python3
"""Render actual display components with fake providers and an offscreen window."""
from pathlib import Path
import os,re,shutil,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
output=Path(os.environ.get('SENOMY_DISPLAY_QA_DIR','/tmp/senomy-display-ui'));output.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='sdu-') as directory:
    temp=Path(directory);shell=temp/'shell/quickshell';shutil.copytree(root/'shell/quickshell',shell,symlinks=True)
    for name in ('appearance','assets'):(temp/name).symlink_to(root/name,target_is_directory=True)
    fixture=(shell/'tests/fixtures/display-editor.qml').read_text().replace('"../../components"','"components"').replace('"../../services"','"services"').replace('"../../config"','"config"')
    (shell/'display-editor-test.qml').write_text(fixture)
    runtime=temp/'r';runtime.mkdir(mode=0o700)
    env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/'config'),XDG_STATE_HOME=str(temp/'state'),
             SENOMY_DISPLAY_QA_DIR=str(output),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
    env.pop('WAYLAND_DISPLAY',None)
    p=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/'display-editor-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=15)
    text=p.stdout+p.stderr
    if p.returncode or re.search(r'ERROR|FAIL|TypeError|ReferenceError|Binding loop',text):
        print(text);raise SystemExit(1)
    assert 'PASS display editor all views' in text,text
    assert 'PASS display review conflict, overlap and scroll handling' in text,text
    assert (output/'display-review-ready.png').stat().st_size>100
    for view in ('projection','arrangement','settings','workspaces','profiles','diagnostics'):
        for width in (1000,640,380):assert (output/f'display-{view}-{width}.png').stat().st_size>100
    print('PASS: actual display editor views rendered with fake providers at 1000/640/380; '+str(output))
