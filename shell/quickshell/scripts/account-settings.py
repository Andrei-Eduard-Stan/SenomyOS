#!/usr/bin/env python3
"""Bounded account projection and allowlisted AccountsService actions.

No shadow/password data is read. Passwords belong exclusively to passwd's TTY.
AccountsService owns polkit authorization; this client never verifies passwords.
"""
import hashlib
import struct
import json
import os
import pwd
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

def launch_tool(tool, args=()):
    # Read-only provider functions remain available if deployment is incomplete.
    sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "scripts"))
    try:
        from senomy_app_launch import launch_tool as independent_launch
    except ImportError:
        return {"ok":False,"state":"unavailable","message":"The independent application launcher is unavailable; no application was started."}
    return independent_launch(tool, args)


BUS = "org.freedesktop.Accounts"
ROOT = "/org/freedesktop/Accounts"
USER = BUS + ".User"

class Unavailable(Exception):
    def __init__(self,message,state="failed"):
        super().__init__(message);self.state=state

class Backend:
    def __init__(self):
        try:
            from gi.repository import Gio, GLib
            self.Gio, self.GLib = Gio, GLib
            self.connection = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
            self.owner="";self.in_mutation=False
        except Exception as exc:
            raise Unavailable("System account bus unavailable") from exc

    def call(self, path, interface, method, signature=None, values=(), interactive=False, destination=BUS, auto_start=False):
        try:
            parameters = self.GLib.Variant(signature, values) if signature else None
            flags = self.Gio.DBusCallFlags.NONE if auto_start else self.Gio.DBusCallFlags.NO_AUTO_START
            if interactive:flags |= self.Gio.DBusCallFlags.ALLOW_INTERACTIVE_AUTHORIZATION
            if destination==BUS:destination=getattr(self,"owner","") or BUS
            timeout=120000 if interactive or getattr(self,"in_mutation",False) else 2500
            deadline=getattr(self,'deadline',None)
            if deadline is not None:
                remaining=deadline-time.monotonic()
                if remaining<=0:raise Unavailable('Account request time budget expired; refresh actual state','unverified' if getattr(self,'in_mutation',False) else 'failed')
                timeout=min(timeout,max(1,int(remaining*1000)))
            return self.connection.call_sync(destination,path,interface,method,parameters,None,flags,timeout,None).unpack()
        except Exception as exc:
            # DBus errors can include user-supplied values. Keep the UI/log
            # message bounded and never forward unrestricted command output.
            try:remote=self.Gio.DBusError.get_remote_error(exc) or ""
            except TypeError:remote=""
            if any(word in remote.lower() for word in ("cancelled","canceled")):
                raise Unavailable("Authorization was cancelled; no success is assumed.","cancelled") from exc
            if any(word in remote.lower() for word in ("permissiondenied","accessdenied","notauthorized")):
                raise Unavailable("Authorization was denied. No success is assumed; refresh current account state.","denied") from exc
            raise Unavailable("Account service unavailable or the request outcome could not be verified; refresh actual state", "unverified" if getattr(self,"in_mutation",False) else "failed") from exc

    def ensure_available(self):
        self.owner=""
        self.call(ROOT,BUS,"ListCachedUsers",auto_start=True)  # normal read-only D-Bus activation

    def identity(self):
        return self.call('/org/freedesktop/DBus','org.freedesktop.DBus','GetNameOwner','(s)',(BUS,),destination='org.freedesktop.DBus')[0]

    def authorize(self,operation,account):
        self.deadline=time.monotonic()+120
        action='org.freedesktop.accounts.change-own-user-data' if operation in ('name','avatar') and account and account['current'] else 'org.freedesktop.accounts.user-administration'
        subject=('system-bus-name',{'name':self.GLib.Variant('s',self.connection.get_unique_name())})
        authorized,challenge,details=self.call('/org/freedesktop/PolicyKit1/Authority','org.freedesktop.PolicyKit1.Authority','CheckAuthorization',
            '((sa{sv})sa{ss}us)',(subject,action,{},1,''),True,destination='org.freedesktop.PolicyKit1')[0]
        if not authorized:
            cancelled=bool(details.get('polkit.dismissed'))
            raise Unavailable('Authorization was cancelled. No account change was submitted.' if cancelled else 'Authorization was denied or is unavailable. No account change was submitted.','cancelled' if cancelled else 'denied')

    def properties(self, uid):
        path = self.call(ROOT, BUS, "FindUserById", "(x)", (uid,))[0]
        return self.call(path, "org.freedesktop.DBus.Properties", "GetAll", "(s)", (USER,))[0]

    def sessions(self):
        return {int(row[1]) for row in self.call("/org/freedesktop/login1", "org.freedesktop.login1.Manager",
            "ListSessions", destination="org.freedesktop.login1")[0]}

    def mutate(self, operation, account, value):
        if operation == "create":
            return self.call(ROOT, BUS, "CreateUser", "(ssi)", (value, value, 0), False)
        if operation == "remove":
            return self.call(ROOT, BUS, "DeleteUser", "(xb)", (account["uid"], False), False)
        path = self.call(ROOT, BUS, "FindUserById", "(x)", (account["uid"],))[0]
        method, signature, argument = {
            "name": ("SetRealName", "(s)", value),
            "avatar": ("SetIconFile", "(s)", value),
            "lock": ("SetLocked", "(b)", value == "true"),
            "type": ("SetAccountType", "(i)", int(value) if value in ("0", "1") else -1),
        }[operation]
        return self.call(path, USER, method, signature, (argument,), False)

