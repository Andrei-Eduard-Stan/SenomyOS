"""One per-user calendar owner: private typed socket and independent alarms."""
import argparse
import asyncio
import fcntl
import json
import os
from pathlib import Path
import socket
import struct
import time
from dbus_next import Message,MessageType,Variant,BusType
from dbus_next.aio import MessageBus
from .engine import Engine,CalendarError,FieldErrors
from .reminders import Reminders
from .remote import Remote
from .store import StoreError

class Server:
 def __init__(self,state,runtime,test_mode=False):
  self.state=Path(state);self.runtime=Path(runtime);self.runtime.mkdir(mode=0o700,parents=True,exist_ok=True)
  self.lock=open(self.runtime/'calendar.lock','a');os.chmod(self.runtime/'calendar.lock',0o600);fcntl.flock(self.lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
  self.engine=Engine(state);self.reminders=Reminders(self.engine);self.remote=Remote(self.engine,test_mode);self.clients=set();self.bus=None;self.closed=False;self.gate=asyncio.Lock();self.health_error=''
 async def broadcast(self,kind='changed',**values):
  message=json.dumps(dict(type=kind,**values),ensure_ascii=False)+'\n'
  for writer in list(self.clients):
   try: writer.write(message.encode());await writer.drain()
   except (ConnectionError,RuntimeError): self.clients.discard(writer)
 def dispatch(self,operation,args,identifier):
  e=self.engine
  if operation=='snapshot': return dict(e.snapshot(),healthError=self.health_error)
  if operation=='query': return e.query(args['start'],args['end'],args.get('search',''),args.get('source',''))
  if operation=='detail': return e.detail(args['source'],args['uid'],args.get('rid',''))
  if operation=='save': return e.save(args,identifier)
  if operation=='draftSave': return e.draft_save(args)
  if operation=='draftGet': return e.draft_get()
  if operation=='draftDiscard': return e.draft_discard()
  if operation=='deletePreview': return e.delete_preview(args['source'],args['uid'],args.get('rid',''),args.get('scope','series'))
  if operation=='deleteConfirm': return e.delete(args['token'])
  if operation=='sourceSave': return e.source_save(args)
  if operation=='sourceDeletePreview': return e.source_delete_preview(args['source'])
  if operation=='sourceDeleteConfirm': return e.source_delete(args['token'])
  if operation=='preferencesSave': return e.prefs_save(args)
  if operation=='importPreview': return e.import_preview(args['path'],args['source'])
  if operation=='batchPreview': return e.batch_preview(args['data'],args['source'])
  if operation=='batchConfirm': return e.import_confirm(args['token'])
  if operation=='importConfirm': return e.import_confirm(args['token'])
  if operation=='exportPreview': return e.export_preview(args['path'],args['source'])
  if operation=='exportConfirm': return e.export_confirm(args['token'])
  if operation=='reminderAction': return self.reminders.action(args['key'],args['action'],args.get('minutes',10))
  if operation=='accountAdd': return self.remote.account_add(args)
  if operation=='syncPreview': return self.remote.sync_preview(args['source'])
  if operation=='syncConfirm': return self.remote.sync_confirm(args['token'])
  if operation=='conflictPreview': return self.remote.resolve_preview(args['source'],args['uid'],args['choice'])
  if operation=='conflictConfirm': return self.remote.resolve(args['token'])
  raise CalendarError('Unknown calendar operation.')
 async def handle(self,reader,writer):
  transport_socket=writer.get_extra_info('socket')
  if transport_socket and hasattr(socket,'SO_PEERCRED'):
   _,uid,_=struct.unpack('3i',transport_socket.getsockopt(socket.SOL_SOCKET,socket.SO_PEERCRED,12))
   if uid!=os.getuid(): writer.close();return
  self.clients.add(writer)
  try:
   while data:=await reader.readline():
    identifier='';operation='';args={}
    try:
     if len(data)>65536: raise CalendarError('Request exceeds 64 KiB.')
     message=json.loads(data);identifier=message['id'];operation=message['operation'];args=message.get('args',{})
     if not isinstance(identifier,str) or len(identifier)>100 or not isinstance(args,dict): raise CalendarError('Malformed calendar request.')
     async with self.gate: result=await asyncio.to_thread(self.dispatch,operation,args,identifier)
     response=dict(id=identifier,ok=True,result=result)
    except FieldErrors as error: response=dict(id=identifier,ok=False,error=str(error),fieldErrors=error.fields)
    except (CalendarError,StoreError,ValueError) as error: response=dict(id=identifier,ok=False,error=str(error) if isinstance(error,(CalendarError,StoreError)) else 'Invalid date, timezone or calendar fields.')
    except Exception:
     response=dict(id=identifier,ok=False,error='Calendar request failed. Check service availability or account credentials; local data is retained.')
    writer.write((json.dumps(response,ensure_ascii=False)+'\n').encode());await writer.drain()
    if operation not in ['snapshot','query','detail','draftSave','draftGet','draftDiscard'] and response['ok']:
     async with self.gate: await asyncio.to_thread(self.reminders.reconcile)
     await self.broadcast()
  except (ConnectionError,ValueError,asyncio.LimitOverrunError): pass
  finally:
   self.clients.discard(writer);writer.close()
   try: await writer.wait_closed()
   except ConnectionError: pass
 async def notify(self,alarm):
  if not self.bus:
   try:
    self.bus=await MessageBus(bus_type=BusType.SESSION).connect();self.bus.add_message_handler(self.action_signal)
    await self.bus.call(Message(destination='org.freedesktop.DBus',path='/org/freedesktop/DBus',interface='org.freedesktop.DBus',member='AddMatch',signature='s',body=["type='signal',interface='org.freedesktop.Notifications',member='ActionInvoked'"]))
   except Exception: self.bus=None;return
  # Do not activate a notification daemon when no renderer/fallback owns the bus.
  owner=await self.bus.call(Message(destination='org.freedesktop.DBus',path='/org/freedesktop/DBus',interface='org.freedesktop.DBus',member='GetNameOwner',signature='s',body=['org.freedesktop.Notifications']))
  if owner.message_type==MessageType.ERROR: return
  unique=owner.body[0];token=self.reminders.delivery_started(alarm['key'])
  actions=['open:'+token,'Open event','snooze:'+token,'Snooze 10 min','dismiss:'+token,'Dismiss reminder']
  reply=await self.bus.call(Message(destination=unique,path='/org/freedesktop/Notifications',interface='org.freedesktop.Notifications',member='Notify',signature='susssasa{sv}i',body=['Senomy Calendar',0,'appointment-soon',alarm['title'][:200],'Calendar reminder',actions,{'desktop-entry':Variant('s','senomy-calendar'),'urgency':Variant('y',1),'resident':Variant('b',True)},0]))
  if reply.message_type==MessageType.ERROR: self.reminders.failed(alarm['key']);return
  self.reminders.delivered(alarm['key'],reply.body[0],unique)
 async def perform_signal(self,row,action):
  if action=='open': await self.broadcast('openEvent',source=row['source'],uid=row['uid'],rid=row['occurrence'])
  else: self.reminders.action(row['key'],'snooze' if action=='snooze' else 'dismiss');await self.broadcast()
 def action_signal(self,message):
  if message.message_type!=MessageType.SIGNAL or message.interface!='org.freedesktop.Notifications' or message.member!='ActionInvoked' or len(message.body)!=2: return
  native_id,action=message.body;parts=str(action).split(':')
  if len(parts)!=2 or parts[0] not in ['open','snooze','dismiss']: return
  asyncio.create_task(self.match_signal(native_id,message.sender,parts[1],parts[0]))
 async def match_signal(self,native_id,sender,token,action):
  async with self.gate:
   row=self.engine.store.db.execute('SELECT * FROM alarms WHERE native_id=? AND owner=? AND action_token=? AND status=\'notified\'',(native_id,sender,token)).fetchone()
   if row: await self.perform_signal(dict(row),action)
 async def tick(self):
  while not self.closed:
   try:
    async with self.gate:
     await asyncio.to_thread(self.reminders.reconcile);alarms=self.reminders.due()
    for alarm in alarms:
     async with self.gate:
      current=self.engine.store.db.execute('SELECT * FROM alarms WHERE key=? AND status IN (\'scheduled\',\'snoozed\')',(alarm['key'],)).fetchone()
      if current: await asyncio.wait_for(self.notify(dict(current)),5)
    self.health_error=''
    await self.broadcast()
   except Exception:
    self.health_error='Reminder delivery needs attention; saved events and alarm history are retained.'
    await self.broadcast()
   await asyncio.sleep(30)
 async def run(self):
  path=self.runtime/'calendar.sock'
  if path.exists(): path.unlink()
  server=await asyncio.start_unix_server(self.handle,str(path),limit=65537);os.chmod(path,0o600)
  tick=asyncio.create_task(self.tick())
  try:
   async with server: await server.serve_forever()
  finally: self.closed=True;tick.cancel();path.unlink(missing_ok=True)

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--state',default=str(Path(os.environ.get('XDG_STATE_HOME',Path.home()/'.local/state'))/'senomyos/calendar'));parser.add_argument('--runtime',default=str(Path(os.environ.get('XDG_RUNTIME_DIR','/tmp'))/('senomyos-calendar-'+str(os.getuid()))));parser.add_argument('--test-mode',action='store_true');args=parser.parse_args();os.umask(0o077)
 try: asyncio.run(Server(args.state,args.runtime,args.test_mode).run())
 except (KeyboardInterrupt,BlockingIOError): pass

if __name__=='__main__': main()
