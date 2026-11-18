#!/usr/bin/env python3
"""Bounded geometry IPC for the shell-owned keyboard; never sends input."""
import ctypes
import json
import os
from pathlib import Path
import re
import signal
import socket
import sys


def request(pid, data):
    fields=[data.get(key) for key in ('x','y','width','height')]
    if any(type(v) is not int or not 0<=v<=16384 for v in fields):raise ValueError('Invalid rectangle')
    if type(data.get('visible')) is not bool or type(data.get('floating')) is not bool:raise ValueError('Invalid mode')
    signature=os.environ.get('HYPRLAND_INSTANCE_SIGNATURE','');runtime=os.environ.get('XDG_RUNTIME_DIR','')
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,180}',signature) or not runtime.startswith('/'):raise OSError('IPC unavailable')
    command='senomy-osk-geometry '+' '.join(map(str,[pid,*fields,int(data['visible'] and not data['floating'])]))
    with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as c:
        c.settimeout(2);c.connect(str(Path(runtime)/'hypr'/signature/'.socket.sock'));c.sendall(command.encode());reply=b''
        while True:
            part=c.recv(1024)
            if not part:break
            reply+=part
            if len(reply)>4096:raise OSError('Oversized geometry response')
    result=json.loads(reply)
    if not isinstance(result,dict) or result.get('ok') is not True:raise ValueError('Unavailable geometry component')
    return result


def main(args):
    if len(args)!=1 or not args[0].isdecimal() or not 2<=int(args[0])<=4194304:return 2
    pid=int(args[0]);parent=os.getppid()
    libc=ctypes.CDLL(None,use_errno=True)
    if parent<=1 or libc.prctl(1,signal.SIGTERM,0,0,0)!=0 or os.getppid()!=parent:return 1
    for line in sys.stdin:
        if len(line)>512:continue
        try:
            # The bridge and provider must be children of this same shell.
            stat=(Path('/proc')/str(pid)/'stat').read_text().rsplit(')',1)[1].split()
            if int(stat[1])!=parent:raise OSError('Keyboard ownership ended')
            result=request(pid,json.loads(line));print(json.dumps(result),flush=True)
        except (OSError,ValueError,TypeError,KeyError):print('{"ok":false}',flush=True)
    return 0
if __name__=='__main__':raise SystemExit(main(sys.argv[1:]))
