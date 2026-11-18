#!/usr/bin/env python3
"""Bounded, read-only shell/desktop resource observations; no process command lines."""
import argparse,datetime,json,os,platform,statistics,subprocess,time
from pathlib import Path

PROC=Path('/proc')

def command(argv):
    try:
        r=subprocess.run(argv,capture_output=True,text=True,timeout=3)
        return r.stdout.strip() if r.returncode==0 else None
    except (OSError,subprocess.TimeoutExpired):return None

def proc_stat(pid,proc=PROC):
    try:
        text=(proc/str(pid)/'stat').read_text()
        fields=text[text.rindex(')')+2:].split()
        status=(proc/str(pid)/'status').read_text().splitlines()
        context={line.split(':',1)[0]:int(line.split(':',1)[1]) for line in status if line.startswith(('voluntary_ctxt_switches:','nonvoluntary_ctxt_switches:'))}
        pss=None
        try:
            for line in (proc/str(pid)/'smaps_rollup').read_text().splitlines():
                if line.startswith('Pss:'):pss=int(line.split()[1]);break
        except (OSError,ValueError):pass
        return {'pid':int(pid),'parent':int(fields[1]),'startTicks':int(fields[19]),'cpuTicks':int(fields[11])+int(fields[12]),'rssKiB':int(fields[21])*os.sysconf('SC_PAGE_SIZE')//1024,'pssKiB':pss,'contextSwitches':sum(context.values()) if len(context)==2 else None}
    except (OSError,ValueError,IndexError):return None

def delta(before,after,seconds,hz):
    if not before or not after or before['pid']!=after['pid'] or before['startTicks']!=after['startTicks'] or seconds<=0:return None
    ticks=after['cpuTicks']-before['cpuTicks']
    if ticks<0:return None
    switches=None if before['contextSwitches'] is None or after['contextSwitches'] is None else after['contextSwitches']-before['contextSwitches']
    return {'cpuPercentOneCore':100*ticks/hz/seconds,'contextSwitchesPerSecond':switches/seconds if switches is not None and switches>=0 else None}

def battery_energy(sysroot=Path('/sys/class/power_supply')):
    values=[]
    try:packs=list(sysroot.iterdir())
    except OSError:return None
    for pack in packs:
        try:
            if (pack/'type').read_text().strip()!='Battery':continue
            if (pack/'status').read_text().strip()!='Discharging':return None
            if (pack/'energy_now').is_file():energy=int((pack/'energy_now').read_text())/1000000
            else:
                energy=int((pack/'charge_now').read_text())*int((pack/'voltage_now').read_text())/1000000000000
            values.append(energy)
        except (OSError,ValueError):return None
    return sum(values) if values else None

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds',type=int,default=60)
    parser.add_argument('--interval',type=float,default=2)
    parser.add_argument('--pid',type=int,help='Explicit shell PID; otherwise query the user service')
    parser.add_argument('--label',choices=['idle','settings','performance','insights','animation','custom'],default='custom')
    args=parser.parse_args()
    if not 5<=args.seconds<=3600 or not 0.5<=args.interval<=30:parser.error('Use 5..3600 seconds and 0.5..30 second intervals')
    shell=args.pid
    if shell is None:
        value=command(['systemctl','--user','show','senomy-quickshell.service','--property=MainPID','--value'])
        shell=int(value) if value and value.isdigit() else 0
    if shell<=0 or not proc_stat(shell):parser.error('Shell PID is unavailable; specify a live --pid')
    targets={'shell':shell}
    signature=os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
    try:
        for item in json.loads(command(['hyprctl','instances','-j']) or '[]'):
            if item.get('instance')==signature and int(item.get('pid',0))>0:targets['compositor']=int(item['pid'])
    except (ValueError,TypeError):pass
    displays=[]
    try:
        for m in json.loads(command(['hyprctl','monitors','-j']) or '[]'):
            displays.append({k:m.get(k) for k in ('width','height','refreshRate','scale','transform')})
    except (ValueError,TypeError):pass
    hz=os.sysconf('SC_CLK_TCK');start=time.monotonic();end=start+args.seconds
    previous={};samples=[];energy_start=battery_energy();previous_at=start;power_samples=[]
    while True:
        now=time.monotonic();row={'elapsedSeconds':round(now-start,3),'processes':{}}
        for role,pid in targets.items():
            current=proc_stat(pid)
            change=delta(previous.get(role),current,now-previous_at,hz)
            row['processes'][role]={'available':current is not None,'pid':pid,'rssKiB':current['rssKiB'] if current else None,'pssKiB':current['pssKiB'] if current else None,'interval':change}
            if current:previous[role]=current
            else:previous.pop(role,None)
        power_samples.append(battery_energy());samples.append(row);previous_at=now
        if now>=end:break
        time.sleep(min(args.interval,max(0,end-time.monotonic())))
    elapsed=samples[-1]['elapsedSeconds'];energy_end=battery_energy()
    watts=(energy_start-energy_end)*3600/elapsed if elapsed and energy_start is not None and energy_end is not None and energy_start>=energy_end and all(e is not None for e in power_samples) else None
    summary={}
    for role in targets:
        intervals=[(s['processes'][role]['interval'],s['elapsedSeconds']-samples[i-1]['elapsedSeconds']) for i,s in enumerate(samples) if i>0 and s['processes'][role]['interval'] is not None]
        valid_seconds=sum(dt for _,dt in intervals)
        cpu=sum(d['cpuPercentOneCore']*dt for d,dt in intervals)/valid_seconds if valid_seconds else None
        pss=[s['processes'][role]['pssKiB'] for s in samples if s['processes'][role]['pssKiB'] is not None]
        summary[role]={'cpuPercentOneCore':cpu,'observedIntervalSeconds':valid_seconds,'pssKiBMedian':statistics.median(pss) if pss else None,'pssKiBPeak':max(pss) if pss else None,'presentInAllSamples':all(s['processes'][role]['available'] for s in samples)}
    result={'schema_version':1,'observedAt':datetime.datetime.now().astimezone().isoformat(),'label':args.label,'durationSeconds':elapsed,'kernel':platform.release(),'logicalCpus':os.cpu_count(),'displays':displays,'summary':summary,'samples':samples,'wholeMachineDischargeWatts':watts,'limits':['Selected shell/compositor PIDs only; child helpers and other desktop services are not included.','Context switches are not hardware wakeups.','Discharge is whole-machine energy change, not shell attribution; short runs are coarse and invalid if any sample cannot verify discharge.','GPU timing, input latency, cold boot and suspend acceptance require separate measurements.','PID replacement invalidates its delta; a service restart is not followed automatically.']}
    print(json.dumps(result,separators=(',',':')))
if __name__=='__main__':main()
