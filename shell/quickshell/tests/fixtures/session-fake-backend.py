"""Inert transport fixture. Never dispatches commands or creates systemd units."""
import json,os,sys,time
from datetime import datetime
from pathlib import Path
root=Path(os.environ['XDG_RUNTIME_DIR'])/'senomyos';root.mkdir(parents=True,exist_ok=True)
path=root/'session-schedule.json';review_path=root/'fake-review.json'
record=json.loads(path.read_text()) if path.exists() else {}
operation=sys.argv[1]
with (root/'calls.jsonl').open('a') as log:log.write(json.dumps(sys.argv[1:])+'\n')
result={'ok':True}
def save():
 temporary=path.with_suffix('.tmp');temporary.write_text(json.dumps(record));temporary.replace(path)
if operation=='status':result.update(schedule=record,capabilities={key:True for key in ['lock','suspend','logout','reboot','poweroff']},schedulingAvailable=True,reason='')
elif operation=='prepare':
 form=json.loads(sys.argv[2])
 if form.get('mode')=='delay' and form.get('seconds')=='0':result={'ok':False,'error':'Invalid countdown.','fieldErrors':{'seconds':'Use a positive countdown.'}}
 else:
  now=time.time();due=now+int(form.get('seconds','1800'))
  if form['mode']=='at':due=datetime.fromisoformat(form['date']+'T'+form['time']).astimezone().timestamp()
  label='Now' if form['mode']=='now' else datetime.fromtimestamp(due).astimezone().strftime('%a %d %b, %H:%M:%S %Z (%z)')
  review={'id':'private-review','action':form['action'],'label':{'lock':'Lock','poweroff':'Shut down','reboot':'Restart','suspend':'Sleep','logout':'Log out'}[form['action']],'mode':form['mode'],'dueEpoch':due,'dueLabel':label,'form':form,'replaces':record.get('label','') if record.get('state')=='scheduled' and form['mode']!='now' else ''}
  review_path.write_text(json.dumps(review));result['review']=review
elif operation=='commit':
 review=json.loads(review_path.read_text());assert sys.argv[2]==review['id']
 if review['mode']!='now':
  record=dict(review,state='scheduled',remainingSeconds=int(review['form'].get('seconds','1800')) if review['mode']=='delay' else review['dueEpoch']-time.time(),progress=1,urgency='normal',createdEpoch=time.time(),durationSeconds=review['dueEpoch']-time.time());save();result['schedule']=record
 elif review['form'].get('executeId'):record['state']='succeeded';save();result['schedule']=record
 result['message']='Private request accepted.'
elif operation=='cancel':
 assert record['id']==sys.argv[2];record['state']='cancelled';save();result['schedule']=record;result['message']='Private cancellation accepted.'
elif operation=='postpone':
 req=json.loads(sys.argv[2]);assert req['id']==record['id'];record['remainingSeconds']+=req['seconds'];record['dueEpoch']+=req['seconds'];record['dueLabel']=datetime.fromtimestamp(record['dueEpoch']).astimezone().strftime('%a %d %b, %H:%M:%S %Z (%z)');save();result['schedule']=record
else:result={'ok':False,'error':'Unsupported fixture operation.'}
print(json.dumps(result));sys.exit(0 if result['ok'] else 1)