def limits():
    low, high = 1000, 60000
    try:
        for line in Path("/etc/login.defs").read_text().splitlines():
            match = re.match(r"^\s*(UID_MIN|UID_MAX)\s+(\d+)\s*(?:#.*)?$", line)
            if match:
                if match[1] == "UID_MIN": low = int(match[2])
                else: high = int(match[2])
    except OSError:
        pass
    return low, high

def token(account):
    return hashlib.sha256(json.dumps(account, sort_keys=True, separators=(",", ":")).encode()).hexdigest()

def snapshot(backend=None, entries=None, current=None, activate=True):
    current=os.getuid() if current is None else current
    low,high=limits();entries=pwd.getpwall() if entries is None else entries
    accounts=[];complete=True;owner="";sessions=set();warning=""
    try:
        backend=backend or Backend();backend.deadline=time.monotonic()+8
        if activate:backend.ensure_available()
        owner=backend.identity();backend.owner=owner
        backend.call(ROOT,BUS,"ListCachedUsers")
    except Unavailable:
        backend=None;complete=False
    if backend:
        try:sessions=backend.sessions()
        except Unavailable:complete=False;warning="Login-session inventory unavailable; access-removing changes are disabled."
    for entry in entries:
        if not(low<=entry.pw_uid<=high or entry.pw_uid==current):continue
        if len(accounts)>=64:complete=False;break
        props={}
        if backend:
            try:
                props=backend.properties(entry.pw_uid)
                valid=(type(props.get('Uid'))is int and props['Uid']==entry.pw_uid and props.get('UserName')==entry.pw_name
                    and type(props.get('AccountType'))is int and props['AccountType']in(0,1)
                    and type(props.get('Locked'))is bool and type(props.get('SystemAccount'))is bool)
                if not valid:props={};complete=False
            except Unavailable:complete=False
        if props.get('SystemAccount')is True and entry.pw_uid!=current:continue
        admin=props.get('AccountType')==1 if props else None
        shell=entry.pw_shell or ''
        shell_usable=bool(shell and Path(shell).name not in ('nologin','false','halt','shutdown','sync') and os.access(shell,os.X_OK))
        account={'uid':entry.pw_uid,'username':entry.pw_name,'name':str(props.get('RealName',entry.pw_gecos.split(',')[0]))[:256],
            'avatar':str(props.get('IconFile',''))[:4096],'administrator':admin,'locked':props.get('Locked'),
            'current':entry.pw_uid==current,'signedIn':entry.pw_uid in sessions,'managed':bool(props),'providerIdentity':owner,
            'loginShell':shell,'viableAdministrator':admin is True and props.get('Locked')is False and shell_usable}
        account['token']=token(account);accounts.append(account)
    if backend:
        try:
            if backend.identity()!=owner:raise Unavailable('Account provider changed')
        except Unavailable:
            backend=None;complete=False;owner="";warning="Account provider changed during discovery. Refresh before reviewing a change."
    result={'schema_version':1,'available':bool(backend),'complete':complete,'accounts':accounts,'providerIdentity':owner,
        'currentUid':current,'message':warning or ('Account metadata is incomplete; administrative changes are disabled.' if backend and not complete else 'AccountsService / system accounts' if backend else 'AccountsService is unavailable. System account names remain readable; administration requires that provider.'),
        'providerSetupAvailable':bool(shutil.which('kitty')and(Path(__file__).resolve().parents[3]/'scripts/senomy-provider-setup').is_file()),
        'passwordAvailable':bool(shutil.which('kitty')and Path('/usr/bin/passwd').is_file()),
        'administrativePasswordAvailable':bool(backend and shutil.which('kitty')and Path('/usr/bin/pkexec').is_file()and Path('/usr/bin/passwd').is_file()),
        'observedAtMs':int(time.monotonic()*1000)}
    result['token']=token({'providerIdentity':owner,'accounts':accounts,'complete':complete,'currentUid':current})
    return result

