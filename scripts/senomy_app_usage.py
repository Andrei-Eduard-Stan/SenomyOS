#!/usr/bin/env python3
"""Local desktop-launch counts; no arguments, document names or process tracking."""
from pathlib import Path
import fcntl
import json
import os
import re
import tempfile
import time

MAX_BYTES = 262144
MAX_APPS = 512

def directory():
    return Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state')))/'senomyos/app-usage'

def app_id(value):
    if not isinstance(value,str) or not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.+@-]{0,254}\.desktop',value):
        raise ValueError('Invalid desktop entry identity')
    return value[:-8]

def read(path):
    if not path.exists(): return {'schemaVersion':1,'apps':{}}
    if path.stat().st_size>MAX_BYTES: raise ValueError('Usage history exceeded its size limit')
    data=json.loads(path.read_text())
    if not isinstance(data,dict) or data.get('schemaVersion')!=1 or not isinstance(data.get('apps'),dict) or len(data['apps'])>MAX_APPS:
        raise ValueError('Unsupported usage history')
    for key,row in data['apps'].items():
        app_id(key+'.desktop')
        if not isinstance(row,dict) or type(row.get('count')) is not int or not 1<=row['count']<=2147483647 or type(row.get('lastOpened')) is not int or row['lastOpened']<0:
            raise ValueError('Invalid usage history entry')
    return data

def record(target):
    """Best effort: history failure must never change a successful launch receipt."""
    try:
        identity=app_id(target);root=directory();root.mkdir(parents=True,mode=0o700,exist_ok=True)
        with os.fdopen(os.open(root/'history.lock',os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600),'a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            path=root/'history.json';data=read(path)
            previous=data['apps'].get(identity,{})
            data['apps'][identity]={'count':min(2147483647,previous.get('count',0)+1),'lastOpened':int(time.time())}
            data['apps']=dict(sorted(data['apps'].items(),key=lambda entry:(-entry[1]['count'],-entry[1]['lastOpened'],entry[0]))[:MAX_APPS])
            name=None
            try:
                with tempfile.NamedTemporaryFile(mode='w',dir=root,prefix='.history-',delete=False) as stream:
                    name=stream.name;json.dump(data,stream,separators=(',',':'));stream.write('\n');stream.flush();os.fsync(stream.fileno())
                os.replace(name,path)
            finally:
                if name and os.path.exists(name):os.unlink(name)
        return True
    except (OSError,ValueError,TypeError):
        return False
