#!/usr/bin/env python3
"""Independent user application scopes. No device mutations or arbitrary shell.

The scope is entered BEFORE GIO/native launch. Request data travels on stdin,
not systemd's command line/properties/journal. Caller env/cwd/UID are inherited;
we never import or overwrite the user manager environment. Shell helpers do not
use this boundary. A successful receipt means launch/handoff, not app readiness.
"""
from pathlib import Path
import json
import os
import pwd
import re
import shutil
import subprocess
import sys
import uuid

ROOT = Path(os.environ.get("SENOMY_SOURCE_ROOT", str(Path(__file__).resolve().parent.parent))).resolve()
MAX_REQUEST = 65536

class LaunchError(ValueError):
    pass

class LaunchUnverified(LaunchError):
    pass

def string(value, limit=4096):
    if not isinstance(value, str) or not value or len(value)>limit or any(ord(c)<32 or ord(c)==127 for c in value):
        raise LaunchError('Invalid application launch argument.')
    return value

def local_path(value):
    path=Path(string(value))
    if not path.is_absolute() or not path.exists():
        raise LaunchError('The selected local file or folder is unavailable.')
    return str(path)

def validate(request):
    if not isinstance(request,dict) or set(request)-{'kind','target','args'}:
        raise LaunchError('Invalid application launch request.')
    kind=request.get('kind');target=string(request.get('target'))
    args=request.get('args',[])
    if not isinstance(args,list) or len(args)>32:
        raise LaunchError('Too many application launch arguments.')
    args=[string(arg) for arg in args]
    if kind=='desktop':
        if '/' in target or not target.endswith('.desktop') or target.startswith('-'):
            raise LaunchError('Choose an installed desktop entry.')
        for arg in args: uri_or_file(arg)
    elif kind=='open':
        uri_or_file(target)
        if args:raise LaunchError('Open accepts one file or URI.')
    elif kind=='tool':
        tool_argv(target,args) # fixed per-tool validation before creating scope
    else:raise LaunchError('Unsupported application launch operation.')
    return {'kind':kind,'target':target,'args':args}

def uri_or_file(value):
    from urllib.parse import urlsplit
    string(value)
    if value.startswith('/'):
        local_path(value);return value
    parsed=urlsplit(value)
    if parsed.scheme not in ('http','https','mailto','file') or parsed.username or parsed.password:
        raise LaunchError('Unsupported or credential-bearing URI.')
    if parsed.scheme in ('http','https') and not parsed.hostname:
        raise LaunchError('Invalid web address.')
    if parsed.scheme=='file':
        from urllib.parse import unquote
        if parsed.netloc not in ('','localhost') or parsed.query or parsed.fragment:
            raise LaunchError('Only local file addresses are supported.')
        local_path(unquote(parsed.path))
    return value

def executable(name):
    binary=shutil.which(name)
    if not binary:raise LaunchError('Required application tool is not installed: '+name)
    return binary

def project_tool(relative,installed):
    source=ROOT/relative
    return str(source) if source.is_file() and os.access(source,os.X_OK) else executable(installed)

