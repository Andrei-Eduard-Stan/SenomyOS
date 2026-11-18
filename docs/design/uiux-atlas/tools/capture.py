#!/usr/bin/env python3
"""Offscreen atlas capture. Never opens the shell or attaches to the host bus.

Uses production QML and existing inert fixtures. Changes only temporary copies.
Run from any directory. All output stays in this atlas folder.
"""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, sys, tempfile

ATLAS = Path(__file__).resolve().parents[1]
ROOT = ATLAS.parents[2]
SOURCE = ROOT / 'shell/quickshell'
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'scripts'))
from qa_remaining_hosts import prepare_hosts
from qa_directory_host import directory_host


def isolated_env(work, out):
    runtime = work / 'runtime'
    runtime.mkdir(mode=0o700, exist_ok=True)
    env = {k: v for k, v in os.environ.items() if k not in (
        'DISPLAY', 'WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE',
        'DBUS_SESSION_BUS_ADDRESS')}
    fonts = work / 'fonts.conf'
    fonts.write_text('<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd"><fontconfig><include>/etc/fonts/fonts.conf</include><dir>' + str(ROOT/'appearance/shared/fonts') + '</dir><dir>' + str(Path.home()/'.local/share/fonts') + '</dir><cachedir>' + str(work/'font-cache') + '</cachedir></fontconfig>')
    env.update(QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               XDG_RUNTIME_DIR=str(runtime), XDG_STATE_HOME=str(work/'state'),
               XDG_CONFIG_HOME=str(work/'config'), XDG_DATA_HOME=str(work/'data'),
               SENOMY_QA_OUT=str(out), SENOMY_DISPLAY_QA_DIR=str(out),
               SENOMY_SOURCE_ROOT=str(work/'inert-providers'),
               SENOMY_NOTIFICATION_OWNER='none', FONTCONFIG_FILE=str(fonts),
               PYTHONDONTWRITEBYTECODE='1')
    return env


def run_qml(work, shell, name, text, out, timeout=55):
    out.mkdir(parents=True, exist_ok=True)
    path = shell / ('atlas-' + name + '.qml')
    path.write_text(text)
    result = subprocess.run(['dbus-run-session', '--', 'qs', '--path', str(path), '--no-color'],
                            env=isolated_env(work, out), capture_output=True, text=True, timeout=timeout)
    log = result.stdout + result.stderr
    (out / 'capture.log').write_text(log)
    errors = [s for s in log.splitlines() if re.search(r'ERROR|FAIL:|ReferenceError|TypeError|Binding loop', s)]
    pngs = list(out.glob('*.png'))
    status = dict(job=name, returncode=result.returncode, captures=len(pngs), errors=errors[:12])
    print(json.dumps(status), flush=True)
    return status


def prepared(work):
    return prepare_hosts(SOURCE, work)


def prefix(name):
    text = (SOURCE / 'tests/fixtures' / (name + '.qml')).read_text()
    return text[:text.index('    Timer {' if '    Timer {' in text else ' Timer {')]


