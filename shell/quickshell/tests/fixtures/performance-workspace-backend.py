#!/usr/bin/env python3
"""Private fixture transport only. Never signal, restart or run a workload."""
from pathlib import Path
import json,os,sys,time
root=Path(os.environ['SENOMY_PERF_FIXTURE']);root.mkdir(exist_ok=True)
name=Path(sys.argv[0]).name;args=sys.argv[1:];prefs=root/'prefs.json';p=json.loads(prefs.read_text()) if prefs.exists() else {'sort':'cpu','filter':'all'}
def emit(data):print(json.dumps({'ok':True,'observed_at':int(time.time()),'data':data}))
def record():
 with (root/'calls.jsonl').open('a') as f:f.write(json.dumps([name,*args])+'\n')
if name=='performance-status.sh':
 emit({'cpu_inventory':{'model':'Fixture 8-thread processor','architecture':'x86_64','logical_cpus':8,'physical_cores':4,'sockets':1,'virtualization':'none','max_mhz':4200},'health':{'hostname':'fixture','kernel':'6.x fixture','temperature':{'available':True,'celsius':51,'source':'Fixture thermal sensor'}},'graphics':{'available':True,'driver':'Fixture graphics','device':'Integrated graphics inventory'},'services':{'available':True,'failed_total':0,'user_state':'running'},'sensors':{'temperatures':[{'source':'Fixture CPU sensor','label':'Package','celsius':51,'critical_celsius':100}]},'storage':{'percent':38,'mount':'/','used_bytes':204010946560,'total_bytes':536870912000,'filesystem':'ext4','source':'/dev/fixture-root','root_device':{'name':'fixture0','logical_sector_bytes':512,'physical_sector_bytes':4096},'devices':[{'name':'fixture0','model':'Fixture NVMe','size_bytes':536870912000,'transport':'nvme','partition_count':3}]},'network':{'interface':'fixture0','state':'up','kind':'ethernet','mtu':1500,'ipv4':'192.0.2.10','ipv6':'2001:db8::10','gateway':'192.0.2.1'},'sockets':{'available':True,'used':72,'udp_in_use':12,'tcp':{'established':7,'listening':10}}})
elif name=='performance-processes.sh':
 if args and args[0] in ['cpu','memory','name']:p['sort']=args[0]
 time.sleep(.12) # In-flight sample exercises stale-view rejection deterministically.
 rows=[{'pid':50000+i,'name':['Editor','Browser','Terminal','Build worker','Media player','File manager'][i%6]+' '+str(i+1),'cpu_percent':round(max(0,24-i*.65),1),'memory_mib':120+i*19,'memory_percent':.5+i*.05,'state':'S','threads':2+i%8,'user':'fixture','rank':i+1} for i in range(36)]
 if p['filter']=='heavy':rows=[row for row in rows if row['cpu_percent']>=10]
 if p['filter']=='active':rows=[row for row in rows if row['cpu_percent']>0]
 rows.sort(key=(lambda row:row['name']) if p['sort']=='name' else (lambda row:-row['memory_mib']) if p['sort']=='memory' else lambda row:-row['cpu_percent'])
 emit({'processes':rows[:int(os.environ.get('SENOMY_PROCESS_LIMIT','512'))],'process_count':36,'thread_count':182,'sort_mode':p['sort'],'filter_mode':p['filter']})
elif name=='performance-process-detail.sh':
 pid=int(args[0]);i=pid-50000
 emit({'pid':pid,'user':'fixture','state':'S','threads':4,'rss_mib':120+i*19,'fd_count':24,'executable':'/fixture/bin/application','cwd':'/fixture/work','command':'Fixture application --safe','start_ticks':str(pid*10),'action_allowed':pid!=50035})
elif name=='performance-action.sh':
 record()
 if args[0] in ['set-sort','set-filter']:p[args[0][4:]]=args[1];prefs.write_text(json.dumps(p))
 elif args[0] not in ['terminate-exact','stop-exact','continue-exact','kill-exact']:raise SystemExit(2)
elif name=='benchmark-action.sh':
 if args[0]=='plan':emit({'estimated_seconds':30 if args[1]=='quick' else 90,'thermal_limit_c':94,'profile':args[1]})
 elif args[0] in ['start','cancel']:
  record();(root/'benchmark.json').write_text(json.dumps({'state':'running' if args[0]=='start' else 'cancelled','state_label':'RUNNING' if args[0]=='start' else 'CANCELLED','progress':12 if args[0]=='start' else 0,'message':'Private inert fixture status. No workload ran.','logs':['Fixture accepted the request.']}))
 else:raise SystemExit(2)
elif name=='benchmark-status.sh':emit(json.loads((root/'benchmark.json').read_text()) if (root/'benchmark.json').exists() else {'state':'idle','state_label':'READY','progress':0,'message':'No workload has been requested.','logs':[]})
else:raise SystemExit('Unsupported private fixture transport')
