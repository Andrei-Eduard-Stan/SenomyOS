#!/usr/bin/env python3
"""Versioned user audio preferences; no audio-device writes."""
import json
import os
from pathlib import Path
import sys
import tempfile

DEFAULTS = {'schemaVersion': 1, 'amplification': False, 'routes': []}

def validate(value):
    if not isinstance(value, dict) or value.get('schemaVersion') != 1 or type(value.get('amplification')) is not bool:
        raise ValueError('Unsupported audio preferences')
    routes=value.get('routes', [])
    if not isinstance(routes,list) or len(routes)>32:raise ValueError('Too many remembered routes')
    clean=[];seen=set()
    for rule in routes:
        if not isinstance(rule,dict) or rule.get('direction') not in ('playback','recording'):raise ValueError('Invalid remembered route')
        for field in ('appKey','endpointName'):
            if not isinstance(rule.get(field),str) or not 1<=len(rule[field])<=180 or any(ord(c)<32 for c in rule[field]):raise ValueError('Invalid route identity')
        key=(rule['direction'],rule['appKey'])
        if key in seen:raise ValueError('Duplicate remembered app route')
        seen.add(key);clean.append({k:rule[k] for k in ('direction','appKey','endpointName')})
    return {'schemaVersion':1,'amplification':value['amplification'],'routes':clean}

def load(path):
    if not path.exists(): return dict(DEFAULTS)
    if path.stat().st_size > 16384: raise ValueError('Audio preferences exceeded the size limit')
    return validate(json.loads(path.read_text()))

def save(path, value):
    value = validate(value);path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.audio-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as output:
            json.dump(value, output);output.write('\n');output.flush();os.fsync(output.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):os.unlink(name)
    return value

def main():
    path=Path(os.environ.get('XDG_CONFIG_HOME') or Path.home()/'.config')/'senomyos/audio.json'
    try:
        if len(sys.argv)==2 and sys.argv[1]=='read':value=load(path)
        elif len(sys.argv)==3 and sys.argv[1]=='save' and len(sys.argv[2])<16384:value=save(path,json.loads(sys.argv[2]))
        else:raise ValueError('Invalid preference request')
        result={'ok':True,'preferences':value}
    except (ValueError,OSError) as exc:result={'ok':False,'preferences':dict(DEFAULTS),'message':str(exc)[:200]}
    print(json.dumps(result))
if __name__=='__main__':main()
