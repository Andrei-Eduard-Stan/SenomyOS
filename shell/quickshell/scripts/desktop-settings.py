#!/usr/bin/env python3
"""Registered app defaults and future-login autostart preferences; never executes Exec."""
import configparser
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

MIMES={'x-scheme-handler/https':'Web links (HTTPS)','x-scheme-handler/http':'Web links (HTTP)',
       'inode/directory':'Folders','text/plain':'Text files','application/pdf':'PDF documents','image/png':'PNG images'}
APP_ID=re.compile(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,200}\.desktop')
PROTECTED=('senomy','hypr','polkit','nm-applet','blueman','at-spi','snap-userd','org.freedesktop','org.kde.polkit')
try:
    import gi
    gi.require_version('Gio','2.0')
    from gi.repository import Gio
    try:
        gi.require_version('GioUnix','2.0')
        from gi.repository import GioUnix
        DesktopAppInfo=GioUnix.DesktopAppInfo
    except (ImportError,ValueError):DesktopAppInfo=Gio.DesktopAppInfo
except (ImportError,ValueError):Gio=None;DesktopAppInfo=None


def digest(value):return hashlib.sha256(json.dumps(value,sort_keys=True).encode()).hexdigest()
def config_home():return Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))
def state_home():return Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))
def safe_label(value):return ''.join(c if c.isprintable() else ' ' for c in str(value))[:200]


