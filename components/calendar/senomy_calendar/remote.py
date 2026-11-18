"""Optional CalDAV adapter. Secrets stay in Secret Service, never shell state."""
import subprocess
import time
from urllib.parse import urlparse, urljoin
import caldav
from caldav.elements import dav
from .engine import CalendarError,parsed

class Remote:
 def __init__(self,engine,allow_http=False): self.engine=engine;self.store=engine.store;self.allow_http=allow_http
 def validate_url(self,url):
  parsed_url=urlparse(url)
  if parsed_url.scheme!='https' and not(self.allow_http and parsed_url.scheme=='http' and parsed_url.hostname in ['127.0.0.1','localhost']): raise CalendarError('CalDAV requires an HTTPS URL.')
  if not parsed_url.hostname or parsed_url.username or parsed_url.password or parsed_url.fragment or parsed_url.query: raise CalendarError('Enter a calendar URL without credentials or fragments.')
  return url
 def password(self,identifier):
  result=subprocess.run(['secret-tool','lookup','application','senomy-calendar','account',identifier],capture_output=True,text=True,timeout=10)
  if result.returncode or not result.stdout.strip(): raise CalendarError('No account credential is available. Set it through the credential terminal.')
  return result.stdout.rstrip('\n')
 def client(self,source):
  self.validate_url(source['url']);password=self.password(source['id']) if source['username'] else None
  return caldav.DAVClient(url=source['url'],username=source['username'] or None,password=password,timeout=10,ssl_verify_cert=True)
 def account_add(self,form):
  import uuid
  identifier=uuid.uuid4().hex;url=self.validate_url(form['url']);name=form.get('name','CalDAV').strip()[:100]
  if not name: raise CalendarError('Account needs a name.')
  with self.store.transaction(): self.store.db.execute('INSERT INTO sources(id,name,color,provider,url,username,sync_state) VALUES(?,?,?,?,?,?,?)',(identifier,name,'#8fb8c9','caldav',url,form.get('username','')[:200],'not-connected'))
  return dict(id=identifier)
 def sync(self,identifier):
  source=self.store.source(identifier)
  if source['provider']!='caldav': raise CalendarError('This calendar is local.')
  started=time.monotonic();client=self.client(source);calendar=caldav.Calendar(client=client,url=source['url']);remote={}
  # A complete collection enumeration is necessary before inferring deletions.
  objects=calendar.events()
  if len(objects)>2000: raise CalendarError('Remote calendar exceeds the 2000-series limit; nothing was removed.')
  for item in objects:
   if time.monotonic()-started>30: raise CalendarError('Sync time budget exceeded; retry later.')
   data=item.data;cal=parsed(data);events=cal.walk('VEVENT')
   if not events: continue
   uid=str(events[0]['UID']);href=str(item.url);etag=item.etag
   # caldav 3.x may retain the DAV XML element rather than its string.
   etag=str(etag.text or '') if hasattr(etag,'text') else str(etag or '')
   if len({str(e['UID']) for e in events})!=1: raise CalendarError('A remote resource contains multiple event UIDs.')
   remote[uid]=dict(ics=data,href=href,etag=etag)
  local={r['uid']:dict(r) for r in self.store.db.execute('SELECT * FROM events WHERE source=?',(identifier,))}
  conflicts=0
  for uid,row in local.items():
   if not row['dirty'] or not source['writable']: continue
   latest=remote.get(uid)
   if row['deleted'] and latest is None:
    with self.store.db: self.store.db.execute('DELETE FROM events WHERE source=? AND uid=?',(identifier,uid))
    continue
   if (latest and row['etag']!=latest['etag']) or (not latest and row['etag']):
    with self.store.db: self.store.db.execute('UPDATE events SET conflict=? WHERE source=? AND uid=?',(__import__('json').dumps(latest or {'deleted':True}),identifier,uid))
    conflicts+=1;continue
   href=row['href'] or urljoin(source['url'].rstrip('/')+'/',__import__('urllib.parse',fromlist=['quote']).quote(uid,safe='')+'.ics')
   if urlparse(href).netloc!=urlparse(source['url']).netloc: raise CalendarError('Cross-host resource URL rejected.')
   headers={'If-Match':row['etag']} if row['etag'] else {'If-None-Match':'*'}
   response=client.request(href,method='DELETE' if row['deleted'] else 'PUT',body='' if row['deleted'] else row['ics'],headers=dict(headers,**{'Content-Type':'text/calendar; charset=utf-8'}))
   if response.status==412:
    conflicts+=1
    with self.store.db: self.store.db.execute("UPDATE events SET conflict=? WHERE source=? AND uid=?",(__import__('json').dumps({'refreshRequired':True}),identifier,uid))
    continue
   if response.status not in [200,201,204]: raise CalendarError('Remote write failed; local edit remains queued.')
   with self.store.db:
    if row['deleted']: self.store.db.execute('DELETE FROM events WHERE source=? AND uid=?',(identifier,uid));remote.pop(uid,None)
    else:
     etag=response.headers.get('Etag',response.headers.get('ETag',''))
     if not etag:
      verification=client.request(href,method='GET')
      etag=verification.headers.get('ETag','')
      if verification.status!=200 or not etag: raise CalendarError('Upload accepted but remote version is unverified; sync again before editing.')
     self.store.db.execute('UPDATE events SET dirty=0,href=?,etag=?,conflict=\'\' WHERE source=? AND uid=?',(href,etag,identifier,uid));remote[uid]=dict(ics=row['ics'],href=href,etag=etag)
  state='conflicts' if conflicts else 'synced' if source['writable'] else 'read-only-synced'
  with self.store.transaction():
   for uid,record in remote.items():
    old=self.store.db.execute('SELECT * FROM events WHERE source=? AND uid=?',(identifier,uid)).fetchone()
    if old and (old['dirty'] or old['conflict']): continue
    if old:
     if old['ics']!=record['ics']: self.store.db.execute('UPDATE events SET ics=?,href=?,etag=?,revision=revision+1 WHERE source=? AND uid=?',(record['ics'],record['href'],record['etag'],identifier,uid))
     else: self.store.db.execute('UPDATE events SET etag=?,href=? WHERE source=? AND uid=?',(record['etag'],record['href'],identifier,uid))
    else: self.store.db.execute('INSERT INTO events(source,uid,ics,revision,href,etag) VALUES(?,?,?,1,?,?)',(identifier,uid,record['ics'],record['href'],record['etag']))
   for uid,row in local.items():
    if uid not in remote and not row['dirty'] and not row['conflict']: self.store.db.execute('DELETE FROM events WHERE source=? AND uid=?',(identifier,uid))
   self.store.db.execute('UPDATE sources SET sync_state=?,last_sync=? WHERE id=?',(state,self.engine.clock(),identifier))
  return dict(state=state,conflicts=conflicts)
 def sync_preview(self,identifier):
  source=self.store.source(identifier)
  if source['provider']!='caldav': raise CalendarError('This calendar is local.')
  count=self.store.db.execute('SELECT count(*) FROM events WHERE source=? AND dirty=1',(identifier,)).fetchone()[0]
  impact=f'Download remote events and upload {count} queued local changes. The remote calendar may be changed.' if source['writable'] else f'Download remote events only. This calendar is read-only; {count} queued local changes are retained without upload.'
  return dict(token=self.engine.preview('sync',(identifier,self.store.revision)),impact=impact)
 def sync_confirm(self,token):
  source,revision=self.engine.take_preview(token,'sync')
  if self.store.revision!=revision: raise CalendarError('Calendar changed; review sync again.')
  try: return self.sync(source)
  except Exception:
   with self.store.transaction(): self.store.db.execute("UPDATE sources SET sync_state='offline-or-error' WHERE id=?",(source,))
   raise CalendarError('Sync failed. Check the collection URL, connection and credentials; queued local changes are retained.') from None
 def resolve_preview(self,source,uid,choice):
  row=self.store.db.execute('SELECT * FROM events WHERE source=? AND uid=?',(source,uid)).fetchone()
  if not row: raise CalendarError('Conflict no longer exists.')
  if not row['conflict'] or choice not in ['local','remote']: raise CalendarError('No resolvable conflict.')
  import json
  data=json.loads(row['conflict'])
  if data.get('refreshRequired'): raise CalendarError('Sync again to download the conflicting version before reviewing it.')
  def describe(ics):
   event=parsed(ics).walk('VEVENT')[0]
   return str(event.get('SUMMARY','Untitled'))+' // '+str(event.decoded('DTSTART'))+' // '+str(event.get('LOCATION',''))
  return dict(token=self.engine.preview('conflict',(source,uid,row['revision'],row['conflict'],choice)),impact='Use the '+choice+' version; discard the other version after a private backup.',titles=['LOCAL: '+('Deleted' if row['deleted'] else describe(row['ics'])),'REMOTE: '+('Deleted' if data.get('deleted') else describe(data['ics']))])
 def resolve(self,token):
  import json
  source,uid,revision,conflict,choice=self.engine.take_preview(token,'conflict');row=self.store.db.execute('SELECT * FROM events WHERE source=? AND uid=?',(source,uid)).fetchone()
  if not row: raise CalendarError('Conflict no longer exists.')
  self.engine.check_revision(row,revision)
  data=json.loads(conflict)
  if data.get('refreshRequired'): raise CalendarError('Sync again before resolving this conflict.')
  if row['conflict']!=conflict: raise CalendarError('Conflict changed; review again.')
  self.store.backup()
  with self.store.transaction():
   if choice=='remote':
    if data.get('deleted'): self.store.db.execute('DELETE FROM events WHERE source=? AND uid=?',(source,uid))
    else: self.store.db.execute('UPDATE events SET ics=?,href=?,etag=?,dirty=0,deleted=0,conflict=\'\',revision=revision+1 WHERE source=? AND uid=?',(data['ics'],data['href'],data['etag'],source,uid))
   else: self.store.db.execute('UPDATE events SET etag=?,conflict=\'\',revision=revision+1 WHERE source=? AND uid=?',(data.get('etag',''),source,uid))
  return dict(state='resolved-locally')