def control(out):
    with tempfile.TemporaryDirectory(prefix='senomy-atlas-control-') as d:
        work = Path(d); shell = prepared(work)
        text = prefix('control-directory')
        # Fewer dynamic demo items improve inspection while retaining real lists.
        text = text.replace('length:24', 'length:5').replace('length:16', 'length:3')
        text = text.replace('connectionAttempt:{message:', 'profiles:{busy:false,error:"",status:{devices:[],connectivity:"unavailable"},items:[],actions:actions},connectionAttempt:{message:')
        text = text.replace('battery: ({batteries:', 'battery: ({care:{snapshot:{},packs:[],actionState:"idle",persistentChoice:false,locked:false,busy:false,fresh:false,installed:false,message:"Care provider unavailable in this fixture"},batteries:')
        # Use the current inert Bluetooth model instead of an obsolete object schema.
        text = text.replace('    ControlCentre {', '    BluetoothService {id:fixtureBluetooth;transportEnabled:false;actionContext:"atlas"}\n    ControlCentre {')
        text = re.sub(r'        bluetooth: \(\{[^\n]+\}\)', '        bluetooth: fixtureBluetooth', text)
        text += '''
    Timer {interval:400;running:true;onTriggered:{
      const entries=Directory.all(panel.navigationNodes).filter(n=>!n.dynamic);
      console.log("ATLAS_ROUTES:"+JSON.stringify(entries.map(n=>({id:n.id,label:n.label,path:n.path,target:n.target,route:n.route}))));
      state.controlMode="full";
      for(const node of entries){
        panel.deferredNode="";state.controlDraftDirty=false;
        state.controlSection=node.route;state.controlPath=node.id===node.route?"":node.id;
        input.wait(100);test.capture("settings-"+node.id.replace(/\\//g,"-"),panel);
      }
      state.controlPath="";state.controlSection="overview";state.controlMode="compact";input.wait(100);test.capture("control-overview",panel);
      state.controlMode="full";
      for(const route of ["overview","network/wifi","audio/mixer","power/batteries","input/methods","appearance/motion","accounts"]){
        test.width=390;test.height=740;state.controlSection=route.split("/")[0];state.controlPath=route;input.wait(100);test.capture("narrow-"+route.replace(/\\//g,"-"),panel);
      }
      test.width=1120;test.height=820;state.controlSection="overview";state.controlPath="";input.wait(60);
      panel.navigation.query="wallpaper";input.wait(80);test.capture("search-results",panel);
      panel.navigation.query="no-atlas-result";input.wait(80);test.capture("search-empty",panel);
      panel.navigation.query="";state.controlSection="appearance";state.controlPath="appearance/backgrounds";input.wait(100);
      const field=input.findChild(panel.contentArea,"backgroundSource");if(field){field.forceActiveFocus();input.keyClick(Qt.Key_A);input.wait(40);panel.navigateId("settings/idle");input.wait(80);test.capture("unsaved-review",panel);}
      console.log("ATLAS_DONE");Qt.quit();
    }}
}
'''
        status = run_qml(work, shell, 'control', text, out)
        log = (out/'capture.log').read_text()
        m = re.search(r'ATLAS_ROUTES:(\[.*\])', log)
        if m: (ATLAS/'routes.json').write_text(json.dumps(json.loads(m[1]), indent=2)+'\n')
        return status


def directories(out):
    statuses=[]
    for name in ['directory-performance','directory-insights']:
      with tempfile.TemporaryDirectory(prefix='senomy-atlas-directory-') as d:
        work=Path(d);shell=work/'shell/quickshell';shutil.copytree(SOURCE,shell,symlinks=True)
        for n in ['assets','appearance']:(work/n).symlink_to(ROOT/n,target_is_directory=True)
        (shell/'components/DirectorySurfaceWindow.qml').write_text(directory_host(SOURCE))
        text=prefix(name)
        if name=='directory-insights':
            text=text.replace('notifications:({history:', 'notifications:({sessionService:{busy:false,hasSchedule:false,schedule:{},state:"idle"},history:')
        if name=='directory-performance':
            body='''
        for(const section of panel.sections){state.performanceSection=section.id;input.wait(120);let done=false;panel.captureItem.grabToImage(r=>{r.saveToFile(test.out+"/performance-"+section.id+".png");done=true;});while(!done)input.wait(10);}
        state.performanceSection="processes";input.wait(100);performance.requestProcessTermination();input.wait(100);let done=false;panel.captureItem.grabToImage(r=>{r.saveToFile(test.out+"/process-review.png");done=true;});while(!done)input.wait(10);performance.cancelProcessAction();
        test.width=390;test.height=740;state.performanceSection="cpu";input.wait(100);done=false;panel.captureItem.grabToImage(r=>{r.saveToFile(test.out+"/performance-cpu-narrow.png");done=true;});while(!done)input.wait(10);
'''
        else:
            body='''
        insights.active=true;test.finishQueries();
        for(const section of panel.sections){state.insightsSection=section.id;test.finishQueries();input.wait(120);let done=false;panel.captureItem.grabToImage(r=>{r.saveToFile(test.out+"/insights-"+section.id+".png");done=true;});while(!done)input.wait(10);}
        state.insightsSection="briefing";test.finishQueries();test.width=390;test.height=740;input.wait(100);let done=false;panel.captureItem.grabToImage(r=>{r.saveToFile(test.out+"/insights-briefing-narrow.png");done=true;});while(!done)input.wait(10);
'''
        text+='\n Timer {interval:400;running:true;onTriggered:{'+body+'console.log("ATLAS_DONE");Qt.quit();}}\n}\n'
        statuses.append(run_qml(work,shell,name,text,out/name))
    return statuses


