"""iCalendar parsing/recurrence use maintained libraries, never QML date arithmetic."""
from datetime import date, datetime, timedelta, timezone
import csv
import io
import hashlib
import itertools
import json
from pathlib import Path
import re
import secrets
import time
import uuid
from urllib.parse import urlsplit
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
import icalendar
import recurring_ical_events
import tzlocal
from .store import Store, StoreError, DEFAULTS

UTC=timezone.utc
MAX_ICS=2*1024*1024
MAX_EVENTS=2000

class CalendarError(ValueError): pass

class FieldErrors(CalendarError):
    def __init__(self, fields):
        self.fields=fields
        super().__init__('Check the highlighted fields. Your draft is retained.')


def zone(name):
    try: return ZoneInfo(tzlocal.get_localzone_name() if name == 'local' else name)
    except (ZoneInfoNotFoundError,ValueError): raise CalendarError('Unknown timezone. Use local or an IANA name such as Europe/London.') from None

def text(value, limit=1000):
    if not isinstance(value,str) or len(value)>limit or '\x00' in value: raise CalendarError('Text is invalid or too long.')
    return value

def event_url(value):
    value=text(value,2048).strip()
    if not value: return ''
    try:
        uri=urlsplit(value)
        valid=uri.scheme.lower() in ('http','https') and uri.hostname and uri.port != 0 and uri.username is None and uri.password is None
    except ValueError: valid=False
    if not valid or re.search(r'[\s\x00-\x1f\x7f]',value) or '\\' in value:
        raise CalendarError('Event links must be complete http:// or https:// addresses without embedded credentials.')
    return value

def event_links(event):
    # Imported unsupported URL properties remain intact, but are never launchable.
    values=[str(event.get('URL',''))]+re.findall(r'https?://[^\s<>"\x00-\x1f]+',str(event.get('DESCRIPTION','')),flags=re.IGNORECASE)[:20]
    result=[]
    for index,value in enumerate(values):
        if index:
            value=value.rstrip('.,;!?')
            for closing,opening in [(')', '('), (']', '['), ('}', '{')]:
                while value.endswith(closing) and value.count(closing)>value.count(opening): value=value[:-1]
        try: value=event_url(value)
        except CalendarError: continue
        if value and value not in result: result.append(value)
        if len(result)==10: break
    return result

def encoded(value): return value.isoformat()

def moment(value, tz):
    if isinstance(value,datetime): return value.replace(tzinfo=tz) if value.tzinfo is None else value.astimezone(tz)
    return datetime.combine(value, datetime.min.time(), tz)

def calendar_for(events):
    result=icalendar.Calendar();result.add('prodid','-//SenomyOS//Calendar//EN');result.add('version','2.0')
    for event in events: result.add_component(event)
    return result

def parsed(data):
    if len(data.encode('utf-8'))>MAX_ICS: raise CalendarError('ICS exceeds the 2 MiB import limit.')
    cal=icalendar.Calendar.from_ical(data)
    if cal.name!='VCALENDAR': raise CalendarError('Expected a VCALENDAR file.')
    events=cal.walk('VEVENT')
    if len(events)>MAX_EVENTS: raise CalendarError('Too many event components.')
    for event in events:
        if not event.get('UID') or not event.get('DTSTART'): raise CalendarError('An event has no UID or start date.')
        if event.get('RRULE'):
            rule=event['RRULE']; freq=str(rule.get('FREQ',[''])[0])
            if freq not in ['DAILY','WEEKLY','MONTHLY','YEARLY']: raise CalendarError('Only daily, weekly, monthly and yearly recurrence is supported.')
            if any(len(rule.get(key,[]))>1 for key in ['BYSECOND','BYMINUTE','BYHOUR']): raise CalendarError('Dense sub-day recurrence cannot be imported.')
        if event.get('ATTACH'): raise CalendarError('Remove attachments before import; external attachments are not fetched.')
    return cal

def local_datetime(value,tz,fold=0):
    dt=datetime.fromisoformat(value)
    if dt.tzinfo is not None: raise CalendarError('Enter local date/time and select its timezone separately.')
    aware=dt.replace(tzinfo=tz,fold=int(fold))
    if aware.astimezone(UTC).astimezone(tz).replace(tzinfo=None)!=dt: raise CalendarError('This time does not exist because of a daylight-saving change.')
    return aware

