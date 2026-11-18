import unittest,tempfile,sys,threading,hashlib
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from xml.sax.saxutils import escape
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from senomy_calendar.engine import Engine,CalendarError
from senomy_calendar.remote import Remote

def content(title='Remote'):
 return 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:remote@example\r\nSUMMARY:'+title+'\r\nDTSTART:20261011T090000Z\r\nDTEND:20261011T100000Z\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n'
def etag(data):return '"'+hashlib.sha256(data.encode()).hexdigest()+'"'
class Handler(BaseHTTPRequestHandler):
 resources={};requests=[];reject_once=False
 def log_message(self,*args):pass
 def send(self,status,data='',kind='text/calendar',tag=''):
  raw=data.encode();self.send_response(status);self.send_header('Content-Type',kind);self.send_header('Content-Length',str(len(raw)))
  if tag:self.send_header('ETag',tag)
  self.end_headers();self.wfile.write(raw)
 def do_REPORT(self):
  self.rfile.read(int(self.headers.get('Content-Length',0)));items=[]
  for path,data in self.resources.items():items.append('<d:response><d:href>'+path+'</d:href><d:propstat><d:prop><d:getetag>'+escape(etag(data))+'</d:getetag><c:calendar-data>'+escape(data)+'</c:calendar-data></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>')
  self.send(207,'<?xml version="1.0"?><d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'+''.join(items)+'</d:multistatus>','application/xml')
 def do_GET(self):
  if self.path in self.resources:self.send(200,self.resources[self.path],tag=etag(self.resources[self.path]))
  else:self.send(404)
 def do_PUT(self):
  data=self.rfile.read(int(self.headers.get('Content-Length',0))).decode();self.requests.append(('PUT',self.path,dict(self.headers)))
  if self.reject_once:type(self).reject_once=False;self.send(412);return
  old=self.resources.get(self.path)
  if (old and self.headers.get('If-None-Match')=='*') or (self.headers.get('If-Match') and (not old or etag(old)!=self.headers['If-Match'])):self.send(412);return
  self.resources[self.path]=data;self.send(204 if old else 201,tag=etag(data))
 def do_DELETE(self):
  self.requests.append(('DELETE',self.path,dict(self.headers)));old=self.resources.get(self.path)
  if not old:self.send(404);return
  if self.headers.get('If-Match')!=etag(old):self.send(412);return
  del self.resources[self.path];self.send(204)
class RemoteTest(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.engine=Engine(self.temp.name);self.remote=Remote(self.engine,True);Handler.resources={'/cal/remote.ics':content()};Handler.requests=[];Handler.reject_once=False
  self.server=ThreadingHTTPServer(('127.0.0.1',0),Handler);self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start();self.id=self.remote.account_add({'url':f'http://127.0.0.1:{self.server.server_port}/cal/','name':'Private test collection'})['id']
 def tearDown(self):self.server.shutdown();self.server.server_close();self.thread.join();self.engine.store.db.close();self.temp.cleanup()
 def sync(self):return self.remote.sync_confirm(self.remote.sync_preview(self.id)['token'])
 def test_pull_upload_conflict_resolution_and_delete(self):
  self.assertEqual(self.sync()['state'],'synced');detail=self.engine.detail(self.id,'remote@example');detail['title']='Local edit';self.engine.save(detail,'local')
  self.assertEqual(self.engine.query('2026-10-11','2026-10-12')['items'][0]['pending'],True)
  Handler.resources['/cal/remote.ics']=content('External edit');self.assertEqual(self.sync()['state'],'conflicts');self.assertNotIn('Local edit',Handler.resources['/cal/remote.ics'])
  self.remote.resolve(self.remote.resolve_preview(self.id,'remote@example','local')['token']);self.assertEqual(self.sync()['state'],'synced');self.assertIn('Local edit',Handler.resources['/cal/remote.ics']);self.assertTrue(any('If-Match' in h for method,path,h in Handler.requests if method=='PUT'))
  review=self.engine.delete_preview(self.id,'remote@example');self.engine.delete(review['token']);self.sync();self.assertFalse(Handler.resources)
 def test_server_precondition_failure_and_offline_edit_retained(self):
  self.sync();detail=self.engine.detail(self.id,'remote@example');detail['title']='Queued';self.engine.save(detail,'local');Handler.reject_once=True;self.assertEqual(self.sync()['state'],'conflicts');self.assertIn('Queued',self.engine.store.event(self.id,'remote@example')['ics']);self.assertIn('Remote',Handler.resources['/cal/remote.ics'])
  self.server.shutdown();self.server.server_close()
  with self.assertRaises(Exception):self.sync()
  self.assertTrue(self.engine.store.event(self.id,'remote@example')['dirty'])
 def test_readonly_sync_keeps_queued_edits_without_upload(self):
  self.sync();detail=self.engine.detail(self.id,'remote@example');detail['title']='Queued local';self.engine.save(detail,'local')
  source=self.engine.store.source(self.id);source['writable']=False;self.engine.source_save(source)
  preview=self.remote.sync_preview(self.id);self.assertIn('without upload',preview['impact']);self.assertEqual(self.remote.sync_confirm(preview['token'])['state'],'read-only-synced')
  self.assertFalse(Handler.requests);self.assertIn('Remote',Handler.resources['/cal/remote.ics']);self.assertTrue(self.engine.store.event(self.id,'remote@example')['dirty'])
 def test_remote_deletion_already_absent_is_completed(self):
  self.sync();self.engine.delete(self.engine.delete_preview(self.id,'remote@example')['token']);Handler.resources={};self.sync()
  self.assertIsNone(self.engine.store.db.execute('SELECT 1 FROM events WHERE source=?',(self.id,)).fetchone())
 def test_https_policy_and_preview_has_no_remote_mutation(self):
  strict=Remote(self.engine)
  with self.assertRaises(CalendarError):strict.account_add({'url':'http://example.com/calendar','name':'Unsafe'})
  review=self.remote.sync_preview(self.id);self.assertFalse(Handler.requests);self.engine.source_save({'name':'Changed revision'})
  with self.assertRaises(CalendarError):self.remote.sync_confirm(review['token'])
if __name__=='__main__':unittest.main()
