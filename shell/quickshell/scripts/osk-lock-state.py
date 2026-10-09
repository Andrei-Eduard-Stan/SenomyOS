#!/usr/bin/env python3
"""Fixed Caps Lock IPC only. Event-driven; never reads keyboard key events."""
import ctypes
import signal
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import sys
import time


def directory():
    signature=os.environ.get('HYPRLAND_INSTANCE_SIGNATURE','')
    runtime=os.environ.get('XDG_RUNTIME_DIR','')
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,180}',signature) or not runtime.startswith('/'):
        raise OSError('Compositor IPC unavailable')
    return Path(runtime)/'hypr'/signature


def request(command):
    plugin=Path.home()/'.local/lib/senomyos/osk/caps-sync.so'
    if command not in ('senomy-caps-state','senomy-caps-toggle','senomy-osk-state','j/version','plugin load '+str(plugin)):
        raise ValueError('Unsupported Caps operation')
    with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as client:
        client.settimeout(2);client.connect(str(directory()/'.socket.sock'));client.sendall(command.encode())
        data=b''
        while True:
            chunk=client.recv(512)
            if not chunk:break
            data+=chunk
            if len(data)>2048:raise OSError('Oversized Caps response')
    return data.decode()


def state():
    try:
        result=json.loads(request('senomy-caps-state'))
        if isinstance(result,dict) and result.get('ok') is True and type(result.get('available')) is bool and type(result.get('capsLock')) is bool:
            return {key:result[key] for key in ('ok','available','capsLock')}
    except (OSError,ValueError):pass
    return {'ok':False,'available':False}


def ensure_plugin():
    # Only confirmed provider startup calls this. Wrong-version or missing
    # components leave the ordinary manual keyboard available without sync.
    if state().get('ok') is True:return True
    plugin=Path.home()/'.local/lib/senomyos/osk/caps-sync.so'
    try:
        receipt=json.loads(plugin.with_suffix('.json').read_text())
        version=json.loads(request('j/version'))
        if not isinstance(version,dict) or not isinstance(receipt,dict) or version.get('commit')!=receipt.get('commit'):return False
        if hashlib.sha256(plugin.read_bytes()).hexdigest()!=receipt.get('sha256'):return False
        if request('plugin load '+str(plugin)).strip()!='ok':return False
        return state().get('ok') is True
    except (OSError,ValueError):return False

def emit(value):
    print(json.dumps(value),flush=True)


def arm_owned_child():
    parent=os.getppid()
    if parent<=1:raise OSError('No owning shell')
    libc=ctypes.CDLL(None,use_errno=True)
    libc.prctl.argtypes=[ctypes.c_int,ctypes.c_ulong,ctypes.c_ulong,ctypes.c_ulong,ctypes.c_ulong]
    libc.prctl.restype=ctypes.c_int
    if libc.prctl(1,signal.SIGTERM,0,0,0)!=0 or os.getppid()!=parent:
        raise OSError('Cannot establish owned bridge lifetime')

def stream():
    arm_owned_child()
    while True:
        try:
            with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as client:
                client.settimeout(3);client.connect(str(directory()/'.socket2.sock'))
                emit(state());buffer=b''
                while True:
                    try:chunk=client.recv(2048)
                    except socket.timeout:continue
                    if not chunk:raise OSError('IPC disconnected')
                    buffer+=chunk
                    if len(buffer)>65536:raise OSError('Oversized event')
                    while b'\n' in buffer:
                        line,buffer=buffer.split(b'\n',1)
                        if line in (b'senomy-caps>>0',b'senomy-caps>>1'):
                            emit({'ok':True,'available':True,'capsLock':line.endswith(b'1')})
                        elif line==b'senomy-caps>>unavailable':emit({'ok':True,'available':False})
        except (OSError,ValueError):
            emit({'ok':False,'available':False});time.sleep(1)


def main(args):
    if args==['stream']:stream();return 0
    if args==['state']:emit(state());return 0
    if args==['toggle']:
        try:
            reply=request('senomy-caps-toggle')
            result=json.loads(reply);ok=isinstance(result,dict) and result.get('ok') is True;emit({'ok':ok});return 0 if ok else 1
        except (OSError,ValueError):emit({'ok':False});return 1
    return 2
if __name__=='__main__':raise SystemExit(main(sys.argv[1:]))
