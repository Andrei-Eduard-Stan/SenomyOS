#!/usr/bin/env python3
"""Read-only maintenance evidence and explicitly confirmed native pacman handoff."""
import fcntl
import json
import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path
from senomy_release import read_json, safe, write_json
ROOT=Path(__file__).resolve().parents[1]
STATE=Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))/'senomyos/maintenance'


def identity(pid):
    try:return Path('/proc/sys/kernel/random/boot_id').read_text().strip()+':'+Path('/proc') .joinpath(str(pid),'stat').read_text().rsplit(')',1)[1].split()[19]
    except OSError:return None


def reboot():
    running=platform.release()
    if Path('/run/reboot-required').exists(): return {'state':'required','reason':'System reboot-required marker exists','runningKernel':running}
    modules=Path('/usr/lib/modules')
    if modules.exists() and any(modules.iterdir()) and not (modules/running).is_dir():
        return {'state':'recommended','reason':'Running kernel modules are no longer installed; boot the installed kernel before device recovery','runningKernel':running}
    return {'state':'unknown','reason':'No universal Arch reboot indicator. Review pacman hooks and services; a successful package transaction does not prove all running code is current.','runningKernel':running}


def status():
    transaction=read_json(STATE/'last.json') if (STATE/'last.json').exists() else {'state':'not-run'}
    if transaction.get('state') in ('awaiting-confirmation','running') and identity(transaction.get('pid',0))!=transaction.get('identity'):
        transaction={**transaction,'state':'interrupted','message':'Terminal disappeared without a recorded result. Inspect pacman state before retrying; no automatic rollback or retry.'}
    store=Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))/'senomyos/runtime'
    selected=os.readlink(store/'current') if (store/'current').is_symlink() else None
    return {'packages':transaction,'release':{'selected':selected,'state':'selected-not-runtime-accepted' if selected else 'development-checkout','note':'Release updates require a separately reviewed checksummed candidate and activation; this page never switches releases.'},
            'reboot':reboot(),'handoffAvailable':all(shutil.which(n) for n in ('kitty','sudo','pacman')),
            'authentication':'Local sudo authentication plus pacman transaction review in a native terminal; no credentials or package output are recorded.',
            'rollback':'Release rollback restores owned bindings. Preference reset restores only appearance overrides. Package/kernel/system rollback requires native recovery and is separate.'}


def run_terminal():
    if not sys.stdin.isatty() or not sys.stdout.isatty():raise ValueError('Package handoff requires a local interactive terminal')
    if not all(shutil.which(n) for n in ('sudo','pacman')):raise ValueError('sudo/pacman is unavailable')
    safe(STATE);STATE.mkdir(parents=True,exist_ok=True,mode=0o700)
    with safe(STATE/'transaction.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        value={'schema_version':1,'state':'awaiting-confirmation','pid':os.getpid(),'identity':identity(os.getpid()),'startedAt':int(time.time()),'operation':'sudo pacman -Syu'}
        write_json(STATE/'last.json',value)
        print('Official Arch package upgrade: sudo pacman -Syu\nReview the full transaction and authenticate locally. AUR packages and SenomyOS releases are separate.\nNo automatic reboot or package rollback is performed.')
        code=None
        try:
            if input('Type UPGRADE OFFICIAL PACKAGES to proceed: ')!='UPGRADE OFFICIAL PACKAGES':
                value['state']='cancelled';return
            value['state']='running';write_json(STATE/'last.json',value)
            code=subprocess.call(['/usr/bin/sudo','/usr/bin/pacman','-Syu'])
            value['state']='package-tool-succeeded' if code==0 else 'failed'
            print('pacman exit status:',code,'\nReview any .pacnew files, hooks and restart/reboot guidance above. Live service recovery has not been tested.')
        except (KeyboardInterrupt,EOFError):value['state']='interrupted'
        finally:
            value.update(finishedAt=int(time.time()),exitCode=code,reboot=reboot());write_json(STATE/'last.json',value)


def main():
    action=sys.argv[1] if len(sys.argv)==2 else ''
    if action=='read':
        r=subprocess.run([str(ROOT/'scripts/update-status.sh'),'read'],capture_output=True,text=True,timeout=8)
        value=json.loads(r.stdout);value.setdefault('data',{})['maintenance']=status();print(json.dumps(value));return
    if action=='open':
        r=subprocess.run([str(ROOT/'scripts/senomy-app-launch'),'tool','maintenance'],capture_output=True,text=True,timeout=20)
        launch=json.loads(r.stdout)
        print(json.dumps({'ok':bool(r.returncode==0 and launch.get('ok')),'data':{'state':'terminal-requested' if launch.get('ok') else 'failed'},'error':None if launch.get('ok') else {'message':launch.get('message','Terminal handoff failed')}}));return
    if action=='terminal':run_terminal();return
    raise ValueError('Use read, open or terminal; no arbitrary package arguments')

if __name__=='__main__':
    try:main()
    except (ValueError,OSError,subprocess.SubprocessError) as exc:
        print(json.dumps({'ok':False,'error':{'message':str(exc)}}));sys.exit(1)
