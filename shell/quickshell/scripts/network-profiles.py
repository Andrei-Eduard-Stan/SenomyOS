#!/usr/bin/env python3
"""Secret-free NM profile inventory, reviewed policy actions and native editors."""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
UUID=re.compile(r'[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}')
TYPES={'802-11-wireless','802-3-ethernet','wifi','ethernet','vpn','wireguard'}


def run(args,timeout=5):
    return subprocess.run(args,env=dict(os.environ,LC_ALL='C'),capture_output=True,text=True,timeout=timeout,check=True)


def fields(line):
    values=[];current='';escape=False
    for char in line:
        if escape:
            current+=char;escape=False
        elif char=='\\':escape=True
        elif char==':':values.append(current);current=''
        else:current+=char
    if escape:raise ValueError('Invalid profile inventory.')
    return values+[current]


def catalog():
    binary=shutil.which('nmcli')
    if not binary:raise OSError('NetworkManager CLI unavailable.')
    output=run([binary,'-t','-e','yes','-f','UUID,NAME,TYPE,AUTOCONNECT,ACTIVE','connection','show']).stdout
    if len(output)>256*1024:raise ValueError('Profile inventory exceeded its bound.')
    items=[];seen=set()
    for line in output.splitlines():
        values=fields(line)
        if len(values)!=5 or not UUID.fullmatch(values[0]) or values[3] not in ('yes','no') or values[4] not in ('yes','no'):
            raise ValueError('Invalid profile inventory.')
        uuid,name,kind,auto,active=values
        if uuid in seen:continue
        seen.add(uuid)
        token=hashlib.sha256(json.dumps(values).encode()).hexdigest()
        items.append({'uuid':uuid,'name':''.join(c if c.isprintable() else ' ' for c in name)[:200],
                      'type':kind,'autoconnect':auto=='yes','active':active=='yes',
                      'mutable':kind in TYPES,'token':token})
    return {'items':items,'available':True,'editorAvailable':bool(shutil.which('nm-connection-editor')),'authenticationAvailable':bool(shutil.which('kitty')),
            'message':'Connection-specific DNS and PAC proxy settings use the native editor. VPN setup depends on installed plugins; application-wide proxy behavior is not guaranteed.'}


def reviewed(verb,uuid,token):
    if verb not in ('forget','disconnect','autoconnect') or not UUID.fullmatch(uuid) or not re.fullmatch('[0-9a-f]{64}',token):
        raise ValueError('Unsupported profile action.')
    current=next((item for item in catalog()['items'] if item['uuid']==uuid),None)
    if not current or not current['mutable'] or current['token']!=token:
        raise ValueError('Profile changed since review. Review it again; nothing was changed.')
    if verb=='forget' and current['active']:raise ValueError('Disconnect and review this profile before forgetting it.')
    if verb=='disconnect' and not current['active']:raise ValueError('The profile is no longer active.')
    binary=shutil.which('nmcli')
    args=[binary,'--wait','15','connection']
    if verb=='forget':args+=['delete','uuid',uuid]
    elif verb=='disconnect':args+=['down','uuid',uuid]
    else:args+=['modify','uuid',uuid,'connection.autoconnect','no' if current['autoconnect'] else 'yes']
    run(args,timeout=20)
    try:after=next((item for item in catalog()['items'] if item['uuid']==uuid),None)
    except (OSError,ValueError,subprocess.SubprocessError):
        return {'state':'unverified','message':'Request returned, but current profile state could not be verified. Refresh before retrying.'}
    complete=(after is None if verb=='forget' else bool(after) and (not after['active'] if verb=='disconnect' else after['autoconnect']!=current['autoconnect']))
    return {'state':'succeeded' if complete else 'unverified','message':'NetworkManager reported the requested profile state.' if complete else 'Requested profile state was not observed. The request may still finish; refresh before retrying.'}


def open_editor(mode,uuid=None):
    if mode not in ('all','vpn','edit'):raise ValueError('Unsupported editor mode.')
    binary=shutil.which('nm-connection-editor')
    if not binary:raise OSError('Network profile editor unavailable.')
    args=[binary]
    if mode=='vpn':args+=['--show','vpn']
    if mode=='edit':
        if not uuid or not UUID.fullmatch(uuid) or not any(item['uuid']==uuid for item in catalog()['items']):
            raise ValueError('Profile is no longer available. Refresh before editing.')
        args+=['--edit',uuid]
    subprocess.Popen(args,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True,close_fds=True)
    return {'state':'started','message':'Native editor launch requested. Saved configuration and connection behavior are not yet verified.'}


def main(args):
    try:
        if args==['catalog']:data=catalog()
        elif len(args)==4 and args[0]=='apply-confirmed':data=reviewed(*args[1:])
        elif len(args) in (2,3) and args[0]=='open-editor':data=open_editor(*args[1:])
        else:raise ValueError('Unsupported profile operation.')
        result={'ok':True,'observed_at':int(time.time()),'data':data,'error':None}
    except (OSError,ValueError,subprocess.SubprocessError) as error:
        message=str(error) if isinstance(error,ValueError) else 'Profile operation failed or timed out. Check NetworkManager permissions and refresh state before retrying.'
        result={'ok':False,'observed_at':int(time.time()),'data':None,'error':{'message':message}}
    print(json.dumps(result));return 0 if result['ok'] else 1

if __name__=='__main__':raise SystemExit(main(sys.argv[1:]))
