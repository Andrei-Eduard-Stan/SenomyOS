#!/usr/bin/env python3
"""Bounded focus/device booleans only; no surrounding text or key events."""
import importlib.util
import json
import os
from pathlib import Path
import socket
import sys
import tempfile
import time
spec=importlib.util.spec_from_file_location('osk_locks',Path(__file__).with_name('osk-lock-state.py'))
locks=importlib.util.module_from_spec(spec);spec.loader.exec_module(locks)
FIELDS=('physicalKeyboard','textActive','inputMethod','locked')
def preference_path():
    return Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'senomyos/osk.json'
def mode():
    try:
        p=preference_path()
        if p.stat().st_size>1024:return 'manual'
        value=json.loads(p.read_text())
        return value['mode'] if value.get('mode') in ('auto','manual') else 'manual'
    except FileNotFoundError:return 'auto'
    except (OSError,ValueError,TypeError,AttributeError,KeyError):return 'manual'
def save(value):
    if value not in ('auto','manual'):raise ValueError('Invalid OSK mode')
    p=preference_path();p.parent.mkdir(parents=True,exist_ok=True)
    fd,name=tempfile.mkstemp(prefix='.osk-',dir=p.parent)
    try:
        with os.fdopen(fd,'w') as f:json.dump({'mode':value},f);f.write('\n')
        os.replace(name,p)
    finally:
        if os.path.exists(name):os.unlink(name)
def sanitize(value):
    if not isinstance(value,dict) or value.get('ok') is not True or (type(value.get('protocol')) is not int or value.get('protocol')!=1) or any(type(value.get(k)) is not bool for k in FIELDS) or type(value.get('focusEpoch')) is not int or not 0<=value['focusEpoch']<2**53:
        return {'ok':False,'mode':mode()}
    return {'ok':True,'mode':mode(),**{k:value[k] for k in FIELDS},'focusEpoch':value['focusEpoch']}
def state():
    try:return sanitize(json.loads(locks.request('senomy-osk-auto-state')))
    except (OSError,ValueError):return {'ok':False,'mode':mode()}
def stream():
    locks.arm_owned_child();locks.ensure_plugin();previous=None
    def emit(value):
        nonlocal previous
        if value!=previous:print(json.dumps(value),flush=True);previous=value
    while True:
        try:
            with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as c:
                c.settimeout(2);c.connect(str(locks.directory()/'.socket2.sock'));emit(state());buffer=b''
                while True:
                    try:data=c.recv(2048)
                    except socket.timeout:
                        if not previous or previous.get('ok') is not True:emit(state())
                        continue
                    if not data:raise OSError('Disconnected')
                    buffer+=data
                    if len(buffer)>65536:raise OSError('Oversized compositor event')
                    while b'\n' in buffer:
                        line,buffer=buffer.split(b'\n',1)
                        if line.startswith(b'senomy-osk-auto>>'):
                            if len(line)>1024:raise OSError('Oversized focus event')
                            emit(sanitize(json.loads(line.split(b'>>',1)[1])))
        except (OSError,ValueError):emit({'ok':False,'mode':mode()});time.sleep(1)
def main(args):
    if args==['stream']:stream();return 0
    if len(args)==2 and args[0]=='set-mode' and args[1] in ('auto','manual'):
        try:save(args[1]);print(json.dumps({'ok':True,'mode':args[1]}));return 0
        except OSError:print('{"ok":false}');return 1
    return 2
if __name__=='__main__':raise SystemExit(main(sys.argv[1:]))