def read_entry(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size>1024*1024:
        raise ValueError('Unsupported desktop entry.')
    content=path.read_text()
    parser=configparser.ConfigParser(interpolation=None,strict=False);parser.optionxform=str
    parser.read_string(content)
    if not parser.has_section('Desktop Entry') or parser['Desktop Entry'].get('Type')!='Application':
        raise ValueError('Unsupported desktop entry.')
    return content,parser['Desktop Entry']


def app_record(app):
    app_id=app.get_id()
    if not app_id or not APP_ID.fullmatch(app_id):return None
    desktop=DesktopAppInfo.new(app_id)
    if desktop is None or desktop.get_is_hidden():return None
    try:
        path=Path(desktop.get_filename());content,entry=read_entry(path)
    except (OSError,ValueError,configparser.Error):return None
    return {'id':app_id,'name':safe_label(app.get_name()),'token':digest([app_id,content]),
            'autostartAllowed':bool(entry.get('Exec')) and not app_id.lower().startswith(PROTECTED)}


def defaults():
    if Gio is None:return {'available':False,'items':[],'apps':[],'message':'Desktop application registry is unavailable.'}
    items=[]
    for mime,label in MIMES.items():
        current=Gio.AppInfo.get_default_for_type(mime,False)
        current_id=current.get_id() if current else ''
        options=[]
        for app in Gio.AppInfo.get_all_for_type(mime):
            record=app_record(app)
            if record and not any(option['id']==record['id'] for option in options):options.append(record)
        options.sort(key=lambda item:(item['name'].casefold(),item['id']))
        items.append({'mime':mime,'label':label,'current':current_id,'currentName':safe_label(current.get_name()) if current else 'Unconfigured',
                      'options':options,'token':digest([mime,current_id,options])})
    apps=[]
    for app in Gio.AppInfo.get_all():
        record=app_record(app)
        if record and record['autostartAllowed'] and not any(item['id']==record['id'] for item in apps):apps.append(record)
    apps.sort(key=lambda item:(item['name'].casefold(),item['id']))
    return {'available':True,'items':items,'apps':apps,'message':'Registered MIME handlers only. Saving a default does not launch an application.'}


def set_default(mime,app_id,token):
    if mime not in MIMES or not APP_ID.fullmatch(app_id):raise ValueError('Unsupported default application choice.')
    current=next((item for item in defaults()['items'] if item['mime']==mime),None)
    if not current or current['token']!=token or not any(item['id']==app_id for item in current['options']):
        raise ValueError('Default or application metadata changed. Review it again; nothing was saved.')
    app=DesktopAppInfo.new(app_id)
    if not app.set_as_default_for_type(mime):raise ValueError('Application default was rejected.')
    after=Gio.AppInfo.get_default_for_type(mime,False)
    observed=after is not None and after.get_id()==app_id
    return {'state':'succeeded' if observed else 'unverified','message':'Desktop registry reports the requested default. Real file/link opening remains to be verified.' if observed else 'Requested default was not observed. Refresh before retrying.'}


def autostart():
    directories=[config_home()/'autostart']+[Path(item)/'autostart' for item in os.environ.get('XDG_CONFIG_DIRS','/etc/xdg').split(':') if item]
    entries={}
    for directory in directories:
        for path in sorted(directory.glob('*.desktop')):
            if path.name not in entries:entries[path.name]=path
    desktop_names=set(os.environ.get('XDG_CURRENT_DESKTOP','').split(':'))
    items=[]
    for name,path in entries.items():
        if not APP_ID.fullmatch(name):continue
        try:content,entry=read_entry(path)
        except (OSError,ValueError,configparser.Error):continue
        only=set(filter(None,entry.get('OnlyShowIn','').split(';')));exclude=set(filter(None,entry.get('NotShowIn','').split(';')))
        try_exec=entry.get('TryExec','');try_available=not try_exec or bool(shutil.which(try_exec))
        eligible=bool(entry.get('Exec')) and (not only or bool(only&desktop_names)) and not bool(exclude&desktop_names) and try_available
        protected=name.lower().startswith(PROTECTED)
        items.append({'id':name,'name':safe_label(entry.get('Name',name)),'enabled':entry.get('Hidden','false').lower()!='true',
                      'eligible':eligible,'protected':protected,'source':'user' if path.parent==directories[0] else 'system',
                      'token':digest([str(path),content]),'message':'Protected session infrastructure' if protected else 'Eligibility is metadata, not proof of launch; compositor must run XDG autostart.'})
    return sorted(items,key=lambda item:(item['name'].casefold(),item['id']))


def source_entry(name):
    for directory in [config_home()]+[Path(item) for item in os.environ.get('XDG_CONFIG_DIRS','/etc/xdg').split(':') if item]:
        path=directory/'autostart'/name
        if path.exists() or path.is_symlink():return path
    raise ValueError('Autostart entry is no longer available.')


def with_hidden(content,hidden):
    lines=content.splitlines(True);inside=False;found=False;result=[]
    for line in lines:
        stripped=line.strip()
        if stripped.startswith('['):
            if inside and not found:result.append('Hidden='+hidden+'\n');found=True
            inside=stripped=='[Desktop Entry]'
        if inside and re.match(r'^\s*Hidden\s*=',line):
            if not found:result.append('Hidden='+hidden+'\n');found=True
        else:result.append(line)
    if not found:result.append(('' if not result or result[-1].endswith('\n') else '\n')+'Hidden='+hidden+'\n')
    return ''.join(result)


def write_override(name,content):
    directory=config_home()/'autostart'
    if directory.is_symlink():raise ValueError('Symlinked autostart directories are unsupported.')
    directory.mkdir(parents=True,exist_ok=True)
    target=directory/name
    if target.exists() or target.is_symlink():
        if target.is_symlink() or target.stat().st_uid!=os.getuid():raise ValueError('Autostart entry ownership is unsupported.')
        backup=state_home()/'senomyos/autostart-backups';backup.mkdir(parents=True,exist_ok=True);backup.chmod(0o700)
        saved=backup/(uuid.uuid4().hex+'-'+name);shutil.copyfile(target,saved);saved.chmod(0o600)
    fd,tmp=tempfile.mkstemp(prefix='.senomy-autostart-',dir=directory)
    try:
        with os.fdopen(fd,'w') as output:output.write(content)
        os.chmod(tmp,0o600);os.replace(tmp,target)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)


