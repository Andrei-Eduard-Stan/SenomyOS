#!/usr/bin/env python3
from pathlib import Path
import os,shutil,tempfile,subprocess
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='senomy-telemetry-') as d:
 temp=Path(d);shell=temp/'shell/quickshell';shutil.copytree(root/'shell/quickshell',shell)
 scripts=temp/'scripts';scripts.mkdir();helper=scripts/'performance-status.sh';helper.write_text('#!/usr/bin/env bash\nprintf \'query\\n\' >> "'+str(temp/'inventory-calls')+'"\nprintf \'{"ok":true,"data":{}}\\n\'\n');helper.chmod(0o755)
 (shell/'telemetry-continuity-test.qml').write_text('''import QtQuick
import QtTest
import Quickshell
import "services"
Scope {
 id:test
 SystemMetrics {id:metrics}
 PerformanceService {id:performance;metrics:metrics}
 QtObject {id:fake;property bool ready:true;property real cpuPercent:30;property real memoryPercent:40;property int memoryTotalKib:100;property bool networkReady:true;property real networkRxKib:3;property real networkTxKib:4;property bool temperatureAvailable:false;property real temperatureCelsius:0;property var cores:[];property var frequency:({available:false})}
 TelemetryHistory {id:history;metrics:fake;maximumSamples:900}
 TestCase {id:input;when:false}
 function check(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
 Timer {interval:3200;running:true;onTriggered:{
  test.check(!performance.active && metrics.history.samples.length>=3,"collects while all panels are closed");
  const before=performance.sampleTimes.slice();test.check(before.length>=3,"dashboard consumes background timestamps before first open");
  performance.active=true;input.wait(30);test.check(before.every(at=>performance.sampleTimes.includes(at)),"first open preserves recent closed history");
  performance.active=false;input.wait(1250);test.check(performance.sampleTimes.length>before.length,"history keeps growing after close");
  const closed=performance.sampleTimes.slice();performance.active=true;input.wait(30);test.check(closed.every(at=>performance.sampleTimes.includes(at)),"reopen preserves timeline");performance.active=false;
  const count=metrics.history.samples.length;metrics.lastRefreshAt=Date.now()-60000;input.wait(5);metrics.refresh();
  test.check(metrics.history.samples.length<=count+2,"resume does not fabricate missed samples");
  test.check(metrics.history.samples[metrics.history.samples.length-1].cpu===null,"resume warms a fresh delta rather than drawing an averaged spike");
  for(let i=0;i<1100;i++)history.sample(1000000+i*1000);
  test.check(history.samples.length===900,"bounded ring retains at most 900 samples");
  const end=history.lastSampleAt;test.check(history.window(60,end).length===61,"60-second window uses elapsed timestamps");
  test.check(history.window(300,end).length===301,"five-minute view uses genuine collected samples");
  fake.ready=false;history.sample(end+1000);test.check(history.samples[899].cpu===null,"unavailable CPU is null, never zero");
  const n=history.samples.length;history.sample(end);test.check(history.samples.length===n,"out-of-order clock sample ignored");
  const genuine=metrics.history.samples;
  metrics.history.samples=[{at:metrics.observedAt-1000,cpu:20,ram:30,rx:1,tx:2,temperature:42,frequency:2400,disk:10,cores:[{id:0,percent:12}]},{at:metrics.observedAt,cpu:null,ram:null,rx:null,tx:null,temperature:null,frequency:null,disk:null,cores:[]}];
  test.check(JSON.stringify(performance.frequencyHistory)==="[2.4,null]","frequency history has GHz units and preserves missing samples");
  test.check(JSON.stringify(performance.temperatureHistory)==="[42,null]","temperature history preserves missing sensors");
  test.check(JSON.stringify(performance.diskBusyHistory)==="[10,null]","disk history consumes shared bounded samples");
  test.check(JSON.stringify(performance.coreHistory(0))==="[12,null]","core history preserves missing/hot-unplugged cores");
  metrics.history.samples=genuine;
  console.log("PASS: real procfs sampler collects closed; first open/close/reopen retain history; resume gap, bounded retention and unavailable values");Qt.quit();
 }}
}
''')
 runtime=temp/'runtime';runtime.mkdir(mode=0o700)
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(temp/'config'),XDG_STATE_HOME=str(temp/'state'),SENOMY_SOURCE_ROOT=str(temp))
 for k in ['HYPRLAND_INSTANCE_SIGNATURE','WAYLAND_DISPLAY']:env.pop(k,None)
 r=subprocess.run(['dbus-run-session','--','qs','--path',str(shell/'telemetry-continuity-test.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=12)
 log=r.stdout+r.stderr
 if r.returncode or 'PASS:' not in log or 'TypeError' in log or 'ReferenceError' in log:raise SystemExit(log)
 print(next(line for line in log.splitlines() if 'PASS:' in line))
 calls=(temp/'inventory-calls').read_text().splitlines() if (temp/'inventory-calls').exists() else []
 print('Inventory helper calls:',len(calls),'(only during explicit opens)')
 assert r.returncode==0 and 'PASS:' in log and len(calls)==2
