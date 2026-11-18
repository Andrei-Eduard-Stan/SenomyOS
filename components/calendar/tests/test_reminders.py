import tempfile,unittest,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from senomy_calendar.engine import Engine
from senomy_calendar.reminders import Reminders
class ReminderTest(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.now=1791720000;self.engine=Engine(self.temp.name,lambda:self.now);self.rem=Reminders(self.engine)
 def tearDown(self): self.engine.store.db.close();self.temp.cleanup()
 def test_closed_renderer_snooze_restart_dedup_and_cancel(self):
  from datetime import datetime,timezone,timedelta
  start=datetime.fromtimestamp(self.now+60,timezone.utc)
  form=dict(source='personal',title='Alarm',start=start.replace(tzinfo=None).isoformat(timespec='minutes'),end=(start+timedelta(hours=1)).replace(tzinfo=None).isoformat(timespec='minutes'),timezone='UTC',reminder='1')
  saved=self.engine.save(form,'create');self.rem.reconcile();self.assertEqual(len(self.rem.due()),1)
  key=self.rem.due()[0]['key'];self.rem.delivery_started(key);self.rem.delivered(key,42,':fixture');self.rem.reconcile();self.assertFalse(self.rem.due())
  self.rem.action(key,'snooze',10);self.engine.store.db.close();self.engine=Engine(self.temp.name,lambda:self.now);self.rem=Reminders(self.engine);self.assertFalse(self.rem.due());self.now+=600;self.rem.reconcile();self.assertEqual(len(self.rem.due()),1)
  review=self.engine.delete_preview('personal',saved['uid']);self.engine.delete(review['token']);self.rem.reconcile();self.assertFalse(self.rem.due())
 def test_missed_alarm_and_uncertain_delivery_do_not_duplicate(self):
  from datetime import datetime,timezone,timedelta
  start=datetime.fromtimestamp(self.now-3600,timezone.utc)
  self.engine.save(dict(source='personal',title='Past',start=start.replace(tzinfo=None).isoformat(timespec='minutes'),end=(start+timedelta(hours=1)).replace(tzinfo=None).isoformat(timespec='minutes'),timezone='UTC',reminder='0'),'past')
  self.rem.reconcile();self.assertEqual(self.engine.snapshot()['reminders'][0]['status'],'missed');self.assertFalse(self.rem.due())
if __name__=='__main__': unittest.main()
