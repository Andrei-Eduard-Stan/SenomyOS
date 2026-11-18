#!/usr/bin/env python3
"""Disposable units + private bus/offscreen GUI. NEVER controls the live shell.

Uses the real user manager ONLY for randomly named fixture service/app scopes.
No compositor IPC, physical display, device/provider/account/power operation.
"""
from pathlib import Path
import argparse,json,os,re,shutil,signal,subprocess,sys,tempfile,time,uuid

def main():
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--out',type=Path,required=True);a=p.parse_args();root=a.root.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
 unit='senomy-wp01-test-'+uuid.uuid4().hex+'.service';scopes=set();checks=[];live_before=subprocess.check_output(['systemctl','--user','show','senomy-quickshell.service','-p','MainPID','-p','NRestarts'],text=True)
 def control(verb,target):
  if target!=unit and target not in scopes:raise AssertionError('Unowned unit target rejected')
  assert target!='senomy-quickshell.service'
  return subprocess.run(['systemctl','--user',verb,target],check=True,capture_output=True,text=True,timeout=12)
 def check(ok,label):
  if not ok:raise AssertionError(label)
  checks.append(label);print('PASS:',label,flush=True)
 def wait_json(path,predicate=lambda x:True,seconds=10):
  until=time.monotonic()+seconds
  while time.monotonic()<until:
   try:
    data=json.loads(path.read_text())
    if predicate(data):return data
   except (FileNotFoundError,json.JSONDecodeError):pass
   time.sleep(.05)
  raise AssertionError('Timed out waiting for fixture record '+path.name)
 def alive(pid):
  try:return Path('/proc',str(pid),'stat').read_text().split(') ')[1][0]!='Z'
  except FileNotFoundError:return False
 with tempfile.TemporaryDirectory(prefix='senomy-wp01-fixture-') as directory:
  work=Path(directory);data=work/'data';apps=data/'applications';apps.mkdir(parents=True);config=work/'config';config.mkdir();(work/'cwd').mkdir();(work/'bin').mkdir()
  source=work/'source';qml=source/'shell/quickshell';(qml/'services').mkdir(parents=True);(source/'scripts').mkdir()
  shutil.copy2(root/'shell/quickshell/services/ApplicationLaunch.qml',qml/'services/ApplicationLaunch.qml')
  shutil.copy2(root/'scripts/senomy_app_launch.py',source/'scripts/senomy_app_launch.py')
  shellfile=qml/'shell.qml'
  gui=work/'gui.qml';gui.write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
Window {visible:true;width:160;height:120;title:"Senomy WP01 inert GUI"
 FileView {id:record;path:Quickshell.env("WP01_GUI_RECORD");blockWrites:true}
 Component.onCompleted:record.setText(JSON.stringify({pid:Quickshell.processId,visible:visible}))
}
''')
  # An actual GUI child, with a recorder around it for cwd/argv/UID assertions.
  recorder=work/'app.py';recorder.write_text('''import os,sys,json,subprocess,signal,time