def simple(out, name, hosting=True):
    with tempfile.TemporaryDirectory(prefix='senomy-atlas-'+name+'-') as d:
        work=Path(d)
        if hosting:shell=prepared(work)
        else:
            shell=work/'shell/quickshell';shutil.copytree(SOURCE,shell,symlinks=True)
            for n in ['assets','appearance']:(work/n).symlink_to(ROOT/n,target_is_directory=True)
        text=(SOURCE/'tests/fixtures'/f'{name}.qml').read_text()
        if name=='remaining-popup':
            text=prefix(name)+'''
 Timer {interval:400;running:true;onTriggered:{
  for(const route of ["notifications","toast","calendar","tray"]){
   test.route=route;test.width=470;test.height=route==="calendar"?520:route==="toast"?320:610;input.wait(180);test.capture(route+"-470");
   if(route==="notifications"){notificationProvider.dnd=true;input.wait(80);test.capture("notifications-dnd");notificationProvider.dnd=false;clearGuard.actionState="pending";input.wait(80);test.capture("archive-review");clearGuard.actionState="idle";}
  }
  console.log("ATLAS_DONE");Qt.quit();
 }}
}
'''
            text=text.replace('property bool serverEnabled:true','property var sessionService:({busy:false,hasSchedule:false,schedule:{},state:"idle"})\n  property bool serverEnabled:true')
            text=text.replace('placementEnabled:true;shown:true;toastShown:true','placementEnabled:true;presentedNotification:notificationProvider.latest;shown:true;toastShown:true')
        return run_qml(work,shell,name,text,out)


def external_preview(out, script, args=(), extra=None):
    out.mkdir(parents=True,exist_ok=True)
    env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1')
    if extra:env.update(extra)
    r=subprocess.run([sys.executable,'-B',str(ROOT/'scripts'/script),*map(str,args)],env=env,capture_output=True,text=True,timeout=55)
    (out/'driver.log').write_text(r.stdout+r.stderr)
    status=dict(job=script,returncode=r.returncode,captures=len(list(out.glob('*.png'))),errors=(r.stdout+r.stderr)[-1800:] if r.returncode else [])
    print(json.dumps(status),flush=True);return status