def tool_argv(tool,args):
    kitty=lambda:executable('kitty')
    if tool=='terminal' and not args:return [kitty()]
    if tool=='maintenance' and not args:
        return [kitty(),'--hold','--class','senomy-maintenance','--title','SenomyOS official package review','--',executable('python3'),'-B',project_tool('scripts/senomy-maintenance.py','senomy-maintenance'),'terminal']
    if tool=='lens' and len(args)==1 and args[0] in ('all','apps','files','windows','actions'):
        return [project_tool('components/launcher/rofi/scripts/senomy-command-lens','senomy-command-lens'),'--mode',args[0]]
    if tool=='thunar-daemon' and not args:return [executable('thunar'),'--daemon']
    if tool=='network-editor':
        if args==['all']:return [executable('nm-connection-editor')]
        if args==['create-wifi']:return [executable('nm-connection-editor'),'--create','--type','wifi']
        if args==['vpn']:return [executable('nm-connection-editor'),'--show','vpn']
        if len(args)==2 and args[0]=='edit' and re.fullmatch(r'[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}',args[1]):
            return [executable('nm-connection-editor'),'--edit',args[1]]
    elif tool=='wifi-auth' and len(args)==1 and not args[0].startswith('-'):
        return [kitty(),'--title','SenomyOS Wi-Fi authentication','--',executable('nmcli'),'--ask','device','wifi','connect',args[0]]
    elif tool=='wifi-auth-device' and len(args)==2 and re.fullmatch(r'(?:[0-9A-F]{2}:){5}[0-9A-F]{2}',args[0]) and re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.:-]{0,63}',args[1]):
        return [kitty(),'--class','senomy-network-auth','--title','SenomyOS Network Authentication','--',executable('nmcli'),'--ask','device','wifi','connect',args[0],'ifname',args[1]]
    elif tool=='wifi-auth-interface' and len(args)==2 and not args[0].startswith('-') and re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.:-]{0,63}',args[1]):
        return [kitty(),'--class','senomy-network-auth','--title','SenomyOS Network Authentication','--',executable('nmcli'),'--ask','device','wifi','connect',args[0],'ifname',args[1]]
    elif tool=='network-profile-auth' and len(args)==1 and re.fullmatch(r'[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}',args[0]):
        return [kitty(),'--class','senomy-network-auth','--title','SenomyOS Profile Authentication','--',executable('nmcli'),'--ask','connection','up','uuid',args[0]]
    elif tool=='password' and len(args)==1 and re.fullmatch(r'[A-Za-z_][A-Za-z0-9_.-]{0,31}',args[0]):
        current=pwd.getpwuid(os.getuid()).pw_name
        command=[executable('passwd')] if args[0]==current else [executable('pkexec'),executable('passwd'),'--',args[0]]
        return [kitty(),'--title','Change password: '+args[0],'--',*command]
    elif tool=='provider-setup' and len(args)==1 and args[0] in ('accounts','idle'):
        return [kitty(),'--hold','--title','SenomyOS provider setup','--',project_tool('scripts/senomy-provider-setup','senomy-provider-setup'),'install',args[0],'--confirmed']
    elif tool=='calendar-credential' and len(args)==1 and re.fullmatch(r'[a-f0-9]{32}',args[0]):
        return [kitty(),'--class','senomy-calendar-credential','--',project_tool('scripts/senomy-calendar-credential','senomy-calendar-credential'),args[0]]
    elif tool=='report' and len(args)==1:
        return [kitty(),'--class','senomy-report','--title','Senomy Evidence Report','--',executable('less'),'--',local_path(args[0])]
    elif tool=='console-shell' and len(args)==1 and args[0] in ('bash','zsh','fish','pwsh'):
        title={'bash':'Bash','zsh':'Zsh','fish':'Fish','pwsh':'PowerShell'}[args[0]]
        return [kitty(),'--class','senomy-console','--title','Senomy Console // '+title,'--directory',str(Path.home()),executable(args[0]),'-Login' if args[0]=='pwsh' else '-l']
    elif tool=='code-report' and len(args)==1:return [executable('code'),'--reuse-window',local_path(args[0])]
    elif tool=='ime' and not args:return [executable('fcitx5-configtool')]
    elif tool=='files' and len(args)==2 and args[0] in ('--','--select'):
        local_path(args[1])
        return [project_tool('components/file-manager/thunar/scripts/senomy-file-workspace','senomy-file-workspace'),*args]
    raise LaunchError('Unsupported native tool or arguments.')

def gio_launch(request):
    import gi
    from gi.repository import Gio, GLib
    try:
        gi.require_version('GioUnix','2.0')
        from gi.repository import GioUnix
        desktop=GioUnix.DesktopAppInfo
    except (ValueError,ImportError):desktop=Gio.DesktopAppInfo
    context=Gio.AppLaunchContext()
    # Keep activation information supplied by the caller. GDK obtains a fresh
    # native startup context when a display is available; offscreen has none.
    try:
        gi.require_version('Gdk','3.0')
        from gi.repository import Gdk
        Gdk.init_check([])
        display=Gdk.Display.get_default()
        if display:context=display.get_app_launch_context()
    except (ValueError,ImportError,GLib.Error):pass
    for key in ('XDG_ACTIVATION_TOKEN','DESKTOP_STARTUP_ID'):
        if key in os.environ:context.setenv(key,os.environ[key])
    def uri(value):return Gio.File.new_for_path(value).get_uri() if value.startswith('/') else value
    if request['kind']=='desktop':
        app=desktop.new(request['target'])
        if not app or app.get_is_hidden():raise LaunchError('The installed application entry is unavailable.')
        # GIO owns field codes, Terminal, Path, TryExec, URI forwarding and
        # D-Bus activation. Never split/rebuild the desktop Exec string.
        operation=lambda callback:app.launch_uris_async([uri(x) for x in request['args']],context,None,callback)
        finish=lambda obj,res:obj.launch_uris_finish(res)
    else:
        operation=lambda callback:Gio.AppInfo.launch_default_for_uri_async(uri(request['target']),context,None,callback)
        finish=lambda obj,res:Gio.AppInfo.launch_default_for_uri_finish(res)
    loop=GLib.MainLoop();outcome=[];failure=[]
    def completed(obj,result,*unused):
        try:outcome.append(bool(finish(obj,result)))
        except GLib.Error:
            outcome.append(False)
            if request['kind']=='desktop' and app.get_boolean('Terminal'):
                failure.append('The terminal application could not be launched. Check xdg-terminal-exec or a GIO-compatible terminal and this desktop entry.')
        loop.quit()
    def expired():
        loop.quit();return GLib.SOURCE_REMOVE
    deadline=GLib.timeout_add_seconds(10,expired)
    operation(completed)
    if not outcome:loop.run()
    if outcome:GLib.source_remove(deadline)
    else:raise LaunchUnverified('Application activation did not return in time. It may already be running; check before retrying.')
    if not outcome[0]:raise LaunchError(failure[0] if failure else 'Application activation failed. Check its desktop entry, executable and session provider.')

