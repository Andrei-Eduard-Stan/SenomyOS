#!/usr/bin/env python3
"""Bounded read-only desktop integration status. Never requests portal permissions."""
import json
import os
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
UNITS=('xdg-desktop-portal.service','xdg-desktop-portal-hyprland.service','xdg-desktop-portal-gtk.service')
FEATURES=('FileChooser','OpenURI','ScreenCast','Screenshot','Camera','Inhibit','Settings','Background')


def run(args,timeout=5):
    return subprocess.run(args,env=dict(os.environ,LC_ALL='C'),capture_output=True,text=True,timeout=timeout,check=True)


def unit_status(unit):
    binary=shutil.which('systemctl')
    if not binary:return {'unit':unit,'available':False,'state':'unknown'}
    try:
        text=run([binary,'--user','show',unit,'--no-pager','--property=Id,LoadState,ActiveState,SubState']).stdout
        if len(text)>8192:raise ValueError()
        values=dict(line.split('=',1) for line in text.splitlines() if '=' in line)
        if values.get('Id')!=unit:raise ValueError()
        return {'unit':unit,'available':values.get('LoadState')=='loaded','state':values.get('ActiveState','unknown'),'substate':values.get('SubState','unknown')}
    except (OSError,ValueError,subprocess.SubprocessError):return {'unit':unit,'available':False,'state':'unknown'}


def portal_interfaces():
    binary=shutil.which('busctl')
    if not binary:return {'state':'unknown','features':[],'message':'Session bus inspection unavailable.'}
    try:
        # Auto-start disabled: diagnosis must not activate a portal provider.
        result=run([binary,'--user','--auto-start=no','--timeout=3','--json=short','call',
                    'org.freedesktop.portal.Desktop','/org/freedesktop/portal/desktop',
                    'org.freedesktop.DBus.Introspectable','Introspect'])
        if len(result.stdout)>256*1024:raise ValueError()
        payload=json.loads(result.stdout)
        xml=payload['data'][0]
        interfaces={entry.attrib['name'] for entry in ET.fromstring(xml).findall('interface')}
        return {'state':'advertised','features':[{'name':name,'advertised':'org.freedesktop.portal.'+name in interfaces} for name in FEATURES],
                'message':'Advertised portal interfaces are capabilities, not accepted file picker, permission, camera or screen-sharing journeys.'}
    except (OSError,ValueError,KeyError,TypeError,ET.ParseError,subprocess.SubprocessError):
        return {'state':'unknown','features':[],'message':'Portal introspection unavailable; no permission or provider activation was requested.'}


def catalog():
    return {'services':[unit_status(unit) for unit in UNITS],'portal':portal_interfaces(),
            'flatpakAvailable':bool(shutil.which('flatpak')),'fileManagerAvailable':bool(shutil.which('thunar')),
            'permissionPolicy':'Applications request portal permissions through their own dialogs. No blanket permission bypass or approval is performed here.',
            'journeys':'Removable media, mounts, archives, shares, file associations and screencasting require native application and hardware acceptance.'}


def main(args):
    if args!=['catalog']:
        print(json.dumps({'ok':False,'data':None,'error':{'message':'Unsupported desktop inspection action.'}}));return 1
    print(json.dumps({'ok':True,'observed_at':int(time.time()),'data':catalog(),'error':None}));return 0

if __name__=='__main__':raise SystemExit(main(sys.argv[1:]))
