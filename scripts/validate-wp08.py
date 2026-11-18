#!/usr/bin/env python3
"""Focused offscreen state and private calendar transport; no live mutations."""
import asyncio
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading

root=Path(__file__).resolve().parents[1]
for name in ['wp08-state','wp08-calendar']:
    with tempfile.TemporaryDirectory(prefix='senomy-wp08-') as directory:
        temp=Path(directory);shell=temp/'shell/quickshell';shutil.copytree(root/'shell/quickshell',shell,symlinks=True,ignore=shutil.ignore_patterns('__pycache__'))
        for item in ['assets','appearance']:(temp/item).symlink_to(root/item,target_is_directory=True)
        source=(shell/'tests/fixtures'/f'{name}.qml').read_text().replace('"../../services','"services').replace('"../../components','"components')
        (shell/f'{name}.qml').write_text(source)
        # No hardware sensor inventory or auxiliary disk collector in this fixture.
        (shell/'services/TemperatureService.qml').write_text('import QtQuick\nQtObject {property bool available:false;property real celsius:0}')
        (shell/'services/DiskActivity.qml').write_text('import QtQuick\nQtObject {property bool active:false;property bool available:false;property real busyPercent:0;property double previousAt:0}')
        # Substitute only the toast's native layer host; retain its production
        # state/connections/content, as in qa_remaining_hosts.prepare_hosts.
        toast=shell/'components/NotificationToast.qml';source=toast.read_text().replace('PanelWindow {','FocusScope {\n    readonly property var contentItem:root',1)
        a=source.index('    screen: targetScreen');b=source.index('    Connections {',a)
        fields=[line for line in source[a:b].splitlines() if line.strip().startswith(('readonly property','implicitWidth:','implicitHeight:'))]
        toast.write_text(source[:a]+'\n'.join(fields)+'\n'+source[b:])
        runtime=temp/'r';runtime.mkdir(mode=0o700);state=temp/'state';config=temp/'config'
        env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),XDG_STATE_HOME=str(state),XDG_CONFIG_HOME=str(config),SENOMY_NOTIFICATION_OWNER='none',SENOMY_NOTIFICATION_STORE=str(temp/'history.json'),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
        for item in ['HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY','DISPLAY']:env.pop(item,None)
        calls=[];server_loop=None;stop=None;ready=threading.Event()
        async def serve():
            global server_loop,stop
            server_loop=asyncio.get_running_loop();stop=asyncio.Event();folder=runtime/'senomyos-calendar';folder.mkdir(mode=0o700);path=folder/'calendar.sock';assert len(str(path).encode())<108
            async def client(reader,writer):
                try:
                    while line:=await reader.readline():
                        request=json.loads(line);calls.append(request['operation'])
                        if request['operation']=='save':break
                        result={'sources':[],'preferences':{},'reminders':[],'eventCount':0}
                        writer.write((json.dumps(dict(id=request['id'],ok=True,result=result))+'\n').encode());await writer.drain()
                finally:writer.close();await writer.wait_closed()
            server=await asyncio.start_unix_server(client,str(path));path.chmod(0o600);ready.set()
            async with server:await stop.wait()
        thread=None
        if name=='wp08-calendar':thread=threading.Thread(target=lambda:asyncio.run(serve()),daemon=True);thread.start();assert ready.wait(3)
        try:result=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/f'{name}.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=12)
        finally:
            if thread:server_loop.call_soon_threadsafe(stop.set);thread.join(3)
        output=result.stdout+result.stderr;print(output)
        if result.returncode or re.search(r'FAIL:|TypeError|ReferenceError|Binding loop|Failed to load configuration',output) or 'RESULT:' not in output:raise SystemExit(1)
        if thread:assert calls.count('save')==1, 'Mutation replayed after reconnect'
