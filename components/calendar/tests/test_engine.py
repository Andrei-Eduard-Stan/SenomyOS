import unittest,tempfile,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from senomy_calendar.engine import Engine,CalendarError

class EngineTest(unittest.TestCase):
 def setUp(self): self.temp=tempfile.TemporaryDirectory();self.engine=Engine(self.temp.name)
 def tearDown(self): self.engine.store.db.close();self.temp.cleanup()
 def form(self,**kw): return dict(source='personal',title='Meeting',start='2026-10-11T14:00',end='2026-10-11T15:00',timezone='Europe/London',frequency='NONE',**kw)
 def save(self,form=None,key='first'): return self.engine.save(form or self.form(),key)
 def test_crud_restart_idempotence_and_revision(self):
  saved=self.save();self.assertEqual(saved,self.save());self.assertEqual(self.engine.snapshot()['eventCount'],1)
  uid=saved['uid'];self.engine.store.db.close();self.engine=Engine(self.temp.name)
  detail=self.engine.detail('personal',uid);self.assertEqual(detail['title'],'Meeting');detail['title']='Changed'
  self.engine.save(detail,'changed')
  with self.assertRaises(CalendarError): self.engine.save(detail,'stale')
  review=self.engine.delete_preview('personal',uid);self.assertEqual(self.engine.snapshot()['eventCount'],1)
  self.engine.delete(review['token']);self.assertEqual(self.engine.snapshot()['eventCount'],0)
 def test_recurrence_dst_exclusion_and_override(self):
  form=self.form();form.update(start='2026-10-18T09:00',end='2026-10-18T10:00',frequency='WEEKLY',count='3')
  saved=self.save(form);items=self.engine.query('2026-10-17','2026-11-03')['items'];self.assertEqual(len(items),3);self.assertTrue(all(i['time']=='09:00' for i in items));self.assertEqual(items[1]['startEpoch']-items[0]['startEpoch'],7*86400+3600)
  detail=self.engine.detail('personal',saved['uid'],items[1]['rid']);detail.update(title='Moved occurrence',scope='occurrence',start='2026-10-26T11:00',end='2026-10-26T12:00');self.engine.save(detail,'override')
  items=self.engine.query('2026-10-17','2026-11-03')['items'];self.assertEqual(len(items),3);self.assertEqual(items[1]['title'],'Moved occurrence')
  review=self.engine.delete_preview('personal',saved['uid'],items[0]['rid'],'occurrence');self.engine.delete(review['token']);self.assertEqual(len(self.engine.query('2026-10-17','2026-11-03')['items']),2)
 def test_dst_nonexistent_and_fold(self):
  form=self.form();form.update(start='2026-03-29T01:30',end='2026-03-29T03:00')
  with self.assertRaises(CalendarError): self.save(form)
  form.update(start='2026-10-25T01:30',end='2026-10-25T02:30',fold=1);saved=self.save(form);self.assertEqual(self.engine.detail('personal',saved['uid'])['fold'],1)
 def test_all_day_and_ics_round_trip_duplicates(self):
  form=self.form();form.update(allDay=True,start='2026-10-11',end='2026-10-12',frequency='YEARLY');saved=self.save(form)
  detail=self.engine.detail('personal',saved['uid']);self.assertEqual(detail['end'],'2026-10-12')
  path=str(Path(self.temp.name)/'export.ics');review=self.engine.export_preview(path,'personal');self.engine.export_confirm(review['token'])
  other=self.engine.source_save({'name':'Imported'});review=self.engine.import_preview(path,other['id']);self.assertEqual(review['count'],1);self.engine.import_confirm(review['token'])
  review=self.engine.import_preview(path,other['id']);self.assertEqual(review['duplicates'],1);self.assertEqual(self.engine.import_confirm(review['token'])['imported'],0)
  self.assertEqual(len(self.engine.query('2026-10-12','2026-10-13')['items']),2)
  self.assertEqual(len(self.engine.query('2026-10-13','2026-10-14')['items']),0)
 def test_import_exception_preserves_uid_and_fields(self):
  path=Path(self.temp.name)/'test.ics';path.write_text('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:series@example\r\nSUMMARY:Master\r\nDTSTART:20261011T090000Z\r\nDTEND:20261011T100000Z\r\nRRULE:FREQ=DAILY;COUNT=3\r\nEXDATE:20261012T090000Z\r\nX-SENOMY-TEST:preserved\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n')
  review=self.engine.import_preview(str(path),'personal');self.engine.import_confirm(review['token']);items=self.engine.query('2026-10-11','2026-10-15')['items'];self.assertEqual(len(items),2);self.assertIn('X-SENOMY-TEST:preserved',self.engine.store.event('personal','series@example')['ics'])
 def test_search_visibility_preferences_and_readonly(self):
  saved=self.save();self.assertEqual(len(self.engine.query('2026-10-11','2026-10-12','meeting')['items']),1)
  self.assertFalse(self.engine.query('2026-10-11','2026-10-12','absent')['items'])
  self.engine.source_save({'id':'personal','name':'Personal','visible':False});self.assertFalse(self.engine.query('2026-10-11','2026-10-12')['items'])
  self.engine.prefs_save({'weekStart':0,'timeFormat':'12','timezone':'Europe/London'});self.assertEqual(self.engine.preferences()['weekStart'],0)
  with self.engine.store.db: self.engine.store.db.execute("UPDATE sources SET writable=0 WHERE id='personal'")
  with self.assertRaises(CalendarError): self.engine.delete_preview('personal',saved['uid'])
 def test_stale_review_and_dense_recurrence_rejected(self):
  saved=self.save();review=self.engine.delete_preview('personal',saved['uid']);detail=self.engine.detail('personal',saved['uid']);self.engine.save(detail,'second')
  with self.assertRaises(CalendarError): self.engine.delete(review['token'])
  path=Path(self.temp.name)/'dense.ics';path.write_text('BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:dense\nDTSTART:20261011T090000Z\nRRULE:FREQ=SECONDLY\nEND:VEVENT\nEND:VCALENDAR\n')
  with self.assertRaises(CalendarError): self.engine.import_preview(str(path),'personal')

 def test_notes_links_recurrence_search_and_export(self):
  from icalendar import Calendar
  form=self.form(notes='Agenda and notes: https://example.org/doc. Also https://example.org/doc and https://example.org/second',url='https://meet.example.org/room?key=abc')
  form.update(frequency='DAILY',count='3')
  saved=self.save(form);detail=self.engine.detail('personal',saved['uid'])
  self.assertEqual(detail['url'],form['url']);self.assertEqual(detail['notes'],form['notes'])
  self.assertEqual(detail['links'],[form['url'],'https://example.org/doc','https://example.org/second'])
  from senomy_calendar.engine import event_links
  from icalendar import Event
  notes=Event();notes.add('description','See (HTTPS://example.org/doc(foo)) and https://[::1]/path.')
  self.assertEqual(event_links(notes),['HTTPS://example.org/doc(foo)','https://[::1]/path'])
  items=self.engine.query('2026-10-11','2026-10-15','meet.example')['items'];self.assertEqual(len(items),3);self.assertTrue(all(e['hasNotes'] and e['hasLink'] for e in items))
  occurrence=self.engine.detail('personal',saved['uid'],items[1]['rid']);self.assertEqual(occurrence['links'],detail['links'])
  path=str(Path(self.temp.name)/'links.ics');self.engine.export_confirm(self.engine.export_preview(path,'personal')['token'])
  event=Calendar.from_ical(Path(path).read_bytes()).walk('VEVENT')[0];self.assertEqual(str(event['URL']),form['url']);self.assertEqual(str(event['DESCRIPTION']),form['notes'])
  detail.update(url='',notes='Notes without links');self.engine.save(detail,'clear-link');self.assertFalse(self.engine.detail('personal',saved['uid'])['links'])
 def test_unsafe_event_links_rejected_without_saving(self):
  for value in ['javascript:alert(1)','file:///etc/passwd','https://user:password@example.org','https://example.org/\nfoo','https://@example.org','https://example.org:99999','https://example.org\\evil','https:///broken']:
   with self.subTest(value=value),self.assertRaises(CalendarError):self.engine.save(self.form(url=value),value)
  self.assertEqual(self.engine.snapshot()['eventCount'],0)
 def test_imported_nonweb_url_preserved_but_not_launched(self):
  path=Path(self.temp.name)/'unsafe.ics';path.write_text('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:imported\r\nSUMMARY:Legacy\r\nDTSTART:20261011T090000Z\r\nDTEND:20261011T100000Z\r\nURL:file:///legacy\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n')
  self.engine.import_confirm(self.engine.import_preview(str(path),'personal')['token']);detail=self.engine.detail('personal','imported');self.assertEqual(detail['url'],'file:///legacy');self.assertFalse(detail['links']);detail['title']='Updated';self.engine.save(detail,'update-imported');self.assertIn('URL:file:///legacy',self.engine.store.event('personal','imported')['ics'])
 def test_default_reminder_preferences_persist_and_validate(self):
  self.assertEqual(self.engine.preferences()['defaultReminder'],'10')
  self.engine.clock=lambda:1791747000
  self.engine.prefs_save({'timezone':'Pacific/Auckland'})
  from datetime import datetime
  from zoneinfo import ZoneInfo
  expected=datetime.fromtimestamp(self.engine.clock(),ZoneInfo('Pacific/Auckland')).strftime('%Y-%m-%dT%H:%M')
  self.assertEqual(self.engine.snapshot()['nowLocal'],expected)
  for value in ['', '0','30','10080']:
   self.engine.prefs_save({'defaultReminder':value});self.assertEqual(self.engine.preferences()['defaultReminder'],value)
  for value in ['-1','10081','abc',True,10]:
   with self.subTest(value=value),self.assertRaises(CalendarError):self.engine.prefs_save({'defaultReminder':value})
  self.engine.store.db.close();self.engine=Engine(self.temp.name);self.assertEqual(self.engine.preferences()['defaultReminder'],'10080')



