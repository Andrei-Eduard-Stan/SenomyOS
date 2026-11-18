#!/usr/bin/env python3
"""Exercise the production selector using fake commands and a private HOME."""
from pathlib import Path
import json,os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='senomy-notification-selection-') as directory:
    work=Path(directory);commands=work/'bin';commands.mkdir();statefile=work/'providers.json'
    dispatch=r'''import json,os,sys
from pathlib import Path
p=Path(os.environ['SENOMY_SELECTOR_FIXTURE']);s=json.loads(p.read_text());tool=Path(sys.argv[0]).name;a=sys.argv[1:]
def save():p.write_text(json.dumps(s))
def mutate(event):s['mutations'].append(event);save()
if tool=='systemctl':
 a=[x for x in a if x!='--user'];verb=a[0]
 if verb=='cat':print('[Service]');sys.exit(0)
 if verb=='show':
  unit=a[1];field=a[a.index('--property')+1]
  if field=='Environment':print('SENOMY_NOTIFICATION_OWNER=quickshell' if s['configured'] else '')
  elif field=='MainPID':print(300 if unit=='senomy-quickshell.service' and s['qs'] else s['services'].get(unit,0))
  sys.exit(0)
 if verb=='is-active':sys.exit(0 if (s['qs'] if a[-1]=='senomy-quickshell.service' else s['services'].get(a[-1],0)>0) else 3)
 if verb=='mask':
  if s.get('mask_fail'):sys.exit(1)
  mutate(['mask','runtime' if '--runtime' in a else 'persistent',*[x for x in a if x.endswith('.service')]]);sys.exit(0)
 if verb=='stop':
  unit=a[-1];pid=s['services'].get(unit,0);s['services'][unit]=0
  if pid==s['owner']:s['owner']=300 if s['qs'] else 0
  mutate(['stop',unit]);sys.exit(0)
 if verb=='start':s['qs']=True;s['owner']=300;mutate(['start',a[-1]]);sys.exit(0)
 if verb=='reset-failed':mutate(['reset-failed']);sys.exit(0)
 raise SystemExit('Unexpected systemctl operation: '+str(a))
if tool=='busctl':
 if 'GetNameOwner' in a:
  if s['owner']:print('s ":1.fixture"');sys.exit(0)
  sys.exit(1)
 if 'GetConnectionUnixProcessID' in a:print('u '+str(s['owner']));sys.exit(0)
 raise SystemExit('Unexpected bus call')
if tool=='hyprctl':
 if 'layers' in a:print(json.dumps({'fixture':{'levels':{'2':[{'namespace':'senomy-v2-rail'}] if s['qs'] else []}}}))
 elif 'monitors' in a:print('[{"name":"fixture"}]')
 else:raise SystemExit('Unexpected compositor read')
 sys.exit(0)
if tool=='qs':
 if s['ipc']:print('target shell');sys.exit(0)
 sys.exit(1)
raise SystemExit('Unexpected tool')
'''
    for name in ['systemctl','busctl','hyprctl','qs']:
        p=commands/name;p.write_text('#!/usr/bin/env python3\n'+dispatch);p.chmod(0o755)
    env=dict(os.environ,PATH=str(commands)+os.pathsep+os.environ['PATH'],HOME=str(work/'home'),XDG_CONFIG_HOME=str(work/'config'),XDG_RUNTIME_DIR=str(work/'runtime'),SENOMY_SOURCE_ROOT=str(root),SENOMY_QS_BIN=str(commands/'qs'),SENOMY_HYPRCTL_BIN=str(commands/'hyprctl'),SENOMY_BUSCTL_BIN=str(commands/'busctl'),SENOMY_SELECTOR_FIXTURE=str(statefile),WAYLAND_DISPLAY='fixture',HYPRLAND_INSTANCE_SIGNATURE='fixture')
    def run(args,ok=True,**changes):
        state={'qs':True,'ipc':True,'configured':True,'owner':200,'services':{'dunst.service':200,'swaync.service':0},'mutations':[]};state.update(changes);statefile.write_text(json.dumps(state))
        result=subprocess.run(['bash',str(root/'scripts/senomy-shell'),*args],env=env,capture_output=True,text=True,timeout=12)
        assert (result.returncode==0)==ok,(args,result.stdout,result.stderr)
        return json.loads(statefile.read_text())
    s=run(['notifications'],False);assert not s['mutations']
    s=run(['notifications','--confirmed']);assert s['owner']==300 and not s['services']['dunst.service']
    assert s['mutations']==[['mask','persistent','swaync.service','dunst.service'],['stop','dunst.service']]
    for changes in [{'owner':999},{'qs':False},{'ipc':False},{'configured':False},{'mask_fail':True}]:
        s=run(['notifications','--confirmed'],False,**changes);assert not s['mutations']
    s=run(['use','quickshell'],False);assert not s['mutations']
    s=run(['use','quickshell'],qs=False,owner=0,services={});assert s['mutations'][0]==['mask','runtime','swaync.service','dunst.service'];assert s['owner']==300
    s=run(['use','quickshell'],owner=300,services={});assert s['mutations']==[['mask','runtime','swaync.service','dunst.service']]
    s=run(['notifications','--confirmed'],owner=300,services={});assert s['mutations']==[['mask','persistent','swaync.service','dunst.service']]
    print('PASS: confirmed notification handover, unknown-owner/missing-shell/IPC/config/mask refusal, startup protection and idempotence; fake providers only')
