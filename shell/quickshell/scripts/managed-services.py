#!/usr/bin/env python3
"""Allowlisted user audio-service inventory and explicitly confirmed restart.

Never replays process argv, addresses system services, or restarts the shell.
Only normalized properties enter shell state; no journal or environment output.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

UNITS = {'pipewire.service': 'PipeWire audio/video streams may be interrupted.',
         'pipewire-pulse.service': 'PulseAudio-compatible application audio may be interrupted.',
         'wireplumber.service': 'Audio routing and device policy may be interrupted.'}
PROPERTIES = ('Id','LoadState','ActiveState','SubState','MainPID','InvocationID',
              'StateChangeTimestampMonotonic','CanStart','CanStop')


def run(argv, timeout=5):
    return subprocess.run(argv, capture_output=True, text=True, timeout=timeout, check=True)


def snapshot(unit):
    if unit not in UNITS:
        raise ValueError('Unsupported service.')
    binary = shutil.which('systemctl')
    if not binary:
        raise OSError('User service inspection is unavailable.')
    output = run([binary, '--user', 'show', unit, '--no-pager',
                  '--property=' + ','.join(PROPERTIES)]).stdout
    if len(output) > 8192:
        raise ValueError('Service inspection returned invalid data.')
    fields = dict(line.split('=',1) for line in output.splitlines() if '=' in line)
    if fields.get('Id') != unit or not all(key in fields for key in PROPERTIES):
        raise ValueError('Service identity is unavailable.')
    pid = fields['MainPID']
    if not pid.isdecimal():
        raise ValueError('Service process identity is unavailable.')
    eligible = (fields['LoadState'] == 'loaded' and fields['ActiveState'] in ('active','failed')
                and fields['CanStart'] == 'yes' and fields['CanStop'] == 'yes')
    token = hashlib.sha256(json.dumps(fields,sort_keys=True).encode()).hexdigest()
    return {'unit':unit, 'state':fields['ActiveState'], 'substate':fields['SubState'],
            'loaded':fields['LoadState']=='loaded','pid':int(pid),'token':token,
            'restartAllowed':eligible,'impact':UNITS[unit], 'invocation':fields['InvocationID']}


def catalog():
    items = []
    for unit in UNITS:
        try:
            item = snapshot(unit)
        except (OSError,ValueError,subprocess.SubprocessError):
            item = {'unit':unit,'state':'unavailable','loaded':False,'pid':0,
                    'restartAllowed':False,'impact':UNITS[unit], 'token':''}
        items.append(item)
    return {'items':items,'available':any(item['loaded'] for item in items)}


def association(pid):
    if not str(pid).isdecimal() or int(pid) < 1:
        raise ValueError('Invalid process identity.')
    proc = Path('/proc') / str(pid)
    if proc.stat().st_uid != os.getuid():
        return {'supported':False,'message':'Process is not owned by the current user.'}
    # Only the owning service main process is supported, never an arbitrary child.
    for item in catalog()['items']:
        if item['restartAllowed'] and item['pid'] == int(pid):
            return {'supported':True,'service':item}
    return {'supported':False,'message':'Restart is available only for a supported user-service main process.'}


def restart(unit, token):
    if unit not in UNITS or not re.fullmatch('[0-9a-f]{64}',token):
        raise ValueError('Invalid restart target.')
    before = snapshot(unit)
    if not before['restartAllowed'] or before['token'] != token:
        raise ValueError('Service changed since review. Review it again; nothing was restarted.')
    binary = shutil.which('systemctl')
    run([binary,'--user','restart',unit],timeout=30)
    after = snapshot(unit)
    if after['state'] != 'active' or not after['invocation'] or after['invocation'] == before['invocation']:
        return {'state':'unverified','message':'Restart job returned, but a new active service instance was not observed.'}
    return {'state':'succeeded','message':'A new active service instance was observed. Audio behavior still requires verification.'}


def main(args):
    try:
        if args == ['catalog']:
            data = catalog()
        elif len(args)==2 and args[0]=='process':
            data = association(args[1])
        elif len(args)==3 and args[0]=='restart-confirmed':
            data = restart(args[1],args[2])
        else:
            raise ValueError('Unsupported service action.')
        result={'ok':True,'observed_at':int(time.time()),'data':data,'error':None}
    except (OSError,ValueError,subprocess.SubprocessError) as error:
        # Do not publish raw provider output, logs, commands or environment.
        message=str(error) if isinstance(error,ValueError) else 'User-service operation failed or timed out. Verify service state before retrying.'
        result={'ok':False,'observed_at':int(time.time()),'data':None,'error':{'message':message}}
    print(json.dumps(result))
    return 0 if result['ok'] else 1

if __name__=='__main__':
    raise SystemExit(main(sys.argv[1:]))