class Engine:
    def __init__(self,directory,clock=time.time):
        self.store=Store(directory);self.clock=clock;self.previews={}
    def preferences(self): return self.store.preferences()
    def snapshot(self):
        return dict(revision=self.store.revision,sources=self.store.sources(),preferences=self.preferences(),
                    today=datetime.fromtimestamp(self.clock(),zone(self.preferences()['timezone'])).date().isoformat(),
                    nowLocal=datetime.fromtimestamp(self.clock(),zone(self.preferences()['timezone'])).strftime('%Y-%m-%dT%H:%M'),
                    hasDraft=bool(self.store.db.execute('SELECT 1 FROM drafts').fetchone()),
                    conflicts=[dict(source=r['source'],uid=r['uid'],revision=r['revision']) for r in self.store.db.execute("SELECT source,uid,revision FROM events WHERE conflict!=''")],
                    reminders=[dict(r) for r in self.store.db.execute("SELECT key,source,uid,occurrence,title,due,status,snooze FROM alarms WHERE status NOT IN ('dismissed','acknowledged','cancelled') ORDER BY due DESC LIMIT 100")],
                    capabilities=dict(local=True,recurrence=True,ics=True,caldav=True,invitations=False),
                    eventCount=self.store.db.execute('SELECT count(*) FROM events WHERE deleted=0').fetchone()[0])
    def check_revision(self,row,expected):
        if row['revision']!=expected: raise CalendarError('Event changed since it was opened. Reload before saving.')
    def validate_form(self,form,old=None,rid=''):
        errors={}
        def check(key, action, fallback):
            try: return action()
            except (ValueError,TypeError,KeyError,OverflowError) as error:
                errors[key]=str(error) if isinstance(error,CalendarError) else fallback
        kind=form.get('kind','event');all_day=kind=='note' or bool(form.get('allDay',False))
        if kind=='note' and not str(form.get('notes','')).strip(): errors['notes']='Write your note before saving.'
        if kind!='note' and not str(form.get('title','')).strip(): errors['title']='Enter an event title.'
        tzname=form.get('timezone',self.preferences()['timezone'])
        tz=None if all_day or tzname=='floating' else check('timezone',lambda:zone(tzname),'Choose local, floating or an IANA timezone.')
        values={}
        for key in ('start','end'):
            raw=form.get(key,'')
            values[key]=check(key,lambda:date.fromisoformat(raw) if all_day else datetime.fromisoformat(raw),'Enter a real date'+(' and time in HH:MM.' if not all_day else '.'))
            if not all_day and values[key] is not None:
                if values[key].tzinfo: errors[key]='Enter local time and choose its timezone separately.'
                elif tz is not None: check(key+'Time',lambda:local_datetime(raw,tz,form.get('endFold' if key=='end' else 'fold',form.get('fold',0))),'Choose a valid local time.')
        if all(v is not None for v in values.values()) and (values['end']<values['start'] if all_day else values['end']<=values['start']): errors['end']='End must follow start; all-day events may end on the same day.'
        if 'url' in form and not (old is not None and form['url']==str(old.get('URL',''))): check('url',lambda:event_url(form['url']),'Use a complete http:// or https:// link.')
        def integer(key,low,high):
            value=form.get(key,'')
            if not re.fullmatch(r'\d+',str(value)) or not low<=int(value)<=high: raise CalendarError(f'Use a whole number from {low} to {high}.')
        if form.get('frequency','NONE')!='NONE' and not rid:
            if form.get('frequency') not in ['DAILY','WEEKLY','MONTHLY','YEARLY']: errors['frequency']='Choose a supported repeat frequency.'
            check('interval',lambda:integer('interval',1,365),'Repeat interval must be 1–365.') if 'interval' in form else None
            if form.get('count'): check('count',lambda:integer('count',1,10000),'Repeat count must be 1–10000.')
            if form.get('count') and form.get('until'): errors['until']='Use a repeat count or an end date; clear the other.'
            elif form.get('until'):
                until=check('until',lambda:date.fromisoformat(form['until']),'Enter a real repeat end date.')
                start=values['start']
                if until and start and until<(start if all_day else start.date()): errors['until']='Repeat end must be on or after start.'
        reminder=form.get('reminder','')
        alarms=old.walk('VALARM') if old is not None else []
        previous=str(int(-alarms[0].decoded('TRIGGER').total_seconds()/60)) if alarms and isinstance(alarms[0].decoded('TRIGGER',None),timedelta) else ''
        if reminder not in ('',None,'NONE') and str(reminder)!=previous: check('reminder',lambda:integer('reminder',0,10080),'Choose a whole reminder amount up to 1 week before start.')
        if errors: raise FieldErrors(errors)

    def build_event(self,form,uid,old=None,rid=''):
        self.validate_form(form,old,rid)
        event=old.copy() if old else icalendar.Event()
        if old: event.subcomponents=list(old.subcomponents)
        for key in ['UID','SUMMARY','DESCRIPTION','LOCATION','DTSTART','DTEND','DURATION','RRULE','DTSTAMP','LAST-MODIFIED','SEQUENCE']:
            event.pop(key,None)
        kind=form.get('kind',str(old.get('X-SENOMY-KIND','event')).lower() if old else 'event')
        if kind not in ('event','note'): raise CalendarError('Choose an event or a dated note.')
        notes=text(form.get('notes',''),10000)
        if kind=='note' and not notes.strip(): raise CalendarError('Write something in your note before saving.')
        event.pop('X-SENOMY-KIND',None)
        if kind=='note':
            event.add('x-senomy-kind','note');event.pop('TRANSP',None);event.add('transp','TRANSPARENT')
        title=text(form.get('title','').strip(),200)
        if kind=='note' and not title: title=' '.join(notes.splitlines()[0].split())[:80] or 'Dated note'

        if not title: raise CalendarError('Enter an event title.')
        event.add('uid',uid);event.add('summary',title)
        event.add('description',text(form.get('notes',''),10000));event.add('location',text(form.get('location',''),1000))
        if 'url' in form:
            raw=text(form['url'],2048).strip()
            unchanged=old is not None and raw==str(old.get('URL',''))
            value=raw if unchanged else event_url(raw)
            event.pop('URL',None)
            if value: event.add('url',value)
        all_day=kind=='note' or bool(form.get('allDay',False));tzname=form.get('timezone',self.preferences()['timezone'])
        if all_day:
            start=date.fromisoformat(form['start'][:10]);end=date.fromisoformat(form['end'][:10])+timedelta(days=1)
        elif tzname=='floating':
            start=datetime.fromisoformat(form['start']);end=datetime.fromisoformat(form['end'])
            if start.tzinfo or end.tzinfo: raise CalendarError('Floating times cannot include UTC offsets.')
        else:
            tz=zone(tzname);start=local_datetime(form['start'],tz,form.get('fold',0));end=local_datetime(form['end'],tz,form.get('endFold',form.get('fold',0)))
        if end<=start: raise CalendarError('End must be after start (or on/after the first day for all-day events).')
        freq=form.get('frequency','NONE')
        # RFC 5545 TZID wall times encode the first repeated hour. Preserve an
        # explicitly chosen second hour as UTC for a non-repeating event.
        event.pop('X-SENOMY-TIMEZONE',None)
        if isinstance(start,datetime) and start.tzinfo and (start.fold or end.fold):
            if freq!='NONE' and not rid: raise CalendarError('For repeats starting in the second DST hour, choose UTC or the first hour.')
            event.add('x-senomy-timezone',tzname)
            start=start.astimezone(UTC);end=end.astimezone(UTC)
        event.add('dtstart',start);event.add('dtend',end)
        if freq!='NONE' and not rid:
            if freq not in ['DAILY','WEEKLY','MONTHLY','YEARLY']: raise CalendarError('Unsupported repeat frequency.')
            interval=int(form.get('interval',1))
            if not 1<=interval<=365: raise CalendarError('Repeat interval must be 1–365.')
            original_rule=old.get('RRULE',{}) if old else {}
            rule=dict(original_rule) if str(original_rule.get('FREQ',[''])[0])==freq else {}
            rule['FREQ']=freq;rule['INTERVAL']=interval
            rule.pop('COUNT',None);rule.pop('UNTIL',None)
            count=form.get('count','')
            until=form.get('until','')
            if count and until: raise CalendarError('Use either a repeat count or an end date.')
            if count:
                count=int(count)
                if not 1<=count<=10000: raise CalendarError('Repeat count must be 1–10000.')
                rule['COUNT']=count
            if until:
                last=date.fromisoformat(until)
                if last < start.date() if isinstance(start,datetime) else last<start: raise CalendarError('Repeat end precedes start.')
                previous_until=original_rule.get('UNTIL',[None])[0]
                rule['UNTIL']=previous_until if previous_until and str(previous_until)[:10]==until else datetime.combine(last,datetime.max.time().replace(microsecond=0),start.tzinfo).astimezone(UTC) if isinstance(start,datetime) and start.tzinfo else datetime.combine(last,datetime.max.time().replace(microsecond=0)) if isinstance(start,datetime) else last
            event.add('rrule',rule)
        reminder=form.get('reminder','')
        old_alarms=old.walk('VALARM') if old else []
        old_minutes=''
        if old_alarms and isinstance(old_alarms[0].decoded('TRIGGER',None),timedelta): old_minutes=str(int(-old_alarms[0].decoded('TRIGGER').total_seconds()/60))
        replace_alarms=not old or str(reminder or '')!=old_minutes
        if replace_alarms: event.subcomponents=[c for c in event.subcomponents if c.name!='VALARM' or str(c.get('ACTION',''))!='DISPLAY']
        if replace_alarms and reminder not in ('',None,'NONE'):
            minutes=int(reminder)
            if not 0<=minutes<=10080: raise CalendarError('Reminders must be 0–10080 minutes before start.')
            alarm=icalendar.Alarm();alarm.add('action','DISPLAY');alarm.add('description',title);alarm.add('trigger',-timedelta(minutes=minutes));event.add_component(alarm)
        event.add('dtstamp',datetime.fromtimestamp(self.clock(),UTC));event.add('last-modified',datetime.fromtimestamp(self.clock(),UTC));event.add('sequence',int(old.get('SEQUENCE',0))+1 if old else 0)
        return event
    def detail(self,source,uid,rid=''):
        row=self.store.event(source,uid);cal=parsed(row['ics']);events=cal.walk('VEVENT')
        event=next((e for e in events if e.get('RECURRENCE-ID') and encoded(e.decoded('RECURRENCE-ID'))==rid),None) if rid else None
        master=next((e for e in events if not e.get('RECURRENCE-ID')),events[0]);event=event or master
        if rid and not event.get('RECURRENCE-ID'):
            occurrences=recurring_ical_events.of(cal).at(datetime.fromisoformat(rid) if 'T' in rid else date.fromisoformat(rid))
            event=next((e for e in occurrences if encoded(e.decoded('RECURRENCE-ID',e.decoded('DTSTART')))==rid),None)
            if event is None: raise CalendarError('Occurrence no longer exists.')
        start=event.decoded('DTSTART');end=event.decoded('DTEND',start+timedelta(days=1) if not isinstance(start,datetime) else start+timedelta(hours=1))
        all_day=not isinstance(start,datetime);tzname='floating' if isinstance(start,datetime) and start.tzinfo is None else getattr(start.tzinfo,'key','UTC') if isinstance(start,datetime) else self.preferences()['timezone']
        if event.get('X-SENOMY-TIMEZONE') and not all_day:
            tzname=str(event['X-SENOMY-TIMEZONE']);start=start.astimezone(zone(tzname));end=end.astimezone(zone(tzname))
        rule=master.get('RRULE',{})
        alarms=event.walk('VALARM');minutes=''
        if alarms and isinstance(alarms[0].decoded('TRIGGER',None),timedelta): minutes=str(int(-alarms[0].decoded('TRIGGER').total_seconds()/60))
        form=dict(source=source,uid=uid,revision=row['revision'],rid=rid,kind='note' if str(event.get('X-SENOMY-KIND','')).lower()=='note' else 'event',title=str(event.get('SUMMARY','')),notes=str(event.get('DESCRIPTION','')),url=str(event.get('URL','')),links=event_links(event),location=str(event.get('LOCATION','')),allDay=all_day,timezone=tzname,
                  start=start.isoformat() if all_day else start.replace(tzinfo=None).isoformat(timespec='minutes'),end=(end-timedelta(days=1)).isoformat() if all_day else end.replace(tzinfo=None).isoformat(timespec='minutes'),
                  frequency=str(rule.get('FREQ',['NONE'])[0]),interval=int(rule.get('INTERVAL',[1])[0]),count=str(rule.get('COUNT',[''])[0]),until=str(rule.get('UNTIL',[''])[0])[:10],reminder=minutes,fold=getattr(start,'fold',0),endFold=getattr(end,'fold',0),writable=bool(self.store.source(source)['writable']),conflict=bool(row['conflict']))
        return form
    def save(self,form,request):
        cached=self.store.receipt(request)
        if cached: return cached
        try: source=self.store.source(form.get('source',self.preferences()['defaultCalendar']))
        except StoreError: raise FieldErrors({'source':'Choose an available calendar.'}) from None
        if not source['writable']: raise FieldErrors({'source':'This calendar is read-only. Choose a writable calendar for a new item.'})
        uid=text(form.get('uid') or uuid.uuid4().hex+'@senomyos',256);rid=form.get('rid','');scope=form.get('scope','series')
        existing=self.store.db.execute('SELECT * FROM events WHERE source=? AND uid=?',(source['id'],uid)).fetchone()
        old=None;cal=calendar_for([])
        if existing:
            self.check_revision(existing,form.get('revision'));cal=parsed(existing['ics']);old=next((e for e in cal.walk('VEVENT') if not e.get('RECURRENCE-ID')),None)
        if rid and scope=='occurrence':
            old=next((e for e in cal.walk('VEVENT') if e.get('RECURRENCE-ID') and encoded(e.decoded('RECURRENCE-ID'))==rid),old)
        elif rid: rid=''
        event=self.build_event(form,uid,old,rid)
        if rid:
            event.pop('RECURRENCE-ID',None);event.add('recurrence-id',datetime.fromisoformat(rid) if 'T' in rid else date.fromisoformat(rid))
        cal.subcomponents=[e for e in cal.subcomponents if e.name!='VEVENT' or (encoded(e.decoded('RECURRENCE-ID')) if e.get('RECURRENCE-ID') else '') != rid]
        cal.add_component(event);data=cal.to_ical().decode();revision=existing['revision']+1 if existing else 1
        with self.store.transaction():
            if existing: self.store.db.execute('UPDATE events SET ics=?,revision=?,dirty=?,deleted=0 WHERE source=? AND uid=?',(data,revision,int(source['provider']!='local'),source['id'],uid))
            else:
                if self.store.db.execute('SELECT count(*) FROM events').fetchone()[0]>=MAX_EVENTS: raise CalendarError('Local storage limit reached (2000 series).')
                self.store.db.execute('INSERT INTO events(source,uid,ics,revision,dirty) VALUES(?,?,?,?,?)',(source['id'],uid,data,revision,int(source['provider']!='local')))
            result=dict(uid=uid,source=source['id'],revision=revision,state='saved-local' if source['provider']=='local' else 'queued-offline')
            self.store.save_receipt(request,result)
            self.store.db.execute("DELETE FROM drafts WHERE id='composer'")
        return result
    def draft_save(self,form):
        data=json.dumps(form)
        if len(data.encode())>65536: raise CalendarError('Draft is too large.')
        with self.store.db: self.store.db.execute("INSERT OR REPLACE INTO drafts VALUES('composer',?)",(data,))
        return dict(state='draft-saved')
    def draft_get(self):
        row=self.store.db.execute("SELECT data FROM drafts WHERE id='composer'").fetchone()
        return json.loads(row[0]) if row else {}
    def draft_discard(self):
        with self.store.db: self.store.db.execute("DELETE FROM drafts WHERE id='composer'")
        return dict(state='draft-discarded')
    def query(self,start,end,search='',source=''):
        prefs=self.preferences();tz=zone(prefs['timezone']);begin=moment(date.fromisoformat(start),tz);stop=moment(date.fromisoformat(end),tz)
        if not 0<=(stop-begin).days<=93 or stop<=begin: raise CalendarError('Query range must be 1–93 days.')
        rows=self.store.db.execute('SELECT e.*,s.name,s.color,s.visible,s.writable FROM events e JOIN sources s ON s.id=e.source WHERE deleted=0 AND s.visible=1'+(' AND source=?' if source else ''),(source,) if source else ()).fetchall()
        items=[];truncated=False
        for row in rows:
            cal=parsed(row['ics'])
            pages=recurring_ical_events.of(cal).paginate(501,earliest_end=begin,latest_start=stop)
            page=next(iter(pages),None)
            if page is None: continue
            for event in page:
                event_start=event.decoded('DTSTART');event_end=event.decoded('DTEND',event_start+timedelta(minutes=1) if isinstance(event_start,datetime) else event_start+timedelta(days=1))
                if moment(event_start,tz)>=stop or moment(event_end,tz)<=begin: continue
                if search and search.casefold() not in (' '.join(str(event.get(k,'')) for k in ['SUMMARY','DESCRIPTION','LOCATION','URL'])).casefold(): continue
                rid=encoded(event.decoded('RECURRENCE-ID',event_start))
                shown=moment(event_start,tz);finished=moment(event_end,tz)
                items.append(dict(source=row['source'],uid=row['uid'],rid=rid,revision=row['revision'],kind='note' if str(event.get('X-SENOMY-KIND','')).lower()=='note' else 'event',title=str(event.get('SUMMARY','')),hasNotes=bool(event.get('DESCRIPTION')),hasLink=bool(event_links(event)),location=str(event.get('LOCATION','')),allDay=not isinstance(event_start,datetime),start=encoded(event_start),end=encoded(event_end),date=shown.date().isoformat(),endDate=finished.date().isoformat(),startMinute=shown.hour*60+shown.minute,endMinute=finished.hour*60+finished.minute,lastDate=(finished.date()-timedelta(days=1)).isoformat() if not isinstance(event_start,datetime) or (finished.hour==0 and finished.minute==0) else finished.date().isoformat(),time=shown.strftime('%H:%M' if prefs['timeFormat']=='24' else '%I:%M %p'),endTime=finished.strftime('%H:%M' if prefs['timeFormat']=='24' else '%I:%M %p'),startEpoch=shown.timestamp(),endEpoch=finished.timestamp(),calendar=row['name'],color=row['color'],writable=bool(row['writable']),recurring=any(e.get('RRULE') for e in cal.walk('VEVENT')),pending=bool(row['dirty']),conflict=bool(row['conflict'])))
                if len(items)>=500: truncated=True;break
            if truncated: break
        items.sort(key=lambda e:(e['date'],not e['allDay'],e['startEpoch'],e['title']))
        return dict(items=items,truncated=truncated,revision=self.store.revision)
    def preview(self,operation,payload):
        token=secrets.token_hex(24);self.previews[token]=(self.clock()+120,operation,payload);return token
    def take_preview(self,token,operation):
        expires,kind,payload=self.previews.pop(token,(0,'',None))
        if kind!=operation or expires<self.clock(): raise CalendarError('Review expired. Review the action again.')
        return payload
    def delete_preview(self,source,uid,rid='',scope='series'):
        row=self.store.event(source,uid)
        if not self.store.source(source)['writable']: raise CalendarError('Calendar is read-only.')
        return dict(token=self.preview('delete',(source,uid,row['revision'],rid,scope)),impact='Delete this occurrence' if rid and scope=='occurrence' else 'Delete the entire event or recurring series')
    def delete(self,token):
        source,uid,revision,rid,scope=self.take_preview(token,'delete');row=self.store.event(source,uid);self.check_revision(row,revision)
        if not self.store.source(source)['writable']: raise CalendarError('Calendar is read-only.')
        with self.store.transaction():
            if rid and scope=='occurrence':
                cal=parsed(row['ics']);master=next(e for e in cal.walk('VEVENT') if not e.get('RECURRENCE-ID'));master.add('exdate',datetime.fromisoformat(rid) if 'T' in rid else date.fromisoformat(rid));cal.subcomponents=[e for e in cal.subcomponents if not(e.name=='VEVENT' and e.get('RECURRENCE-ID') and encoded(e.decoded('RECURRENCE-ID'))==rid)]
                self.store.db.execute('UPDATE events SET ics=?,revision=revision+1,dirty=? WHERE source=? AND uid=?',(cal.to_ical().decode(),int(self.store.source(source)['provider']!='local'),source,uid))
            elif self.store.source(source)['provider']=='local': self.store.db.execute('DELETE FROM events WHERE source=? AND uid=?',(source,uid))
            else: self.store.db.execute('UPDATE events SET deleted=1,dirty=1,revision=revision+1 WHERE source=? AND uid=?',(source,uid))
            if rid and scope=='occurrence':
                self.store.db.execute('DELETE FROM alarms WHERE source=? AND uid=? AND occurrence=? AND status NOT IN (\'acknowledged\',\'dismissed\')',(source,uid,rid))
            else:
                self.store.db.execute('DELETE FROM alarms WHERE source=? AND uid=? AND status NOT IN (\'acknowledged\',\'dismissed\')',(source,uid))
        return dict(state='deleted-local' if self.store.source(source)['provider']=='local' else 'queued-offline')
    def source_save(self,form):
        identifier=form.get('id') or uuid.uuid4().hex;name=text(form.get('name','').strip(),100);color=form.get('color','#a997ef')
        if not name: raise CalendarError('Calendar needs a name.')
        if not re.fullmatch('#[0-9a-fA-F]{6}',color): raise CalendarError('Colour must be #RRGGBB.')
        with self.store.transaction():
            old=self.store.db.execute('SELECT id,writable FROM sources WHERE id=?',(identifier,)).fetchone()
            if old: self.store.db.execute('UPDATE sources SET name=?,color=?,visible=?,writable=? WHERE id=?',(name,color,int(form.get('visible',True)),int(form.get('writable',old['writable'])),identifier))
            else: self.store.db.execute('INSERT INTO sources(id,name,color) VALUES(?,?,?)',(identifier,name,color))
        return dict(id=identifier)
    def source_delete_preview(self,source):
        record=self.store.source(source)
        if source=='personal': raise CalendarError('The built-in Personal calendar is retained. Delete individual events instead.')
        count=self.store.db.execute('SELECT count(*) FROM events WHERE source=?',(source,)).fetchone()[0]
        return dict(token=self.preview('source-delete',(source,self.store.revision)),impact=f'Remove {record["name"]} and {count} cached event series from this device. Remote calendars and stored credentials are unchanged; a private backup is retained.')
    def source_delete(self,token):
        source,revision=self.take_preview(token,'source-delete')
        if self.store.revision!=revision: raise CalendarError('Calendar changed; review removal again.')
        self.store.backup()
        with self.store.transaction():
            self.store.db.execute('DELETE FROM alarms WHERE source=?',(source,))
            self.store.db.execute('DELETE FROM events WHERE source=?',(source,))
            self.store.db.execute('DELETE FROM sources WHERE id=?',(source,))
            prefs=self.preferences()
            if prefs['defaultCalendar']==source:
                prefs['defaultCalendar']='personal';self.store.db.execute('UPDATE settings SET data=? WHERE id=1',(json.dumps(prefs),))
        return dict(state='removed-local')
    def prefs_save(self,form):
        prefs=dict(self.preferences(),**{k:form[k] for k in DEFAULTS if k in form})
        errors={}
        if prefs['weekStart'] not in [-1,0,1,2,3,4,5,6]: errors['weekStart']='Choose a valid first day of the week.'
        if prefs['timeFormat'] not in ['12','24']: errors['timeFormat']='Choose 12-hour or 24-hour time.'
        if prefs['dateFormat'] not in ['iso','eu','us']: errors['dateFormat']='Choose European, American or ISO date format.'
        reminder=prefs['defaultReminder']
        if reminder != '' and (not isinstance(reminder,str) or not re.fullmatch(r'\d{1,5}',reminder) or int(reminder)>10080): errors['defaultReminder']='Choose a whole reminder amount from zero to 1 week before start.'
        try: zone(prefs['timezone'])
        except CalendarError as error: errors['timezone']=str(error)
        try: self.store.source(prefs['defaultCalendar'])
        except ValueError: errors['defaultCalendar']='Choose an available calendar.'
        for key in ['workStart','workEnd']:
            if not isinstance(prefs[key],str) or not re.fullmatch(r'(?:[01]\d|2[0-3]):[0-5]\d',prefs[key]): errors[key]='Use HH:MM, from 00:00 to 23:59.'
        if not any(k in errors for k in ('workStart','workEnd')) and prefs['workEnd']<=prefs['workStart']: errors['workEnd']='Work end must follow work start.'
        if errors: raise FieldErrors(errors)
        with self.store.transaction(): self.store.db.execute('UPDATE settings SET data=? WHERE id=1',(json.dumps(prefs),))
        return prefs
    def import_preview(self,path,source):
        self.store.source(source);p=Path(path).expanduser()
        if p.suffix.lower() in ('.csv','.tsv'):
            if not p.is_file() or p.stat().st_size>24000: raise CalendarError('Schedule files must be under 24 KiB (up to 200 rows).')
            return self.batch_preview(p.read_text(encoding='utf-8-sig'),source)
        if not p.is_file() or p.stat().st_size>MAX_ICS: raise CalendarError('Choose a regular ICS file under 2 MiB.')
        data=p.read_text();cal=parsed(data);groups={}
        for event in cal.walk('VEVENT'): groups.setdefault(str(event['UID']),[]).append(event)
        if not groups: raise CalendarError('No events in this ICS file.')
        existing={r[0] for r in self.store.db.execute('SELECT uid FROM events WHERE source=?',(source,))}
        return dict(token=self.preview('import',(source,data,self.store.revision)),count=len(groups),duplicates=len(existing.intersection(groups)),titles=[str(events[0].get('SUMMARY','Untitled')) for events in list(groups.values())[:20]],policy='Skip existing UIDs; preserve complete series and exceptions. No invitations are sent.')
    def import_confirm(self,token):
        source,data,revision=self.take_preview(token,'import')
        if self.store.revision!=revision: raise CalendarError('Calendar changed; preview import again.')
        if not self.store.source(source)['writable']: raise CalendarError('Calendar is read-only.')
        cal=parsed(data);groups={}
        for event in cal.walk('VEVENT'): groups.setdefault(str(event['UID']),[]).append(event)
        added=0
        with self.store.transaction():
            for uid,events in groups.items():
                if self.store.db.execute('SELECT 1 FROM events WHERE source=? AND uid=?',(source,uid)).fetchone(): continue
                if self.store.db.execute('SELECT count(*) FROM events').fetchone()[0]>=MAX_EVENTS: raise CalendarError('Local series limit reached.')
                single=calendar_for(events)
                for component in cal.subcomponents:
                    if component.name=='VTIMEZONE': single.add_component(component)
                self.store.db.execute('INSERT INTO events(source,uid,ics,revision,dirty) VALUES(?,?,?,?,?)',(source,uid,single.to_ical().decode(),1,int(self.store.source(source)['provider']!='local')));added+=1
        return dict(imported=added)
    def batch_preview(self,data,source):
        text(data,24000)
        if len(data.encode())>24000: raise CalendarError('Paste up to 24 KiB of schedule data.')
        calendar=self.store.source(source)
        if not calendar['writable']: raise CalendarError('Choose a writable calendar.')
        data=data.lstrip('\ufeff')
        delimiter='\t' if '\t' in data.split('\n',1)[0] else ','
        try:
            reader=csv.DictReader(io.StringIO(data),delimiter=delimiter,strict=True)
            headers=[str(h).strip().lower().replace(' ','_') for h in (reader.fieldnames or [])]
            allowed={'date','title','start','end','end_date','notes','link','location','reminder','repeat','count','interval','kind'}
            if not {'date','title'}.issubset(headers): raise CalendarError('Include a header row with date and title. Optional columns: start, end, notes, link, kind, reminder, repeat, count, interval, end_date, location.')
            if len(headers)!=len(set(headers)) or any(h not in allowed for h in headers): raise CalendarError('Column names are duplicated or unsupported. Use the format guide.')
            reader.fieldnames=headers;events={};errors=[];rows=0;prefs=self.preferences()
            for index,row in enumerate(reader,2):
                if not any(v for v in row.values()): continue
                rows+=1
                if rows>200: raise CalendarError('Import up to 200 rows at a time.')
                try:
                    if None in row or any(v is None for v in row.values()): raise CalendarError('The number of cells does not match the header. Quote notes containing commas.')
                    row={k:v.strip() for k,v in row.items()}
                    day=row['date'];last=row.get('end_date') or day
                    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}',day) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}',last): raise CalendarError('Use dates in YYYY-MM-DD format.')
                    kind=row.get('kind') or 'event'
                    if kind not in ('event','note'): raise CalendarError('Kind must be event or note.')
                    start=row.get('start','');end=row.get('end','')
                    if bool(start)!=bool(end): raise CalendarError('Supply both start and end times, or leave both blank for an all-day item.')
                    if start and (kind=='note' or not all(re.fullmatch(r'(?:[01]\d|2[0-3]):[0-5]\d',v) for v in (start,end))): raise CalendarError('Times must be HH:MM; dated notes have no time.')
                    reminder=row.get('reminder') or ('' if kind=='note' else prefs['defaultReminder'])
                    if reminder.lower()=='none': reminder=''
                    uid='batch-'+hashlib.sha256(json.dumps(dict(row,source=source),sort_keys=True,ensure_ascii=False).encode()).hexdigest()+'@senomyos'
                    form=dict(title=row['title'],kind=kind,notes=row.get('notes',''),url=row.get('link',''),location=row.get('location',''),start=day+('T'+start if start else ''),end=last+('T'+end if end else ''),allDay=not start,timezone=prefs['timezone'],reminder=reminder,frequency=(row.get('repeat') or 'NONE').upper(),count=row.get('count',''),interval=row.get('interval') or '1')
                    events[uid]=self.build_event(form,uid)
                except (CalendarError,ValueError,TypeError) as error:
                    errors.append('Row '+str(index)+': '+(str(error) if isinstance(error,CalendarError) else 'Enter valid dates, times and repeat/reminder numbers.'))
            if errors: raise CalendarError('Fix these rows before importing:\n'+'\n'.join(errors[:10]))
            if not events: raise CalendarError('Add at least one schedule row beneath the header.')
        except csv.Error: raise CalendarError('CSV could not be read. Check quotation marks and column separators.') from None
        existing={r[0] for r in self.store.db.execute('SELECT uid FROM events WHERE source=?',(source,))}
        duplicates=len(existing.intersection(events));data=calendar_for(events.values()).to_ical().decode()
        return dict(token=self.preview('import',(source,data,self.store.revision)),count=len(events),duplicates=duplicates,rows=rows,
                    titles=[str(e.get('SUMMARY','')) for e in list(events.values())[:20]],
                    items=[dict(title=str(e.get('SUMMARY','')),start=e['DTSTART'].dt.isoformat(),kind=str(e.get('X-SENOMY-KIND','event'))) for e in list(events.values())[:5]],
                    impact=f"Add {len(events)-duplicates} items to {calendar['name']}. {rows-len(events)+duplicates} identical rows will be skipped. Saved items are left unchanged.",
                    policy='Local import only. No invitations or automatic remote sync. Identical normalized rows are skipped on repeat imports.')

    def export_preview(self,path,source):
        self.store.source(source);p=Path(path).expanduser()
        if p.suffix.lower()!='.ics' or p.is_symlink() or not p.parent.is_dir() or (p.exists() and not p.is_file()): raise CalendarError('Choose a regular .ics file in an existing folder.')
        return dict(token=self.preview('export',(str(p),source,self.store.revision,(p.stat().st_ino,p.stat().st_mtime_ns,p.stat().st_size) if p.exists() else None)),impact='Export all personal event contents in this calendar'+(' and overwrite the existing file' if p.exists() else ''))
    def export_confirm(self,token):
        path,source,revision,fingerprint=self.take_preview(token,'export')
        if self.store.revision!=revision: raise CalendarError('Calendar changed; review export again.')
        cal=calendar_for([])
        for row in self.store.db.execute('SELECT ics FROM events WHERE source=? AND deleted=0',(source,)):
            for component in parsed(row['ics']).subcomponents: cal.add_component(component)
        p=Path(path)
        if p.is_symlink(): raise CalendarError('Destination changed; choose another file.')
        import os
        import tempfile
        current=(p.stat().st_ino,p.stat().st_mtime_ns,p.stat().st_size) if p.exists() else None
        if current!=fingerprint: raise CalendarError('Export destination changed; review export again.')
        fd,temporary=tempfile.mkstemp(prefix='.senomy-export-',dir=p.parent)
        try:
            with os.fdopen(fd,'wb') as output:
                output.write(cal.to_ical());output.flush();os.fsync(output.fileno())
            if fingerprint is None: os.link(temporary,p)
            else: os.replace(temporary,p)
        finally: Path(temporary).unlink(missing_ok=True)
        return dict(state='exported',path=str(p))