def worker():
    raw=sys.stdin.buffer.read(MAX_REQUEST+1)
    if len(raw)>MAX_REQUEST:raise LaunchError('Application request exceeds its size limit.')
    request=validate(json.loads(raw))
    groups=Path('/proc/self/cgroup').read_text()
    if os.geteuid()!=os.getuid() or os.getuid()==0 or not re.search(r'/app-senomy-[a-f0-9]{32}\.scope(?:/|$)',groups.strip()):
        raise LaunchError('Application worker requires its independently created user scope.')
    # Neither applications nor inherited children may keep the receipt pipe
    # open or read the request. The saved receipt FD is close-on-exec.
    reply=os.dup(sys.stdout.fileno())
    with open(os.devnull,'r+b') as null:
        for fd in (0,1,2):os.dup2(null.fileno(),fd)
    child_pid=None
    try:
        if request['kind']=='tool':
            argv=tool_argv(request['target'],request['args'])
            # Keep the file-manager daemon independent of the launching terminal/session.
            child=subprocess.Popen(argv,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,close_fds=True,
                                   start_new_session=(request['target']=='thunar-daemon'))
            child_pid=child.pid
        else:gio_launch(request)
        result={'ok':True,'state':'handed-off','message':'Application launch accepted in an independent user scope. Visible opening remains unverified.'}
    except Exception as exc:
        result={'ok':False,'state':'unverified' if isinstance(exc,LaunchUnverified) else 'failed','message':str(exc) if isinstance(exc,LaunchError) else 'Application launch failed. Check its executable, desktop entry and session activation provider.'}
    if child_pid is not None:result['pid']=child_pid
    with os.fdopen(reply,'w') as stream:json.dump(result,stream);stream.write('\n')
    return 0 if result['ok'] else 1

def launch(request):
    try:
        request=validate(request)
        if os.geteuid()!=os.getuid() or os.getuid()==0:
            raise LaunchError('Application launch requires an ordinary unprivileged user.')
        runner=executable('systemd-run')
        unit='app-senomy-'+uuid.uuid4().hex+'.scope'
        command=[runner,'--user','--scope','--quiet','--collect','--expand-environment=no','--slice=app.slice',
                 '--unit='+unit,'--description=SenomyOS application','--',sys.executable,'-B',str(Path(__file__).resolve()),'--worker']
        # Scope launch retains caller cwd/env/UID. No manager environment import,
        # setenv command-line secrets, privilege change, shell or unsafe fallback.
        environment=dict(os.environ)
        for key in ('NOTIFY_SOCKET','WATCHDOG_PID','WATCHDOG_USEC','WATCHDOG_DEVICE','INVOCATION_ID','SYSTEMD_EXEC_PID','MAINPID','LISTEN_PID','LISTEN_FDS','LISTEN_FDNAMES','JOURNAL_STREAM'):
            environment.pop(key,None)
        result=subprocess.run(command,input=json.dumps(request),text=True,capture_output=True,timeout=15,env=environment)
        try:receipt=json.loads(result.stdout)
        except (ValueError,TypeError):raise LaunchError('The user application scope could not be started. Check the user service manager; no direct launch fallback was used.')
        if (not isinstance(receipt,dict) or type(receipt.get('ok')) is not bool or len(result.stdout)>4096
            or receipt.get('state') not in ('handed-off','failed','unverified')
            or not isinstance(receipt.get('message'),str) or not 0<len(receipt['message'])<=1024):
            raise LaunchError('The application launch receipt was invalid. Check current state before retrying.')
        if result.returncode!=0 and receipt['ok']:
            receipt={'ok':False,'state':'unverified','message':'The scope runner failed after accepting the launch. The application may already be running; check before retrying.'}
        receipt['unit']=unit
        if receipt['ok'] and request['kind']=='desktop':
            # Accepted handoff only; never count failures or replay a launch.
            try:
                from senomy_app_usage import record
                record(request['target'])
            except Exception:
                pass # Optional history cannot turn an accepted launch into failure.
        return receipt
    except subprocess.TimeoutExpired:
        # A scope may already exist and launch may have succeeded. NEVER replay
        # or kill it just because its receipt was lost. No automatic retry.
        return {'ok':False,'state':'unverified','unit':unit,'message':'The launch receipt timed out. The application may already be running; check before launching again.'}
    except (LaunchError,OSError,ValueError) as exc:
        return {'ok':False,'state':'failed','message':str(exc) if isinstance(exc,LaunchError) else 'Application launcher unavailable. No direct launch fallback was used.'}

