#!/usr/bin/env python3
"""Secret-free NM profile inventory, reviewed policy actions and native editors."""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

def launch_tool(tool, args=()):
    # Read-only provider functions remain available if deployment is incomplete.
    sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "scripts"))
    try:
        from senomy_app_launch import launch_tool as independent_launch
    except ImportError:
        return {"ok":False,"state":"unavailable","message":"The independent application launcher is unavailable; no application was started."}
    return independent_launch(tool, args)

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


def provider_identity():
    from gi.repository import Gio, GLib
    bus=Gio.bus_get_sync(Gio.BusType.SYSTEM,None)
    return bus.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','GetNameOwner',GLib.Variant('(s)',('org.freedesktop.NetworkManager',)),GLib.VariantType.new('(s)'),Gio.DBusCallFlags.NO_AUTO_START,1500,None).unpack()[0]


def profile_item(values, owner):
    uuid,name,kind,auto,active=values
    return {'uuid':uuid,'name':''.join(c if c.isprintable() else ' ' for c in name)[:200],
            'type':kind,'autoconnect':auto=='yes','active':active=='yes','mutable':kind in TYPES,
            'token':hashlib.sha256(json.dumps([owner,values]).encode()).hexdigest()}


def catalog():
    owner=provider_identity()
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
        items.append(profile_item(values,owner))
    if provider_identity()!=owner:raise ValueError('NetworkManager changed during discovery. Refresh before retrying.')
    return {'items':items,'providerIdentity':owner,'available':True,'editorAvailable':bool(shutil.which('nm-connection-editor')),'authenticationAvailable':bool(shutil.which('kitty')),
            'message':'Connection-specific DNS and PAC proxy settings use the native editor. VPN setup depends on installed plugins; application-wide proxy behavior is not guaranteed.'}


def reviewed(verb,uuid,token):
    if verb not in ('forget','disconnect','autoconnect','connect') or not UUID.fullmatch(uuid) or not re.fullmatch('[0-9a-f]{64}',token):
        raise ValueError('Unsupported profile action.')
    inventory=catalog();current=next((item for item in inventory['items'] if item['uuid']==uuid),None)
    if not current or not current['mutable'] or current['token']!=token:
        raise ValueError('Profile changed since review. Review it again; nothing was changed.')
    if verb=='forget' and current['active']:raise ValueError('Disconnect and review this profile before forgetting it.')
    if verb=='disconnect' and not current['active']:raise ValueError('The profile is no longer active.')
    if verb=='connect':
        if current['active']:raise ValueError('The profile is already active.')
        launched=launch_tool('network-profile-auth',[uuid])
        if not launched['ok']:raise ValueError(launched['message'])
        return {'state':'awaiting-activation','message':'Authentication terminal opened. NetworkManager activation is being observed; internet reachability is separate.'}
    binary=shutil.which('nmcli')
    args=[binary,'--wait','15','connection']
    if verb=='forget':args+=['delete','uuid',uuid]
    elif verb=='disconnect':args+=['down','uuid',uuid]
    else:args+=['modify','uuid',uuid,'connection.autoconnect','no' if current['autoconnect'] else 'yes']
    run(args,timeout=20)
    try:
        observed=catalog()
        if observed['providerIdentity']!=inventory['providerIdentity']:raise ValueError('NetworkManager changed')
        after=next((item for item in observed['items'] if item['uuid']==uuid),None)
    except (OSError,ValueError,subprocess.SubprocessError):
        return {'state':'unverified','message':'Request returned, but current profile state could not be verified. Refresh before retrying.'}
    complete=(after is None if verb=='forget' else bool(after) and (not after['active'] if verb=='disconnect' else after['autoconnect']!=current['autoconnect']))
    return {'state':'succeeded' if complete else 'unverified','message':'NetworkManager reported the requested profile state.' if complete else 'Requested profile state was not observed. The request may still finish; refresh before retrying.'}


def open_editor(mode,uuid=None):
    if mode not in ('all','vpn','edit'):raise ValueError('Unsupported editor mode.')
    binary=shutil.which('nm-connection-editor')
    if not binary:raise OSError('Network profile editor unavailable.')
    if mode=='edit':
        if not uuid or not UUID.fullmatch(uuid) or not any(item['uuid']==uuid for item in catalog()['items']):
            raise ValueError('Profile is no longer available. Refresh before editing.')
    launched=launch_tool('network-editor',[mode]+([uuid] if mode=='edit' else []))
    if not launched['ok']:raise ValueError(launched['message'])
    return {'state':'started','message':'Native editor launch requested. Saved configuration and connection behavior are not yet verified.'}


def ip_details(config):
    if config is None:return {'addresses':[],'dns':[],'gateway':None,'routes':[]}
    return {'addresses':[f'{a.get_address()}/{a.get_prefix()}' for a in config.get_addresses()[:32]],
            'dns':list(config.get_nameservers())[:32], 'gateway':config.get_gateway() or None,
            'routes':[{'destination':r.get_dest(),'prefix':r.get_prefix(),'nextHop':r.get_next_hop() or None,'metric':r.get_metric()} for r in config.get_routes()[:64]]}