def avatar_digest(value):
    """Bound decoding cost before passing an avatar to the system provider."""
    path=Path(value)
    if not path.is_absolute() or not path.is_file() or not 33<=path.stat().st_size<=4*1024*1024:
        raise ValueError("Choose a local PNG no larger than 4 MiB")
    with path.open("rb") as stream:
        header=stream.read(33)
        if header[:8]!=b"\x89PNG\r\n\x1a\n" or header[8:16]!=b"\x00\x00\x00\x0dIHDR":
            raise ValueError("Avatar must be a PNG with a valid image header")
        width,height=struct.unpack(">II",header[16:24])
        if not (1<=width<=2048 and 1<=height<=2048 and width*height<=4194304):
            raise ValueError("Avatar dimensions must be between 1 and 2048 pixels")
        stream.seek(0);payload=stream.read(4*1024*1024+1)
        if len(payload)>4*1024*1024:raise ValueError("Avatar changed; choose a PNG no larger than 4 MiB")
    return hashlib.sha256(payload).hexdigest()

def provider_setup_command():
    helper=Path(__file__).resolve().parents[3]/"scripts/senomy-provider-setup"
    if not helper.is_file() or not os.access(helper,os.X_OK):
        raise ValueError("Account provider setup helper is unavailable")
    return [str(helper),"install","accounts","--confirmed"]

def validate(operation, uid, value, expected, state):
    if operation not in {"create", "remove", "name", "avatar", "lock", "type", "password", "setup"}:
        raise ValueError("Unknown account action")
    if operation == "setup":
        if uid!=-1 or value or expected or not shutil.which("kitty"):
            raise ValueError("Provider setup requires an available secure terminal and no account arguments")
        provider_setup_command();return None
    if operation == "create":
        if not state["available"] or not state["complete"]: raise ValueError("Complete AccountsService inventory required")
        if state.get("token") and expected!=state["token"]:raise ValueError("Account inventory changed; review creation again")
        if uid != -1 or not re.fullmatch(r"[a-z_][a-z0-9_-]{0,30}", value): raise ValueError("Invalid new username")
        if any(a["username"] == value for a in state["accounts"]): raise ValueError("Account already exists")
        try: pwd.getpwnam(value)
        except KeyError: return None
        raise ValueError("That username belongs to an existing account")
    account = next((a for a in state["accounts"] if a["uid"] == uid), None)
    if not account or account["token"] != expected: raise ValueError("Account changed; review a fresh snapshot")
    if operation == "password":
        if not state["passwordAvailable"] or (not account["current"] and not state.get("administrativePasswordAvailable",False)):
            raise ValueError("Secure password handoff or system authorization is unavailable")
        return account
    if not state["available"] or not account["managed"]: raise ValueError("AccountsService required")
    if operation in {"remove", "lock", "type"}:
        if not state["complete"]: raise ValueError("Complete account and login inventory required")
        if account["current"]: raise ValueError("The active account cannot be removed, locked or demoted here")
        if account["signedIn"] and (operation=="remove" or operation=="lock" and value=="true" or operation=="type" and value=="0"):raise ValueError("Sign the account out before removing or disabling its access")
        removes_access = operation == "remove" or (operation == "lock" and value == "true") or (operation == "type" and value == "0")
        viable = [a for a in state["accounts"] if a.get("viableAdministrator") is True]
        if removes_access and account["administrator"] and not any(a["uid"]!=account["uid"] for a in viable): raise ValueError("The last viable administrator must be preserved")
    if operation == "name" and (not value.strip() or len(value)>128 or any(ord(c)<32 for c in value)): raise ValueError("Invalid display name")
    if operation == "avatar":avatar_digest(value)
    if operation == "lock" and value not in {"true","false"}: raise ValueError("Invalid lock state")
    if operation == "type" and value not in {"0","1"}: raise ValueError("Invalid account type")
    return account

