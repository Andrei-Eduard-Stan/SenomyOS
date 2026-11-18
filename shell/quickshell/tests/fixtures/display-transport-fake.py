#!/usr/bin/env python3
"""Inert process transport; never imports the compositor adapter."""
import json
import os
from pathlib import Path
import sys
import time

assert os.environ.get('SENOMY_PRIVATE_DISPLAY_FIXTURE') == '1'
directory = Path(os.environ['XDG_RUNTIME_DIR'])
if Path(sys.argv[0]).name == 'device-inventory.py':
    count_path = directory / 'inventory-count'
    count = int(count_path.read_text()) if count_path.exists() else 0
    count_path.write_text(str(count + 1))
    if count == 0:
        time.sleep(.4)
    failed = (directory / 'inventory-fail').exists()
    width = 800 if failed else 1920 if count == 0 else 1280
    display = dict(key='fixture', name='FIXTURE', width=width, height=720,
                   refreshRate=60, scale=1, transform=0, x=0, y=0,
                   disabled=False, mirrorOf='none', availableModes=['1280x720@60'])
    print(json.dumps(dict(displays=dict(available=True, items=[display]),
                          inputs=dict(available=True, items=[]), digest=str(width),
                          policy=dict(workspaceMode='independent', autoRecovery=False),
                          profiles=[], workspaces=[], windows=[], transaction=dict(state='idle'))))
    sys.exit(7 if failed else 0)

operation = sys.argv[1]
if operation == 'workspace':
    argument = json.loads(sys.argv[2])
    action = argument.get('action')
    if action == 'inventory-fail':
        (directory / 'inventory-fail').touch()
    elif action == 'inventory-good':
        (directory / 'inventory-fail').unlink(missing_ok=True)
    elif action == 'reject':
        print(json.dumps(dict(ok=False, error='Fixture compositor rejected the request')))
        sys.exit(1)
    elif action == 'malformed':
        print('not-json')
        sys.exit(0)
    print(json.dumps(dict(ok=True, message='Inert operation')))
elif operation == 'keep':
    print(json.dumps(dict(ok=True, state='committed', message='False fixture success')))
    sys.exit(7)
elif operation in ('draft-save', 'restore-policy', 'auto-recover'):
    print(json.dumps(dict(ok=True, state='policy-restored', message='False fixture success')))
    sys.exit(7)
else:
    raise AssertionError('Unexpected fixture operation')
