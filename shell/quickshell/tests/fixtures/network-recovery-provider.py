#!/usr/bin/env python3
"""Inert observer; must be run in a private fixture directory."""
import json,os,sys,time
from pathlib import Path
root=Path(os.environ['SENOMY_PRIVATE_NETWORK_FIXTURE']);counter=root/'attempts';n=int(counter.read_text())+1 if counter.exists()else 1;counter.write_text(str(n));(root/'pid').write_text(str(os.getpid()))
def emit(owner,auto=True):
 data={'providerIdentity':owner,'providerAvailable':bool(owner),'available':bool(owner),'items':[{'uuid':'12345678-1234-1234-1234-123456789abc','name':'Fixture VPN','type':'vpn','mutable':True,'token':'a'*64,'active':False,'autoconnect':auto}]if owner else [],'devices':[],'editorAvailable':True,'authenticationAvailable':True}
 print(json.dumps({'ok':True,'data':data}),flush=True)
if n==1:
 emit('first');time.sleep(.3);emit('');time.sleep(.3);emit('replacement',False);time.sleep(.3);sys.exit(1)
emit('replacement',False)
for line in sys.stdin:
 if line.strip()=='refresh':emit('replacement',False)