from pathlib import Path
label=os.environ['WP01_APP_LABEL'];base=Path(os.environ['WP01_WORK']);target=base/(label+'-app.json')
args=sys.argv[1:];record={'pid':os.getpid(),'uid':os.getuid(),'euid':os.geteuid(),'gid':os.getgid(),'cwd':os.getcwd(),'argv':args,'cgroup':Path('/proc/self/cgroup').read_text(),'env':{k:os.environ.get(k) for k in ['WP01_SENTINEL','GTK_THEME','LANG','XDG_ACTIVATION_TOKEN','DESKTOP_STARTUP_ID','NOTIFY_SOCKET','INVOCATION_ID']}}
# A unique fixture label is passed as a harmless inherited environment variable.
target.write_text(json.dumps(record));env=dict(os.environ,WP01_GUI_RECORD=str(base/(label+'-gui.json')))
child=subprocess.Popen(['/usr/bin/qs','--path',str(base/'gui.qml'),'--no-color'],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def stop(*_):
 child.terminate();child.wait(timeout=4);sys.exit(0)
signal.signal(signal.SIGTERM,stop)
try:child.wait()
finally:
 if child.poll() is None:stop()
''')
  helper=work/'helper.py';helper.write_text("import os,time,json;from pathlib import Path;Path(os.environ['WP01_WORK']+'/helper.json').write_text(json.dumps({'pid':os.getpid()}));time.sleep(600)")
  desktop='senomy-wp01-fixture.desktop';files=[work/'one file.txt',work/'two-λ.txt']
  for f in files:f.write_text('inert fixture')
  (apps/desktop).write_text('[Desktop Entry]\nType=Application\nName=WP01 fixture\nExec=/usr/bin/python3 '+str(recorder)+' %F %i %c %k\nIcon=fixture-icon\nPath='+str(work/'cwd')+'\nTerminal=false\nMimeType=application/x-senomy-wp01;\n')
  (config/'mimeapps.list').write_text('[Default Applications]\napplication/x-senomy-wp01='+desktop+'\ntext/plain='+desktop+'\n')
  # Query MIME type through gio; the text/plain file association is private.
  env=dict(os.environ,XDG_DATA_HOME=str(data),XDG_DATA_DIRS=str(data),XDG_CONFIG_HOME=str(config),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',WP01_WORK=str(work),WP01_APP_LABEL='exec',WP01_SENTINEL='literal $HOME ; λ',GTK_THEME='WP01-inert-theme',LANG='C.UTF-8',XDG_ACTIVATION_TOKEN='wp01-token',DESKTOP_STARTUP_ID='wp01-startup',PATH=str(work/'bin')+':/usr/bin:/bin')
  for key in ['WAYLAND_DISPLAY','DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','DBUS_SESSION_BUS_ADDRESS','SENOMY_NOTIFICATION_OWNER']:env.pop(key,None)
  dbus_id='org.senomy.WP01Test'+uuid.uuid4().hex;env['WP01_DBUS_ID']=dbus_id
  services=data/'dbus-1/services';services.mkdir(parents=True)
  (services/(dbus_id+'.service')).write_text('[D-BUS Service]\nName='+dbus_id+'\nExec=/usr/bin/python3 '+str(root/'shell/quickshell/tests/fixtures/wp01-dbus-application.py')+'\n')
  (apps/(dbus_id+'.desktop')).write_text('[Desktop Entry]\nType=Application\nName=WP01 private D-Bus GUI\nDBusActivatable=true\nExec=/usr/bin/false\n')
  (apps/'senomy-wp01-broken.desktop').write_text('[Desktop Entry]\nType=Application\nName=Broken fixture\nExec=/definitely-not-installed-wp01\n')
  (apps/'senomy-wp01-terminal.desktop').write_text((apps/desktop).read_text().replace('Terminal=false','Terminal=true'))
  terminal=work/'bin/xdg-terminal-exec'
  terminal.write_text('#!/usr/bin/env python3\nimport os,sys,json\nfrom pathlib import Path\na=sys.argv[1:];i=a.index("/usr/bin/python3");assert a[i+1]=='+repr(str(recorder))+'\nPath(os.environ["WP01_WORK"]+"/terminal.json").write_text(json.dumps(a))\nos.execv(a[i],a[i:])\n');terminal.chmod(0o755)
  kitty=work/'bin/kitty';kitty.write_text('#!/usr/bin/env python3\nimport os\nos.environ["WP01_APP_LABEL"]="tool"\nos.execv("/usr/bin/python3",["/usr/bin/python3",'+repr(str(recorder))+'])\n');kitty.chmod(0o755)
  for name in ['kgx','gnome-terminal','mate-terminal','xfce4-terminal','xterm','rxvt','konsole']:(work/'bin'/name).symlink_to(terminal)
  bus=subprocess.Popen(['dbus-daemon','--session','--nofork','--print-address=1'],env=env,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
  address=bus.stdout.readline().strip();assert address.startswith('unix:');env['DBUS_SESSION_BUS_ADDRESS']=address
  shellfile.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services
Scope {
 id:root;property bool first:true;property string lastId:""
 Services.ApplicationLaunch {id:launcher;onFinished:(accepted,detail)=>reply.setText(JSON.stringify({id:root.lastId,receipt:launcher.receipt}))}
 Process {command:["python3",Quickshell.env("WP01_WORK")+"/helper.py"];running:true}
 FileView {id:reply;path:Quickshell.env("WP01_WORK")+"/reply.json";blockWrites:true}
 FileView {id:request;path:Quickshell.env("WP01_WORK")+"/request.json";watchChanges:true;blockLoading:true;onFileChanged:reload();onLoaded:{const value=JSON.parse(text());if(root.first){root.first=false;root.lastId=value.id;return;}if(value.id!==root.lastId){root.lastId=value.id;launcher.request(value.kind,value.target,value.args||[]);}}}
 Timer {interval:150;running:true;onTriggered:{ready.setText(JSON.stringify({pid:Quickshell.processId}));}}
 FileView {id:ready;path:Quickshell.env("WP01_WORK")+"/shell.json";blockWrites:true}
}
''')
  (work/'request.json').write_text(json.dumps({'id':'initial','kind':'desktop','target':desktop}))
  command=['systemd-run','--user','--quiet','--collect','--unit='+unit,'--description=Senomy WP01 disposable shell fixture','--property=Type=exec','--property=KillMode=control-group','--property=TimeoutStopSec=4s','--property=Restart=on-failure','--property=RestartSec=200ms']
  # Pass only explicitly selected test env, not a user environment dump.
  keys=['XDG_RUNTIME_DIR','XDG_DATA_HOME','XDG_DATA_DIRS','XDG_CONFIG_HOME','DBUS_SESSION_BUS_ADDRESS','QT_QPA_PLATFORM','QT_QUICK_BACKEND','WP01_WORK','WP01_DBUS_ID','WP01_APP_LABEL','WP01_SENTINEL','GTK_THEME','LANG','XDG_ACTIVATION_TOKEN','DESKTOP_STARTUP_ID','PATH']
  command += ['--setenv='+key+'='+env[key] for key in keys if key in env]
  command+=['--setenv=WAYLAND_DISPLAY=','--setenv=DISPLAY=','--setenv=HYPRLAND_INSTANCE_SIGNATURE=','--','/usr/bin/qs','--path',str(shellfile),'--no-color']
  def launch(kind,target,args=()):
   ident=uuid.uuid4().hex;temporary=work/'request.tmp';temporary.write_text(json.dumps({'id':ident,'kind':kind,'target':target,'args':list(args)}));temporary.replace(work/'request.json')
   receipt=wait_json(work/'reply.json',lambda x:x['id']==ident,20)['receipt']
   if 'unit' in receipt:
    assert re.fullmatch(r'app-senomy-[a-f0-9]{32}\.scope',receipt['unit']);scopes.add(receipt['unit'])
   return receipt
  try:
   subprocess.run(command,check=True,capture_output=True,text=True,timeout=10)
   first=wait_json(work/'shell.json');oldhelper=wait_json(work/'helper.json')['pid']
   receipt=launch('desktop',desktop,[str(f) for f in files]);check(receipt.get('ok'),'desktop entry launched through production QML adapter')
   app=wait_json(work/'exec-app.json');gui_record=wait_json(work/'exec-gui.json');check(gui_record['visible'] and alive(gui_record['pid']),'ordinary Qt GUI window created offscreen')
   check(unit not in app['cgroup'] and receipt['unit'] in app['cgroup'],'ordinary GUI application is outside disposable shell cgroup')
   check(app['uid']==os.getuid()==app['euid'] and app['gid']==os.getgid(),'UID/EUID/GID unchanged')
   check(app['cwd']==str(work/'cwd') and app['argv'][:2]==[str(f) for f in files] and app['argv'][2:]==['--icon','fixture-icon','WP01 fixture',str(apps/desktop)],'GIO preserves Path, spaces/Unicode and desktop field codes')
   check(app['env']['WP01_SENTINEL']==env['WP01_SENTINEL'] and app['env']['GTK_THEME']==env['GTK_THEME'] and app['env']['LANG']==env['LANG'],'caller environment retained without manager import or shell expansion')
   (out/'exec-record.json').write_text(json.dumps(app,indent=2)+'\n')
   old_invocation=subprocess.check_output(['systemctl','--user','show',unit,'--property=InvocationID','--value'],text=True).strip()
   check(app['env']['NOTIFY_SOCKET'] is None and app['env']['INVOCATION_ID']!=old_invocation,'parent service notification/invocation identity not leaked (scope may supply its own)')
   check(app['env']['XDG_ACTIVATION_TOKEN']==env['XDG_ACTIVATION_TOKEN'] and app['env']['DESKTOP_STARTUP_ID']==env['DESKTOP_STARTUP_ID'],'supplied activation/startup tokens survive scope and GIO exec launch')
   activation=launch('desktop',dbus_id+'.desktop');check(activation.get('ok'),'private D-Bus activation accepted (Exec fallback is deliberately false)')
   dbusapp=wait_json(work/'dbus-app.json');dbusgui=wait_json(work/'dbus-gui.json')
   check(dbusgui['visible'] and unit not in dbusapp['cgroup'],'D-Bus activated GUI is independent from disposable shell')
   launch('desktop',dbus_id+'.desktop',[str(files[1])]);again=wait_json(work/'dbus-app.json',lambda x:any(e['operation']=='open' for e in x['events']))
   (out/'dbus-record.json').write_text(json.dumps(again,indent=2))
   check(again['pid']==dbusapp['pid'] and again['events'][-1]['uris']==[files[1].as_uri()],'D-Bus Open preserves URI arguments and reuses application instance')
   for cycle in range(3):
    control('restart',unit);new=wait_json(work/'shell.json',lambda x:x['pid']!=first['pid']);wait_json(work/'helper.json',lambda x:x['pid']!=oldhelper)
    check(alive(app['pid']) and alive(gui_record['pid']) and alive(dbusapp['pid']),f'application survives disposable shell restart {cycle+1}')
    check(not alive(oldhelper),f'old shell helper cleaned after restart {cycle+1}')
    first=new;oldhelper=json.loads((work/'helper.json').read_text())['pid']
    time.sleep(.2);check(json.loads((work/'exec-app.json').read_text())['pid']==app['pid'],f'restart {cycle+1} does not replay or duplicate launch')
   # Test a renderer reload by touching only the disposable shell source.
   old=first['pid'];oldhelper=json.loads((work/'helper.json').read_text())['pid'];shellfile.write_text(shellfile.read_text()+'\n// fixture renderer reload\n');time.sleep(1)
   check(alive(app['pid']) and alive(gui_record['pid']),'application survives disposable watched-source reload')
   check(not alive(oldhelper),'renderer reload cleans its previous helper')
   receipt=launch('desktop','senomy-wp01-missing.desktop');check(not receipt['ok'] and bool(receipt.get('message')),'missing desktop entry gives visible bounded failure receipt')
   broken=launch('desktop','senomy-wp01-broken.desktop');check(not broken['ok'] and bool(broken.get('message')),'missing executable gives useful failure without false success')
   old_dbus_count=len(json.loads((work/'dbus-app.json').read_text())['events'])
   launch('desktop',dbus_id+'.desktop');repeated=wait_json(work/'dbus-app.json',lambda x:len(x['events'])>old_dbus_count)
   check(repeated['pid']==dbusapp['pid'] and len(repeated['events'])==old_dbus_count+1,'repeated activation after restart reuses D-Bus application without duplicate instance')
   terminal_receipt=launch('desktop','senomy-wp01-terminal.desktop',[str(files[0])]);check(terminal_receipt.get('ok'),'Terminal=true desktop entry launch accepted by GIO')
   wait_json(work/'terminal.json');terminal_app=wait_json(work/'exec-app.json',lambda x:x['pid']!=app['pid'])
   check(unit not in terminal_app['cgroup'] and terminal_app['argv'][0]==str(files[0]),'native Terminal desktop handling retains independent scope and arguments')
   # Private default association creates one additional explicitly requested app.
   receipt=launch('open',str(files[0]));check(receipt.get('ok'),'private file association launch accepted')
   opened=wait_json(work/'exec-app.json',lambda x:x['pid'] not in (app['pid'],terminal_app['pid']));check(opened['argv'][0]==str(files[0]) and unit not in opened['cgroup'],'default association preserves selected file and independent ownership')
   native=launch('tool','terminal');check(native.get('ok'),'typed native terminal handoff accepted')
   toolapp=wait_json(work/'tool-app.json');toolgui=wait_json(work/'tool-gui.json')
   check(native['unit'] in toolapp['cgroup'] and native['pid']==toolapp['pid'] and toolgui['visible'],'typed tool child enters independent scope with useful PID receipt')
   old_shell=json.loads((work/'shell.json').read_text())['pid'];old_helper=json.loads((work/'helper.json').read_text())['pid']
   assert re.fullmatch(r'senomy-wp01-test-[a-f0-9]{32}\.service',unit)
   subprocess.run(['systemctl','--user','kill','--kill-whom=main','--signal=SIGKILL',unit],capture_output=True,text=True,check=True,timeout=8)
   wait_json(work/'shell.json',lambda x:x['pid']!=old_shell);wait_json(work/'helper.json',lambda x:x['pid']!=old_helper)
   check(alive(app['pid']) and alive(opened['pid']) and alive(dbusapp['pid']) and alive(terminal_app['pid']) and alive(toolapp['pid']),'applications survive disposable shell crash and on-failure restart')
   check(not alive(old_helper),'crash recovery cleans old shell helper')
   # Stop, rather than restart, the fixture shell: all independent GUI apps stay.
   current_helper=json.loads((work/'helper.json').read_text())['pid'];control('stop',unit)
   check(alive(app['pid']) and alive(opened['pid']) and alive(dbusapp['pid']) and alive(terminal_app['pid']) and alive(toolapp['pid']),'applications survive stopping disposable shell service')
   check(not alive(current_helper),'stopping shell cleans final owned helper')
   # All cgroups stopped below are exactly the units created by this fixture.
   (out/'results.json').write_text(json.dumps({'checks':checks,'fixtureUnit':unit,'applicationReceipt':receipt,'environment':'real user manager, disposable random units, private session bus, offscreen Qt; no live shell restart','liveServiceUnchanged':live_before==subprocess.check_output(['systemctl','--user','show','senomy-quickshell.service','-p','MainPID','-p','NRestarts'],text=True)},indent=2)+'\n')
  finally:
   try:control('stop',unit)
   except subprocess.CalledProcessError:pass
   for scope in scopes:
    try:control('stop',scope)
    except subprocess.CalledProcessError:pass
   try:
    owned=json.loads((work/'dbus-app.json').read_text())['pid']
    if str(root/'shell/quickshell/tests/fixtures/wp01-dbus-application.py') in Path('/proc',str(owned),'cmdline').read_bytes().decode(errors='replace'):
     os.kill(owned,signal.SIGTERM)
   except (FileNotFoundError,ProcessLookupError):pass
   bus.terminate();bus.wait(timeout=4);shellfile.unlink(missing_ok=True)
 print('PASS: isolated application survival; live shell/session was not restarted')
if __name__=='__main__':main()