def launch_tool(tool,args=()):return launch({'kind':'tool','target':tool,'args':list(args)})

def migration_status():
    """Conservative read-only restart guard. Never migrates/signals old apps."""
    try:
        result=subprocess.run(['systemctl','--user','show','senomy-quickshell.service','--property=MainPID,ControlGroup','--no-pager'],capture_output=True,text=True,timeout=4,check=True)
        fields=dict(line.split('=',1) for line in result.stdout.splitlines() if '=' in line)
        main=int(fields['MainPID']);relative=fields['ControlGroup']
        if main<=0 or not relative.startswith('/user.slice/') or '..' in relative.split('/'):
            raise LaunchError('Shell ownership could not be verified; restart was refused.')
        group=Path('/sys/fs/cgroup')/relative.lstrip('/')
        pids=set()
        for path in group.rglob('cgroup.procs'):
            pids.update(int(x) for x in path.read_text().split())
            if len(pids)>8192:raise LaunchError('Shell ownership inventory exceeded its bound; restart was refused.')
        foreign=[]
        owned={'account-settings.py','network-profiles.py','battery-care-client.py','energy-provider.py','bluetooth-controller.py','notification-owner.py','osk-automatic.py','osk-lock-state.py','osk-geometry.py','osk-provider.py'}
        tools={str(Path(binary).resolve()) for name in ('pw-dump','wvkbd-mobintl','wvkbd-deskintl','systemctl','hyprctl','notify-send') if (binary:=shutil.which(name))}
        for pid in sorted(pids-{main,os.getpid()}):
            proc=Path('/proc')/str(pid)
            try:
                args=(proc/'cmdline').read_bytes().decode(errors='replace').split('\0');comm=(proc/'comm').read_text().strip()
                exe=str((proc/'exe').resolve(strict=True))
                python=exe==str(Path(sys.executable).resolve())
                known=exe in tools or (python and any(Path(a).name in owned and a==str(ROOT/'shell/quickshell/scripts'/Path(a).name) for a in args[1:3]))
                if not known:foreign.append({'pid':pid,'name':comm[:80]})
            except FileNotFoundError:continue
        if foreign:return {'ok':False,'state':'migration-required','processes':foreign[:128],'processCount':len(foreign),'message':'Restart refused: existing or unclassified application processes still belong to the old shell cgroup. Save and close these applications, or finish a normal logout/login when ready. This check never moves or terminates them.'}
        return {'ok':True,'state':'restart-safe','processes':[],'message':'No unclassified application descendants were observed. New launches must use independent app scopes.'}
    except (OSError,ValueError,KeyError,subprocess.SubprocessError) as exc:
        return {'ok':False,'state':'unverified','message':str(exc) if isinstance(exc,LaunchError) else 'Shell process ownership could not be verified; restart was refused.'}

def main(args):
    if args==['--worker']:
        try:return worker()
        except Exception:
            print(json.dumps({'ok':False,'state':'failed','message':'Invalid application worker request.'}));return 1
    quiet=bool(args and args[0]=='--quiet')
    if quiet:args=args[1:]
    if args==['check-restart']:result=migration_status()
    elif len(args)>=2 and args[0] in ('desktop','open','tool'):
        result=launch({'kind':args[0],'target':args[1],'args':args[2:]})
    else:result={'ok':False,'state':'failed','message':'Use desktop ID [URI...], open FILE_OR_URI, tool NAME [ARGS...], or check-restart.'}
    if not quiet:print(json.dumps(result,separators=(',',':')))
    elif not result['ok']:print(result['message'],file=sys.stderr)
    return 0 if result['ok'] else 1

if __name__=='__main__':raise SystemExit(main(sys.argv[1:]))
