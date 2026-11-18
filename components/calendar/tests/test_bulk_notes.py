import unittest,tempfile,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from senomy_calendar.engine import Engine,CalendarError,parsed

class NotesBulkTest(unittest.TestCase):
 def setUp(self):self.temp=tempfile.TemporaryDirectory();self.e=Engine(self.temp.name)
 def tearDown(self):self.e.store.db.close();self.temp.cleanup()
 def test_note_crud_draft_and_ics_round_trip(self):
  form=dict(source='personal',kind='note',title='',notes='Remember the documents\nhttps://example.org',start='2026-10-20',end='2026-10-20',allDay=True,frequency='NONE')
  saved=self.e.save(form,'note');detail=self.e.detail('personal',saved['uid']);self.assertEqual(detail['kind'],'note');self.assertEqual(detail['title'],'Remember the documents');self.assertEqual(detail['reminder'],'');self.assertTrue(detail['allDay']);self.assertEqual(detail['links'],['https://example.org'])
  item=self.e.query('2026-10-20','2026-10-21')['items'][0];self.assertEqual(item['kind'],'note');self.assertEqual(str(parsed(self.e.store.event('personal',saved['uid'])['ics']).walk('VEVENT')[0]['TRANSP']),'TRANSPARENT')
  self.e.draft_save(dict(detail,notes='New note draft'));self.assertEqual(self.e.draft_get()['notes'],'New note draft');detail['notes']='Edited note';self.e.save(detail,'edit-note');self.assertEqual(self.e.detail('personal',saved['uid'])['notes'],'Edited note')
  path=str(Path(self.temp.name)/'notes.ics');self.e.export_confirm(self.e.export_preview(path,'personal')['token']);other=self.e.source_save({'name':'Notes import'})['id'];self.e.import_confirm(self.e.import_preview(path,other)['token']);self.assertEqual(self.e.detail(other,saved['uid'])['kind'],'note')
  self.e.delete(self.e.delete_preview('personal',saved['uid'])['token']);self.assertEqual(len(self.e.query('2026-10-20','2026-10-21')['items']),1)
 def test_note_cannot_save_empty_text_or_clear_existing_record(self):
  form=dict(source='personal',kind='note',title='Note',notes='Keep this',start='2026-10-20',end='2026-10-20',frequency='NONE');saved=self.e.save(form,'create');detail=self.e.detail('personal',saved['uid']);detail['notes']=' '
  with self.assertRaises(CalendarError):self.e.save(detail,'empty')
  self.assertEqual(self.e.detail('personal',saved['uid'])['notes'],'Keep this')
 def test_bulk_preview_confirm_duplicate_and_repeat(self):
  data='date,title,start,end,notes,link,repeat,count,kind,reminder\n2026-10-20,Meeting,09:00,10:00,"Agenda, with commas",https://example.org,WEEKLY,3,event,15\n2026-10-21,,, ,Remember tickets,,,,note,none\n'
  preview=self.e.batch_preview(data,'personal');self.assertEqual(preview['count'],2);self.assertEqual(self.e.snapshot()['eventCount'],0)
  self.assertEqual(self.e.import_confirm(preview['token'])['imported'],2);items=self.e.query('2026-10-20','2026-11-06')['items'];self.assertEqual(len(items),4);self.assertEqual(sum(i['kind']=='note' for i in items),1)
  self.e.prefs_save({'defaultReminder':'30'});again=self.e.batch_preview(data,'personal');self.assertEqual(again['duplicates'],2);self.assertEqual(self.e.import_confirm(again['token'])['imported'],0)
 def test_tab_separated_file_and_bom(self):
  path=Path(self.temp.name)/'schedule.tsv';path.write_text('\ufeffdate\ttitle\tnotes\n2026-10-20\tAppointment\tBring notes, and a pen\n',encoding='utf-8');preview=self.e.import_preview(str(path),'personal');self.assertEqual(self.e.import_confirm(preview['token'])['imported'],1)
 def test_bad_row_atomic_preview_and_stale_review(self):
  bad='date,title,start,end,link\n2026-10-20,Valid,09:00,10:00,\n2026-10-20,Bad,10:00,09:00,javascript:bad\n'
  with self.assertRaisesRegex(CalendarError,'Row 3:'):self.e.batch_preview(bad,'personal')
  self.assertEqual(self.e.snapshot()['eventCount'],0)
  preview=self.e.batch_preview('date,title\n2026-10-20,All day\n','personal');self.e.source_save({'name':'New source'})
  with self.assertRaises(CalendarError):self.e.import_confirm(preview['token'])
  self.assertEqual(self.e.snapshot()['eventCount'],0)
 def test_limits_headers_quoting_and_readonly(self):
  for data in ['date,title\n'+''.join('2026-10-20,Event\n' for _ in range(201)), 'date,title,unknown\n2026-10-20,E,X\n','date,title\n2026-10-20,E,extra\n','date,title\n2026-10-20,"unterminated']:
   with self.subTest(data=data[:40]),self.assertRaises(CalendarError):self.e.batch_preview(data,'personal')
  self.e.source_save({'id':'personal','name':'Personal','writable':False})
  with self.assertRaises(CalendarError):self.e.batch_preview('date,title\n2026-10-20,E','personal')
 def test_duplicate_rows_in_one_batch_are_collapsed(self):
  p=self.e.batch_preview('date,title\n2026-10-20,E\n2026-10-20,E\n','personal');self.assertEqual(p['rows'],2);self.assertEqual(p['count'],1);self.assertEqual(self.e.import_confirm(p['token'])['imported'],1)

if __name__=='__main__':unittest.main()
