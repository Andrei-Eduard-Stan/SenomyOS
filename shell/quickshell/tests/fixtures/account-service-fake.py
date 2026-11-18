#!/usr/bin/env python3
"""Inert account service transport; private fixture directory required."""
import json,os,sys,time
from pathlib import Path
root=Path(os.environ['SENOMY_PRIVATE_ACCOUNT_FIXTURE'])
def state(name='External',stamp=None):
 version=1 if name=='Fixture'else 2
 return {'schema_version':1,'observedAtMs':int(time.monotonic()*1000)if stamp is None else stamp,'providerIdentity':'fixture-owner','available':True,'complete':True,'currentUid':2001,'token':'inventory'+str(version),'passwordAvailable':True,'accounts':[{'uid':2001,'username':'fixture','name':name,'avatar':'','current':True,'signedIn':True,'administrator':True,'locked':False,'managed':True,'token':'target'+str(version)},{'uid':2002,'username':'second','name':'Second','avatar':'','current':False,'signedIn':False,'administrator':False,'locked':False,'managed':True,'token':'second'}]}
if sys.argv[1]=='apply':
 if sys.argv[2]=='create':print(json.dumps({'ok':True,'state':'succeeded','message':'nonzero must not succeed','snapshot':state('Fixture',1)}));sys.exit(7)
 print(json.dumps({'ok':False,'state':'cancelled','message':'Fixture authentication cancelled'}));sys.exit(1)
counter=root/'attempts';n=int(counter.read_text())+1 if counter.exists()else 1;counter.write_text(str(n));(root/'pid').write_text(str(os.getpid()))
print(json.dumps(state('Fixture'if n==1 else'External')),flush=True)
if n==1:
 time.sleep(.3);print(json.dumps(state()),flush=True);time.sleep(.3);sys.exit(1)
for line in sys.stdin:
 if line.strip()=='refresh':print(json.dumps(state()),flush=True)