def network_snapshot(client):
    owner=client.get_dbus_name_owner() or ''
    if not client.get_nm_running() or not owner:
        return {'providerIdentity':'','providerAvailable':False,'available':False,'items':[],'devices':[],
                'message':'NetworkManager is unavailable. Waiting for its return; no service restart is requested.'}
    active=client.get_active_connections();active_ids={a.get_uuid() for a in active if a.get_state().value_nick=='activated'};items=[]
    for c in client.get_connections()[:128]:
        uuid=c.get_uuid()
        if not uuid or not UUID.fullmatch(uuid):continue
        setting=c.get_setting_connection()
        items.append(profile_item([uuid,c.get_id() or '',c.get_connection_type() or '',
                                  'yes' if setting and setting.get_autoconnect() else 'no','yes' if uuid in active_ids else 'no'],owner))
    primary=client.get_primary_connection();primary_devices=primary.get_devices() if primary else []
    devices=[]
    for d in client.get_devices()[:32]:
        if d.get_device_type().value_nick in ('loopback','wifi-p2p'):continue
        conn=d.get_active_connection()
        devices.append({'interface':d.get_iface(),'type':d.get_device_type().value_nick,
                        'state':d.get_state().value_nick,'reason':d.get_state_reason().value_nick,'managed':bool(d.get_managed()),
                        'connection':conn.get_id() if conn else '', 'ipv4':ip_details(d.get_ip4_config()),'ipv6':ip_details(d.get_ip6_config())})
    from urllib.parse import urlsplit
    uri=client.connectivity_check_get_uri() or ''
    parsed=urlsplit(uri)
    if parsed.scheme not in ('http','https') or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:uri=''
    return {'providerIdentity':owner,'providerAvailable':True,'available':True,'items':items,'devices':devices,
            'networkingEnabled':bool(client.networking_get_enabled()),'primaryDevice':primary_devices[0].get_iface() if primary_devices else '',
            'primaryConnection':primary.get_id() if primary else '', 'connectivity':client.get_connectivity().value_nick,'portalUri':uri,
            'activeTunnels':[{'name':a.get_id(),'type':a.get_connection_type(),'state':a.get_state().value_nick} for a in active if a.get_connection_type() in ('vpn','wireguard')],
            'editorAvailable':bool(shutil.which('nm-connection-editor')),'authenticationAvailable':bool(shutil.which('kitty') and shutil.which('nmcli')),
            'message':'NetworkManager owns saved profiles, DNS, routes and autoconnect. Advanced/hidden/enterprise configuration stays in the native editor; VPN plugins and credentials must be installed separately.'}


def release_signals(bindings):
    from gi.repository import GObject
    for obj,handler in bindings:
        if GObject.signal_handler_is_connected(obj,handler):GObject.signal_handler_disconnect(obj,handler)
    bindings.clear()


def watch():
    import gi
    gi.require_version('NM','1.0')
    from gi.repository import NM,GLib,GObject
    client=NM.Client.new(None);loop=GLib.MainLoop();bindings=[];pending=0
    def changed(*args):
        nonlocal pending
        if not pending:pending=GLib.timeout_add(200,publish)
    def publish():
        nonlocal pending
        pending=0
        release_signals(bindings)
        try:
            data=network_snapshot(client)
            objects=[(c,'changed') for c in client.get_connections()]
            for d in client.get_devices():
                for key in ('state','state-reason','ip4-config','ip6-config','active-connection','managed','interface'):
                    objects.append((d,'notify::'+key))
                for ip in (d.get_ip4_config(),d.get_ip6_config()):
                    if ip:objects.append((ip,'notify'))
            for a in client.get_active_connections():objects.append((a,'notify::state'))
            for obj,signal in objects:bindings.append((obj,GObject.Object.connect(obj,signal,changed)))
            result={'ok':True,'observed_at':int(time.time()),'data':data,'error':None}
        except Exception:
            result={'ok':False,'observed_at':int(time.time()),'data':None,'error':{'message':'Network status could not be read. Refresh inventory; current connectivity may still be working.'}}
        print(json.dumps(result),flush=True)
        return False
    for signal in ('device-added','device-removed','connection-added','connection-removed','active-connection-added','active-connection-removed'):GObject.Object.connect(client,signal,changed)
    keys={'nm-running','dbus-name-owner','primary-connection','activating-connection','active-connections','devices','connections','networking-enabled','connectivity'}
    GObject.Object.connect(client,'notify',lambda obj,prop:changed() if prop.name in keys else None)
    # One shell-owned observer; no scans, connectivity probes or per-second CLI polling.
    def request(channel,condition):
        if condition & (GLib.IO_HUP|GLib.IO_ERR):loop.quit();return False
        line=sys.stdin.readline()
        if not line:loop.quit();return False
        if line.strip()=='refresh':changed()
        return True
    GLib.io_add_watch(sys.stdin,GLib.IO_IN|GLib.IO_HUP|GLib.IO_ERR,request)
    publish();loop.run();return 0


def main(args):
    try:
        if args==['watch']:return watch()
        if args==['catalog']:data=catalog()
        elif len(args)==4 and args[0]=='apply-confirmed':data=reviewed(*args[1:])
        elif len(args) in (2,3) and args[0]=='open-editor':data=open_editor(*args[1:])
        else:raise ValueError('Unsupported profile operation.')
        result={'ok':True,'observed_at':int(time.time()),'data':data,'error':None}
    except Exception as error:
        message=str(error) if isinstance(error,ValueError) else 'Profile operation failed or timed out. Check NetworkManager permissions and refresh state before retrying.'
        result={'ok':False,'observed_at':int(time.time()),'data':None,'error':{'message':message}}
    print(json.dumps(result));return 0 if result['ok'] else 1

if __name__=='__main__':raise SystemExit(main(sys.argv[1:]))