def set_autostart(name,enabled,token):
    if not APP_ID.fullmatch(name) or enabled not in ('yes','no'):raise ValueError('Unsupported autostart choice.')
    item=next((item for item in autostart() if item['id']==name),None)
    if not item or item['protected'] or item['token']!=token:raise ValueError('Autostart entry changed or is protected. Nothing was saved.')
    content,_=read_entry(source_entry(name));write_override(name,with_hidden(content,'false' if enabled=='yes' else 'true'))
    after=next((item for item in autostart() if item['id']==name),None)
    observed=after is not None and after['enabled']==(enabled=='yes')
    return {'state':'succeeded' if observed else 'unverified','message':'Autostart preference saved for a future login. No application was started or stopped.'}


def add_autostart(app_id,token):
    if not APP_ID.fullmatch(app_id):raise ValueError('Unsupported application identity.')
    item=next((app for app in defaults()['apps'] if app['id']==app_id),None)
    if not item or not item['autostartAllowed'] or item['token']!=token:raise ValueError('Application metadata changed or is unsupported. Nothing was saved.')
    if any(entry['id']==app_id for entry in autostart()):raise ValueError('Autostart entry already exists. Use its existing preference control.')
    app=DesktopAppInfo.new(app_id);content,_=read_entry(Path(app.get_filename()))
    write_override(app_id,with_hidden(content,'false'))
    return {'state':'succeeded','message':'Registered application added for a future login. No application was launched; startup depends on XDG autostart deployment.'}


def deployment():
    # Arch's packaged target is fixed platform infrastructure, not a machine ID.
    target=Path('/usr/lib/systemd/user/xdg-desktop-autostart.target')
    link=config_home()/'systemd/user/graphical-session.target.wants/xdg-desktop-autostart.target'
    current=os.readlink(link) if link.is_symlink() else ('occupied' if link.exists() else '')
    return {'supported':target.is_file(),'enabled':current==str(target),'token':digest([str(link),current]),
            'message':'Future user-manager sessions only; no live application launch or manager reload. Fresh-login acceptance is required.'}


def enable_autostart(token):
    current=deployment()
    if not current['supported'] or current['token']!=token:raise ValueError('Autostart deployment changed or is unavailable. Review it again.')
    link=config_home()/'systemd/user/graphical-session.target.wants/xdg-desktop-autostart.target'
    if link.exists() or link.is_symlink():
        if current['enabled']:return {'state':'succeeded','message':'Future XDG autostart is already configured.'}
        raise ValueError('An existing autostart target link was preserved. Review it manually.')
    link.parent.mkdir(parents=True,exist_ok=True)
    link.symlink_to('/usr/lib/systemd/user/xdg-desktop-autostart.target')
    return {'state':'succeeded','message':'Future XDG autostart configured. No live application or user-manager action was performed; a fresh user-manager/login is required.'}


def main(args):
    try:
        if args==['catalog']:data={'defaults':defaults(),'autostart':autostart(),'deployment':deployment()}
        elif len(args)==2 and args[0]=='enable-autostart-confirmed':data=enable_autostart(args[1])
        elif len(args)==4 and args[0]=='default-confirmed':data=set_default(*args[1:])
        elif len(args)==4 and args[0]=='autostart-confirmed':data=set_autostart(*args[1:])
        elif len(args)==3 and args[0]=='add-autostart-confirmed':data=add_autostart(*args[1:])
        else:raise ValueError('Unsupported desktop preference action.')
        result={'ok':True,'observed_at':int(time.time()),'data':data,'error':None}
    except Exception as error:
        message=str(error) if isinstance(error,ValueError) else 'Desktop preference operation failed. Refresh and check desktop registry or file permissions before retrying.'
        result={'ok':False,'observed_at':int(time.time()),'data':None,'error':{'message':message}}
    print(json.dumps(result));return 0 if result['ok'] else 1

if __name__=='__main__':raise SystemExit(main(sys.argv[1:]))