def special(out, name):
    with tempfile.TemporaryDirectory(prefix='senomy-atlas-'+name+'-') as d:
        work=Path(d)
        if name in ['audio-quick-quality','calendar-quick-quality','tray-quick-quality','session-popup-quality','session-surfaces-quality']:
            shell=prepared(work)
            component={'audio-quick-quality':'VolumePopup','calendar-quick-quality':'CalendarPopup','tray-quick-quality':'TrayPopup','session-popup-quality':'PowerPopup','session-surfaces-quality':'PowerPopup'}[name]
            actual=(SOURCE/f'components/{component}.qml').read_text()
            sizes='\n'.join(line for line in actual.splitlines() if line.strip().startswith(('implicitWidth:','implicitHeight:')))
            p=shell/f'components/{component}.qml';p.write_text(p.read_text().replace('    FocusScope {\n        id: card',sizes+'\n    FocusScope {\n        id: card'))
        else:
            shell=work/'shell/quickshell';shutil.copytree(SOURCE,shell,symlinks=True)
            for n in ['assets','appearance']:(work/n).symlink_to(ROOT/n,target_is_directory=True)
        if name=='bluetooth-quality':
            p=shell/'components/BluetoothPopup.qml';text=p.read_text().replace('Interaction.QuickPopoverWindow {','FocusScope {',1).replace('    id:root','''    id:root
    property var targetScreen:({width:1920,height:1080})
    property bool cardShown:true
    property bool requestedOpen:visible
    property var focusTarget
    property bool keyboardPriority
    function handleEscape(){dismissRequested();}
    function dismiss(){dismissRequested();}
    signal dismissRequested()''',1).replace('    color:"transparent"','    property color color:"transparent"')
            p.write_text('\n'.join(line for line in text.splitlines() if not line.strip().startswith('anchor.')))
        text=(SOURCE/'tests/fixtures'/f'{name}.qml').read_text()
        return run_qml(work,shell,name,text,out)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--jobs',nargs='*');args=parser.parse_args()
    jobs=args.jobs or ['control','directories','controls','popups','audio','calendar-quick','tray','session','session-popup','session-surfaces','bluetooth','lens','display','auth','calendar']
    statuses=[]
    for job in jobs:
      out=ATLAS/'screenshots/full'/job
      try:
        if job=='control':r=control(out)
        elif job=='directories':r=directories(out)
        elif job=='controls':r=simple(out,'remaining-controls')
        elif job=='popups':r=simple(out,'remaining-popup')
        elif job in ['audio','calendar-quick','tray','session','session-popup','session-surfaces','bluetooth']:
            name={'audio':'audio-quick-quality','calendar-quick':'calendar-quick-quality','tray':'tray-quick-quality','session':'session-quality','session-popup':'session-popup-quality','session-surfaces':'session-surfaces-quality','bluetooth':'bluetooth-quality'}[job]
            r=special(out,name)
        elif job=='lens':
            from capture_extra import lens
            r=lens()
        elif job=='display':r=external_preview(out,'validate-display-ui.py',extra={'SENOMY_DISPLAY_QA_DIR':str(out)})
        elif job=='auth':r=external_preview(out,'preview-auth-surfaces.py',[out])
        elif job=='calendar':r=calendar(out)
        else:raise ValueError(job)
        statuses.extend(r if isinstance(r,list) else [r])
      except Exception as e:
        statuses.append(dict(job=job,error=str(e)));print(json.dumps(statuses[-1]),flush=True)
    path=ATLAS/'capture-results.json'
    previous=json.loads(path.read_text()) if path.exists() else []
    names={r.get('job') for r in statuses};previous=[r for r in previous if r.get('job') not in names]
    path.write_text(json.dumps(previous+statuses,indent=2)+'\n')


def calendar(out):
    """Only a private calendar database and private daemon, never user's records."""
    with tempfile.TemporaryDirectory(prefix='senomy-atlas-calendar-') as d:
        work=Path(d);shell=work/'shell/quickshell';shutil.copytree(SOURCE,shell,symlinks=True)
        for n in ['assets','appearance']:(work/n).symlink_to(ROOT/n,target_is_directory=True)
        out.mkdir(parents=True,exist_ok=True)
        fixture=shell/'atlas-calendar.qml';fixture.write_text((SOURCE/'tests/fixtures/calendar-organizer.qml').read_text())
        env=isolated_env(work,out);env['PYTHONPATH']=str(ROOT/'components/calendar')
        python=Path.home()/'.local/share/senomyos/calendar/runtime/bin/python'
        harness=work/'harness.py'
        harness.write_text('''import subprocess,sys,time,os,pathlib
p=subprocess.Popen([sys.argv[1],'-m','senomy_calendar.daemon','--runtime',os.environ['XDG_RUNTIME_DIR']+'/senomyos-calendar'],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
try:
 for i in range(100):
  if pathlib.Path(os.environ['XDG_RUNTIME_DIR']+'/senomyos-calendar/calendar.sock').exists():break
  time.sleep(.02)
 r=subprocess.run(['qs','--path',sys.argv[2],'--no-color'],capture_output=True,text=True,timeout=45)
 print(r.stdout+r.stderr);sys.exit(r.returncode)
finally:
 p.terminate();p.wait(timeout=5)
''')
        r=subprocess.run(['dbus-run-session','--',sys.executable,str(harness),str(python),str(fixture)],env=env,capture_output=True,text=True,timeout=52)
        (out/'capture.log').write_text(r.stdout+r.stderr)
        status=dict(job='calendar',returncode=r.returncode,captures=len(list(out.glob('*.png'))),errors=(r.stdout+r.stderr)[-1800:] if r.returncode else [])
        print(json.dumps(status),flush=True);return status

if __name__=='__main__':main()
