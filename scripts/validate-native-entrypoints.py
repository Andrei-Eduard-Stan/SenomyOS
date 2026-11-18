#!/usr/bin/env python3
"""Mocked entry-point, retirement and screenshot lifecycle integration."""
from pathlib import Path
import json,os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]

def executable(path,source):
    path.write_text('#!/usr/bin/env python3\n'+source);path.chmod(0o755);return str(path)
with tempfile.TemporaryDirectory(prefix='senomy-entrypoints-') as directory:
    temp=Path(directory);commands=temp/'bin';commands.mkdir()
    log=temp/'ipc.json'
    executable(commands/'pgrep','import os,sys\nsys.exit(0 if os.environ.get("SENOMY_TEST_SHELL","1")=="1" else 1)\n')
    qs=executable(commands/'qs','import json,os,sys\nfrom pathlib import Path\np=Path(os.environ["SENOMY_TEST_IPC_LOG"]);calls=json.loads(p.read_text()) if p.exists() else [];calls.append(sys.argv[1:]);p.write_text(json.dumps(calls));print(os.environ.get("SENOMY_TEST_IPC_REPLY","settings"))\n')
    hypr=executable(commands/'hyprctl','import json\nprint(json.dumps([{"name":"fixture output","focused":True}]))\n')
    env=dict(os.environ,PATH=str(commands)+os.pathsep+os.environ['PATH'],HOME=str(temp/'home'),XDG_CONFIG_HOME=str(temp/'config'),XDG_DATA_HOME=str(temp/'data'),XDG_STATE_HOME=str(temp/'state'),XDG_RUNTIME_DIR=str(temp/'runtime'),SENOMY_TEST_IPC_LOG=str(log),SENOMY_QS_BIN=qs,SENOMY_HYPRCTL_BIN=hypr)
    def run(script,args=(),ok=True,extra=None):
        result=subprocess.run([str(root/script),*args],env=dict(env,**(extra or {})),capture_output=True,text=True,timeout=10)
        assert (result.returncode==0)==ok,(script,args,result.stdout,result.stderr)
        return result
    run('scripts/senomy-surface',['dismiss'])
    assert json.loads(log.read_text())[-1][-1]=='escapeExternal'
    log.unlink()
    run('scripts/senomy-surface',['show-settings','network/wifi'])
    assert json.loads(log.read_text())[-1][-3:]==['settings','fixture output','network/wifi']
    before=log.read_text()
    run('scripts/senomy-surface',['show-settings','network/$(bad)'],False);assert log.read_text()==before
    run('scripts/senomy-surface',['show-settings'],False,{'SENOMY_TEST_IPC_REPLY':'rejected'})
    run('scripts/senomy-surface',['show-settings'],False,{'SENOMY_TEST_SHELL':'0'});assert len(json.loads(log.read_text()))==2
    sentinel=temp/'runtime-file';sentinel.write_text('sentinel')
    run('scripts/senomy-shell',['use','unsupported'],False,{'XDG_RUNTIME_DIR':str(sentinel)});assert sentinel.read_text()=='sentinel'
    # Deployment only operates on this private home and mocked user manager.
    executable(commands/'systemctl','import sys\nsys.exit(3 if "is-active" in sys.argv else 0)\n')
    run('scripts/senomy-v2-deploy',['apply']);run('scripts/senomy-v2-deploy',['check'])
    assert (temp/'data/applications/senomy-settings.desktop').is_symlink()
    other=temp/'unmanaged';other.mkdir();target=other/'bin/senomy-shell';target.parent.mkdir();target.write_text('user-owned')
    run('scripts/senomy-v2-deploy',['apply'],False,{'XDG_BIN_HOME':str(other/'bin'),'XDG_CONFIG_HOME':str(other/'config')})
    assert target.read_text()=='user-owned' and not (other/'config/systemd/user/senomy-quickshell.service').exists()
    # Flameshot appears after freezing its screenshot. Only then may shell
    # input pause, and exactly the same token must be used to restore it.
    log.unlink()
    counter=temp/'capture-count'
    hypr=executable(commands/'capture-hyprctl','import json,os\nfrom pathlib import Path\np=Path(os.environ["SENOMY_TEST_CAPTURE_COUNT"]);n=int(p.read_text()) if p.exists() else 0;p.write_text(str(n+1));print(json.dumps([{"class":"flameshot","initialTitle":"flameshot"}] if n==1 else []))\n')
    executable(commands/'flameshot','import sys\nsys.exit(0)\n')
    executable(commands/'qs','import json,os,sys\nfrom pathlib import Path\np=Path(os.environ["SENOMY_TEST_IPC_LOG"]);calls=json.loads(p.read_text()) if p.exists() else [];calls.append(sys.argv[1:]);p.write_text(json.dumps(calls));print("paused" if "captureSuspend" in sys.argv else "restored")\n')
    run('scripts/senomy-screenshot',['capture'],True,{'SENOMY_TEST_CAPTURE_COUNT':str(counter),'SENOMY_HYPRCTL_BIN':hypr,'SENOMY_FLAMESHOT_BIN':str(commands/'flameshot'),'SENOMY_SYSTEMCTL_BIN':str(commands/'systemctl'),'SENOMY_SCREENSHOT_FREEZE_SECONDS':'0'})
    calls=json.loads(log.read_text());assert len(calls)==2 and calls[0][-2]=='captureSuspend' and calls[1][-2]=='captureResume' and calls[0][-1]==calls[1][-1]
print('PASS: literal deep links, rejection/no-shell behavior, private deployment, unmanaged-file refusal and capture pause/restore tokens')
