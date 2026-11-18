#!/usr/bin/env python3
"""Allowlisted inert helper receipts. No real accounts, input, portals or apps."""
import json
import os
from pathlib import Path
import sys

assert os.environ.get('SENOMY_PRIVATE_WP07')=='1'
name=Path(sys.argv[0]).name
operation=sys.argv[1] if len(sys.argv)>1 else ''
def count(key):
    p=Path(os.environ['XDG_RUNTIME_DIR'])/key
    n=int(p.read_text()) if p.exists() else 0
    p.write_text(str(n+1));return n
if name=='osk-capabilities.py':
    print(json.dumps(dict(ok=True,providerInstalled=False,protocolState='unknown',message='Inert fixture: no native provider')))
elif name=='native-input-tools.py':
    if operation=='detect':print(json.dumps(dict(ok=True,editorAvailable=True,engineInstalled=True)))
    elif operation=='open-ime':
        print(json.dumps(dict(ok=True,state='started',message='False-fixture-success')));sys.exit(7)
    else:raise AssertionError(operation)
elif name=='osk-automatic.py':
    assert operation=='set-mode'
    n=count('mode-counter')
    print(json.dumps(dict(ok=True,mode='auto' if n==1 else sys.argv[2])))
    sys.exit(7 if n==0 else 0)
elif name in ('desktop-settings.py','desktop-capabilities.py'):
    if operation=='catalog':
        data=dict(defaults=dict(available=True,message='Inert registry',items=[dict(mime='text/plain',label='Text',token='fixture',options=[dict(id='fixture.desktop',name='Fixture editor')])],apps=[]),autostart=[],deployment=dict(supported=False)) if name=='desktop-settings.py' else dict(portal=dict(state='advertised',features=[]))
        print(json.dumps(dict(ok=True,data=data,error=None)));sys.exit(7 if count(name+'-catalog')==0 else 0)
    assert name=='desktop-settings.py' and operation=='default-confirmed'
    print(json.dumps(dict(ok=True,data=dict(state='succeeded',message='False-fixture-success'))));sys.exit(7)
else:raise AssertionError(name)
