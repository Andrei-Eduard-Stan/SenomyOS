"""Persistent alarm reconciliation, independent of renderer lifetime."""
from datetime import datetime,timedelta
import hashlib
import secrets
from .engine import parsed,moment,zone,UTC,CalendarError
import recurring_ical_events

def relative_due(value,trigger,tz):
 # RFC 5545 3.3.6: nominal days first in the event's zone, then elapsed
 # hours/minutes/seconds. Negative timedelta.days must not mean -1 day+23h.
 anchor=value if isinstance(value,datetime) and value.tzinfo is not None else moment(value,tz)
 sign=-1 if trigger<timedelta(0) else 1
 span=abs(trigger)
 return (anchor+timedelta(days=sign*span.days)).timestamp()+sign*(span.seconds+span.microseconds/1000000)

class Reminders:
 def __init__(self,engine): self.engine=engine;self.store=engine.store
 def reconcile(self):
  now=self.engine.clock();tz=zone(self.engine.preferences()['timezone']);begin=datetime.fromtimestamp(now,tz)-timedelta(days=7);end=begin+timedelta(days=14);active=set()
  with self.store.db:
   for row in self.store.db.execute("SELECT source,uid,ics FROM events WHERE deleted=0 AND instr(upper(ics),'BEGIN:VALARM')>0").fetchall():
    cal=parsed(row['ics']);pages=recurring_ical_events.of(cal).paginate(501,earliest_end=begin,latest_start=end);page=next(iter(pages),[])
    for event in page:
     start=event.decoded('DTSTART');finish=event.decoded('DTEND',start)
     rid=event.decoded('RECURRENCE-ID',start).isoformat()
     for index,alarm in enumerate(event.walk('VALARM')):
      if str(alarm.get('ACTION',''))!='DISPLAY': continue
      trigger=alarm.decoded('TRIGGER',None)
      if isinstance(trigger,timedelta):
       if abs(trigger.total_seconds())>7*86400: continue
       due=relative_due(finish if str(alarm['TRIGGER'].params.get('RELATED','START'))=='END' else start,trigger,tz)
      elif isinstance(trigger,datetime): due=moment(trigger,tz).timestamp()
      else: continue
      key=hashlib.sha256((row['source']+'|'+row['uid']+'|'+rid+'|'+str(index)+'|'+str(trigger)).encode()).hexdigest();active.add(key)
      self.store.db.execute('INSERT OR IGNORE INTO alarms(key,source,uid,occurrence,title,due,status) VALUES(?,?,?,?,?,?,?)',(key,row['source'],row['uid'],rid,str(event.get('SUMMARY','Event')),due,'missed' if due<now-300 else 'scheduled'))
      self.store.db.execute('UPDATE alarms SET title=? WHERE key=?',(str(event.get('SUMMARY','Event')),key))
      self.store.db.execute("UPDATE alarms SET due=? WHERE key=? AND status='scheduled'",(due,key))
   for row in self.store.db.execute("SELECT key,due,status FROM alarms WHERE status IN ('scheduled','snoozed','notified','delivery-unconfirmed')").fetchall():
    if row['key'] not in active and row['status']!='snoozed': self.store.db.execute("UPDATE alarms SET status='cancelled' WHERE key=?",(row['key'],))
 def due(self):
  return [dict(row) for row in self.store.db.execute("SELECT * FROM alarms WHERE (status='scheduled' AND due<=?) OR (status='snoozed' AND snooze<=?) ORDER BY due LIMIT 20",(self.engine.clock(),self.engine.clock()))]
 def delivery_started(self,key):
  token=secrets.token_hex(12)
  with self.store.db: self.store.db.execute("UPDATE alarms SET status='delivery-unconfirmed',action_token=? WHERE key=?",(token,key))
  return token
 def delivered(self,key,native_id,owner):
  with self.store.db: self.store.db.execute("UPDATE alarms SET status='notified',native_id=?,owner=? WHERE key=?",(native_id,owner,key))
 def failed(self,key):
  with self.store.db: self.store.db.execute("UPDATE alarms SET status='scheduled' WHERE key=?",(key,))
 def action(self,key,action,minutes=10):
  row=self.store.db.execute('SELECT * FROM alarms WHERE key=?',(key,)).fetchone()
  if not row or row['status']=='cancelled': raise CalendarError('Reminder no longer exists.')
  if action=='snooze':
   minutes=int(minutes)
   if not 1<=minutes<=1440: raise CalendarError('Snooze must be 1–1440 minutes.')
   status='snoozed';snooze=self.engine.clock()+minutes*60
  elif action in ['dismiss','acknowledge']: status='dismissed' if action=='dismiss' else 'acknowledged';snooze=0
  else: raise CalendarError('Unknown reminder action.')
  with self.store.transaction(): self.store.db.execute('UPDATE alarms SET status=?,snooze=? WHERE key=?',(status,snooze,key))
  return dict(state=status)
