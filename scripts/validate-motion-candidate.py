#!/usr/bin/env python3
"""Bounded isolated motion review; --native maps only inert test windows.

Never starts the shell, a service, a compositor or a notification server. Native
mode uses the existing compositor and may temporarily focus the review window.
"""
from pathlib import Path
import argparse,json,os,re,shutil,subprocess,tempfile,time,resource
p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('out',type=Path);p.add_argument('--native',action='store_true');p.add_argument('--baseline',action='store_true');p.add_argument('--captures',action='store_true');p.add_argument('--screen',type=int,default=0);p.add_argument('--profile',action='store_true');a=p.parse_args()
a.source=a.source.resolve();a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=True)
fixture=Path(__file__).resolve().parents[1]/'shell/quickshell/tests/fixtures/motion-signatures.qml'
with tempfile.TemporaryDirectory(prefix='senomy-motion-review-') as d:
 w=Path(d);s=w/'shell/quickshell';shutil.copytree(a.source,s,symlinks=True)
 for name in ['assets','appearance','scripts']:(w/name).symlink_to(a.source.parents[1]/name,target_is_directory=True)
 code=fixture.read_text()
 if not a.native:
  code=code.replace('PanelWindow {','Window {',1).replace('    screen: reviewScreen','    visible:true\n    width:1920;height:72')
  code=re.sub(r'^    (anchors \{ bottom:.*|implicitHeight: 72|exclusiveZone: 0|WlrLayershell.namespace:.*)\n','',code,flags=re.M)
  h=s/'components/interaction/QuickPopoverWindow.qml';v=h.read_text().replace('PopupWindow {','Window {',1).replace('import Quickshell.Hyprland','')
  v=v.replace('    id: root','    id: root\n    property real implicitWidth:160;property real implicitHeight:100\n    width:implicitWidth;height:implicitHeight\n    property QtObject anchor: QtObject {property var item:null;property int edges:0;property int gravity:0;property int adjustment:0;property QtObject rect:QtObject {property real x:0;property real y:0;property real width:0;property real height:0};function updateAnchor() {}}',1)
  v=re.sub(r'^    (mask: Region.*|grabFocus: false|anchor.adjustment:.*)\n','',v,flags=re.M).replace('HyprlandFocusGrab {','FakeFocusGrab {');h.write_text(v)
  (h.parent/'FakeFocusGrab.qml').write_text('import QtQuick\nItem {property bool active:false;property var windows:[];signal cleared()}\n')
  h=s/'components/lens/CommandLensPopup.qml';h.write_text('\n'.join(line for line in h.read_text().split('\n') if not line.strip().startswith('anchor.')))
  h=s/'components/MachineStateOverlay.qml';v=h.read_text().replace('PanelWindow {','Window {',1)
  v=re.sub(r'^    readonly property var nativeMonitor:.*$', '    readonly property var nativeMonitor:null',v,flags=re.M)
  v=re.sub(r'^    (screen: targetScreen|margins.bottom:.*|exclusiveZone: 0|anchors \{.*|WlrLayershell\..*|mask: Region.*)\n','',v,flags=re.M);v=v.replace('    implicitHeight: fitted.height','    width:targetScreen.width\n    height:fitted.height');h.write_text(v)
  # Native placement declarations belong to the replaced host only.
  code=re.sub(r'        anchor.item:trigger;.*\n','',code)
 env=dict(os.environ,SENOMY_QA_OUT=str(a.out),SENOMY_MOTION_PROFILE="1" if a.profile else "0",SENOMY_QA_SCREEN=str(a.screen),SENOMY_MOTION_BASELINE='1' if a.baseline else '0',SENOMY_MOTION_CAPTURES='1' if a.captures else '0',XDG_CONFIG_HOME=str(w/'config'),XDG_STATE_HOME=str(w/'state'),XDG_DATA_HOME=str(w/'data'))
 if not a.native:
  runtime=w/'runtime';runtime.mkdir(mode=0o700);env.update(QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime))
  for key in ['WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE']:env.pop(key,None)
 else:env.update(QT_QPA_PLATFORM='wayland',QT_QPA_PLATFORMTHEME='',QT_NO_XDG_DESKTOP_PORTAL='1',QT_USE_PORTAL='0')
 (s/'motion-review.qml').write_text(code)
 usageStart=resource.getrusage(resource.RUSAGE_CHILDREN)
 started=time.monotonic();r=subprocess.run(['dbus-run-session','--','qs','-p',str(s/'motion-review.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=70)
 log=r.stdout+r.stderr
 trace=re.search(r'MOTION_TRACE (\{.*\})',log)
 if trace:
  usage=resource.getrusage(resource.RUSAGE_CHILDREN)
  data=json.loads(trace[1]);data.update(cpuSeconds=usage.ru_utime+usage.ru_stime-usageStart.ru_utime-usageStart.ru_stime,processTreeMaxRssKiB=usage.ru_maxrss,native=a.native,baseline=a.baseline,captures=a.captures,wallSeconds=time.monotonic()-started)
  (a.out/'trace.json').write_text(json.dumps(data,indent=2)+'\n')
  log=log.replace(trace[0],'MOTION_TRACE saved to trace.json')
 (a.out/'result.log').write_text(log)
 if r.returncode or 'PASS:' not in log or re.search(r'FAIL:|ERROR|TypeError|ReferenceError|Binding loop|Unable to assign',log):raise SystemExit(log)
 print(next(line for line in log.splitlines() if 'PASS:' in line))