class PreservationTest(unittest.TestCase):
 def test_advanced_imported_rule_alarm_and_zero_duration(self):
  import tempfile
  from pathlib import Path
  from icalendar import Calendar
  with tempfile.TemporaryDirectory() as directory:
   engine=Engine(directory);path=Path(directory)/'advanced.ics'
   path.write_text('BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:advanced\r\nSUMMARY:Monthly\r\nDTSTART;TZID=Europe/London:20261001T090000\r\nDTEND;TZID=Europe/London:20261001T100000\r\nRRULE:FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=1\r\nBEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT10M\r\nDESCRIPTION:First\r\nEND:VALARM\r\nBEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT30M\r\nDESCRIPTION:Second\r\nEND:VALARM\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:instant\r\nSUMMARY:Instant event\r\nDTSTART:20261011T120000Z\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n')
   engine.import_confirm(engine.import_preview(str(path),'personal')['token']);detail=engine.detail('personal','advanced');detail['title']='Edited title';engine.save(detail,'edit')
   event=Calendar.from_ical(engine.store.event('personal','advanced')['ics']).walk('VEVENT')[0]
   self.assertEqual(event['RRULE']['BYSETPOS'],[1]);self.assertEqual(len(event.walk('VALARM')),2)
   self.assertTrue(any(e['uid']=='instant' for e in engine.query('2026-10-11','2026-10-12')['items']))
   engine.store.db.close()
 def test_calendar_remove_and_changed_export_destination(self):
  import tempfile
  from pathlib import Path
  with tempfile.TemporaryDirectory() as directory:
   engine=Engine(directory);source=engine.source_save({'name':'Disposable'})['id'];preview=engine.source_delete_preview(source)
   self.assertTrue(engine.store.source(source));engine.source_delete(preview['token'])
   with self.assertRaises(ValueError):engine.store.source(source)
   path=Path(directory)/'export.ics';preview=engine.export_preview(str(path),'personal');path.write_text('New unrelated content')
   with self.assertRaises(CalendarError):engine.export_confirm(preview['token'])
   self.assertEqual(path.read_text(),'New unrelated content');engine.store.db.close()

if __name__=='__main__': unittest.main()
