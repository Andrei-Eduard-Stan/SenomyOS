#!/usr/bin/env python3
"""Inert process provider. Requires a private fixture directory."""
import json,os,sys,time
from pathlib import Path
root=Path(os.environ['SENOMY_PRIVATE_AUDIO_TEST_ROOT'])
if sys.argv[1]=='apply':
 print(json.dumps({'ok':True,'message':'This nonzero fixture exit must not count as success.'}),flush=True);sys.exit(7)
p=root/'attempts';n=int(p.read_text())+1 if p.exists()else 1;p.write_text(str(n));(root/'last-pid').write_text(str(os.getpid()))
print(json.dumps({'available':True,'generation':'fixture','nodes':[],'cards':[{'token':'fixture:card','revision':'one','id':8,'name':'Fixture card','profiles':[],'ports':[],'activePorts':[]}],'canMove':False,'error':''}),flush=True)
if n==1:sys.exit(1)
while True:time.sleep(1)
