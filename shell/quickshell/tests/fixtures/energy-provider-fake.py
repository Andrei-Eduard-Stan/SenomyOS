#!/usr/bin/env python3
"""Inert private transport fixture. Cannot resolve system power operations."""
import json
import os
from pathlib import Path
import sys
import time

root=Path(os.environ['SENOMY_PRIVATE_ENERGY_FIXTURE'])
def emit(data):print(json.dumps(data),flush=True)
def snapshot():
    return {'schemaVersion':1,'ok':True,'backend':{'kind':'fixture','identity':'owner-1','active':'balanced','available':True,'profiles':['balanced','power-saver'],'token':'token'}}
if sys.argv[1]=='watch':
    (root/'watcher.pid').write_text(str(os.getpid()));emit(snapshot())
    while True:time.sleep(60)
elif sys.argv[1]=='get':emit(snapshot())
elif sys.argv[1]=='details':emit({'ok':True,'packs':[],'inhibitors':[],'cpus':[]})
elif sys.argv[1]=='set':
    (root/'submissions.json').write_text(sys.argv[2]);time.sleep(.1)
    print('not a valid result',flush=True);sys.exit(1)
else:sys.exit(2)