def apply(operation, uid, value, expected, backend=None):
    state = snapshot(backend)
    account = validate(operation, uid, value, expected, state)
    if operation == "setup":
        launched=launch_tool("provider-setup",["accounts"])
        if not launched["ok"]:return launched
        return {"ok":True,"state":"handed-off","message":"Setup terminal opened. Review pacman's transaction and enter authorization only there. Package installation is not yet confirmed."}
    avatar_before=avatar_digest(value) if operation=="avatar" else None
    if operation == "password":
        # Password entry, PAM interaction and output belong to the terminal.
        launched=launch_tool("password",[account["username"]])
        if not launched["ok"]:return launched
        return {"ok":True,"state":"handed-off","message":"Secure passwd terminal opened. Password-change success must be checked there."}
    backend = backend or Backend()
    owner=state.get('providerIdentity')
    backend.authorize(operation,account)
    fresh=snapshot(backend)
    if fresh.get('providerIdentity')!=owner:raise ValueError('AccountsService changed during authentication. No account change was submitted.')
    account=validate(operation,uid,value,expected,fresh)
    if operation=='avatar' and avatar_digest(value)!=avatar_before:raise ValueError('The avatar changed during authentication. Choose and review it again.')
    backend.owner=fresh.get('providerIdentity','')
    backend.deadline=time.monotonic()+60
    backend.in_mutation=True
    try:backend.mutate(operation,account,value)
    finally:backend.in_mutation=False
    after = snapshot(backend)
    changed=next((a for a in after["accounts"] if a["uid"]==uid),None)
    observed=False
    if after["available"] and after.get("providerIdentity")==fresh.get("providerIdentity") and (after["complete"] or operation in ("name","avatar") and changed and changed["managed"]):
        if operation=="remove":observed=changed is None
        elif operation=="create":observed=any(a["username"]==value and a["managed"] and a["administrator"] is False for a in after["accounts"])
        elif changed:
            if operation=="avatar":
                # AccountsService copies icons to its own directory. Compare
                # bounded content, not the caller's original pathname.
                try:observed=avatar_digest(changed["avatar"])==avatar_before
                except (ValueError,OSError):observed=False
            elif operation=="name":observed=changed["name"]==value
            elif operation=="lock":observed=changed["locked"]==(value=="true")
            elif operation=="type":observed=changed["administrator"]==(value=="1")

    return {"ok":observed,"state":"succeeded" if observed else "unverified",
        "message":"Account provider confirmed the change. Home files were retained." if observed and operation=="remove" else
        "Account provider confirmed the change." if observed else "Request returned, but refreshed account state did not confirm it. Inspect current state before retrying.","snapshot":after}

def watch():
    from gi.repository import Gio,GLib
    backend=Backend();loop=GLib.MainLoop();pending=0;activate=True
    def emit():
        nonlocal pending,activate
        state=snapshot(backend,activate=activate);activate=False
        pending=0;print(json.dumps(state,separators=(',',':')),flush=True);return False
    def changed(*args):
        nonlocal pending
        if not pending:pending=GLib.timeout_add(150,emit)
    flags=Gio.DBusSignalFlags.NONE
    for sender,interface,member,path,arg in [
        (BUS,None,None,None,None),
        ('org.freedesktop.login1','org.freedesktop.login1.Manager','SessionNew','/org/freedesktop/login1',None),
        ('org.freedesktop.login1','org.freedesktop.login1.Manager','SessionRemoved','/org/freedesktop/login1',None),
        ('org.freedesktop.DBus','org.freedesktop.DBus','NameOwnerChanged','/org/freedesktop/DBus',BUS),
        ('org.freedesktop.DBus','org.freedesktop.DBus','NameOwnerChanged','/org/freedesktop/DBus','org.freedesktop.login1')]:
        backend.connection.signal_subscribe(sender,interface,member,path,arg,flags,changed)
    def request(channel,condition):
        nonlocal activate
        if condition&(GLib.IO_HUP|GLib.IO_ERR):loop.quit();return False
        line=sys.stdin.readline()
        if not line:loop.quit();return False
        if line.strip()=='refresh':activate=True;changed()
        return True
    GLib.io_add_watch(sys.stdin,GLib.IO_IN|GLib.IO_HUP|GLib.IO_ERR,request)
    emit();loop.run();return 0


def main():
    try:
        if sys.argv[1:]==["watch"]:return watch()
        if sys.argv[1:]==["status"]: result=snapshot()
        elif len(sys.argv)==3 and sys.argv[1]=="avatar-info":
            digest=avatar_digest(sys.argv[2])
            result={"ok":True,"path":sys.argv[2],"digest":digest}
        elif len(sys.argv)==7 and sys.argv[1]=="apply" and sys.argv[6]=="--confirmed":
            result=apply(sys.argv[2],int(sys.argv[3]),sys.argv[4],sys.argv[5])
        else: raise ValueError("Expected status or an allowlisted confirmed account operation")
        print(json.dumps(result,separators=(",", ":")));return 0
    except (ValueError,Unavailable,OSError,TypeError) as exc:
        print(json.dumps({"ok":False,"state":getattr(exc,"state","failed"),"message":str(exc)[:256]},separators=(",", ":")));return 1
if __name__=="__main__":sys.exit(main())
