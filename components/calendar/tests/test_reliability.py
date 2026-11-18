"""Focused local recurrence/alarm regressions; no real calendar or remote calls."""
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sys, tempfile, unittest
from zoneinfo import ZoneInfo
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from senomy_calendar.engine import Engine
from senomy_calendar.reminders import Reminders

class Reliability(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.now=datetime(2026,3,28,tzinfo=timezone.utc).timestamp();self.engine=Engine(self.tmp.name,lambda:self.now);self.rem=Reminders(self.engine)
 def tearDown(self):self.engine.store.db.close();self.tmp.cleanup()
 def event(self,start,end,reminder='60',**extra):
  form=dict(source='personal',title='Fixture',start=start,end=end,timezone='Europe/London',reminder=reminder);form.update(extra);return self.engine.save(form,'save-'+start+reminder)
 def alarm(self):self.rem.reconcile();return dict(self.engine.store.db.execute('SELECT * FROM alarms').fetchone())
 def test_spring_hour_is_elapsed_time(self):
  self.engine.prefs_save({'timezone':'Europe/London'});self.event('2026-03-29T02:30','2026-03-29T03:30');self.assertEqual(self.alarm()['due'],datetime(2026,3,29,0,30,tzinfo=timezone.utc).timestamp())
 def test_autumn_hours_are_elapsed_time(self):
  self.now=datetime(2026,10,24,tzinfo=timezone.utc).timestamp();self.engine.prefs_save({'timezone':'Europe/London'});self.event('2026-10-25T02:30','2026-10-25T03:30','120');self.assertEqual(self.alarm()['due'],datetime(2026,10,25,0,30,tzinfo=timezone.utc).timestamp())
 def test_nominal_day_uses_event_zone_not_view_zone(self):
  self.engine.prefs_save({'timezone':'UTC'});self.event('2026-03-29T09:00','2026-03-29T10:00','1440');self.assertEqual(self.alarm()['due'],datetime(2026,3,28,9,tzinfo=timezone.utc).timestamp())
 def test_reconcile_preserves_existing_alarm_identity_and_delivery(self):
  self.event('2026-03-29T02:30','2026-03-29T03:30');before=self.alarm();self.rem.delivered(before['key'],42,':fixture');self.rem.reconcile();after=dict(self.engine.store.db.execute('SELECT * FROM alarms').fetchone());self.assertEqual(after['key'],before['key']);self.assertEqual(after['status'],'notified');self.assertEqual(after['native_id'],42)
 def test_occurrence_delete_preserves_other_delivery_and_snooze(self):
  saved=self.event('2026-03-29T09:00','2026-03-29T10:00','60',frequency='DAILY',count='3');self.rem.reconcile();alarms=[dict(r) for r in self.engine.store.db.execute('SELECT * FROM alarms ORDER BY due')];self.assertEqual(len(alarms),3)
  self.rem.delivered(alarms[0]['key'],42,':fixture');self.rem.action(alarms[1]['key'],'snooze',10)
  review=self.engine.delete_preview('personal',saved['uid'],alarms[2]['occurrence'],'occurrence');self.engine.delete(review['token']);self.rem.reconcile()
  remaining={r['key']:dict(r) for r in self.engine.store.db.execute('SELECT * FROM alarms')};self.assertEqual(remaining[alarms[0]['key']]['status'],'notified');self.assertEqual(remaining[alarms[1]['key']]['status'],'snoozed');self.assertNotIn(alarms[2]['key'],remaining)

if __name__=='__main__':unittest.main()
