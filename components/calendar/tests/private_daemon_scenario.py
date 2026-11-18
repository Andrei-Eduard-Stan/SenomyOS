"""Runs exclusively under the test's private D-Bus and XDG directories."""
import asyncio,json,os,tempfile
from datetime import datetime,timedelta,timezone
from pathlib import Path
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface,method,signal
from senomy_calendar.daemon import Server
from senomy_calendar.engine import Engine

class Notifications(ServiceInterface):
 def __init__(self):super().__init__('org.freedesktop.Notifications');self.calls=[]
 @method()
 def Notify(self,app:'s',replace:'u',icon:'s',title:'s',body:'s',actions:'as',hints:'a{sv}',expiry:'i')->'u':
  self.calls.append(dict(title=title,actions=actions));return len(self.calls)
 @signal()
 def ActionInvoked(self,identifier:'u',action:'s')->'us':return [identifier,action]

async def scenario():
 root=Path(os.environ['XDG_STATE_HOME']);runtime=Path(os.environ['XDG_RUNTIME_DIR'])/'senomyos-calendar'
 server=Server(root,runtime);server.engine.clock=lambda:1791720000
 service_task=asyncio.create_task(server.run())
 for _ in range(100):
  if (runtime/'calendar.sock').exists():break
  await asyncio.sleep(.01)
 assert (runtime/'calendar.sock').stat().st_mode&0o777==0o600
 try:Server(root,runtime);raise AssertionError('second owner was allowed')
 except BlockingIOError:pass
 reader,writer=await asyncio.open_unix_connection(runtime/'calendar.sock');counter=0
 async def request(op,args={}):
  nonlocal counter
  counter+=1;identifier=str(counter);writer.write((json.dumps(dict(id=identifier,operation=op,args=args))+'\n').encode());await writer.drain()
  while True:
   response=json.loads(await asyncio.wait_for(reader.readline(),5))
   if response.get('id')==identifier:return response
 assert not (await request('arbitraryShell',{}))['ok']
 invalid=await request('save',dict(source='personal',title='',start='bad',end='bad',reminder='1 week before'))
 assert not invalid['ok'] and {'title','start','end','reminder'}<=set(invalid['fieldErrors'])
 assert (await request('snapshot'))['result']['eventCount']==0
 form=dict(source='personal',uid='private@senomyos',title='Closed UI alarm',start='2026-10-11T12:00',end='2026-10-11T13:00',timezone='UTC',reminder='0')
 # Explicit clock set to this civil instant; no renderer exists.
 server.engine.clock=lambda:datetime(2026,10,11,12,tzinfo=timezone.utc).timestamp()
 assert (await request('save',form))['ok']
 await request('snapshot')
 alarm=server.reminders.due()[0]
 # No native owner: daemon does not claim the bus or mark delivered.
 await server.notify(alarm);assert server.reminders.due()
 native_bus=await MessageBus().connect();native=Notifications();native_bus.export('/org/freedesktop/Notifications',native);await native_bus.request_name('org.freedesktop.Notifications')
 await server.notify(alarm);assert len(native.calls)==1;assert not server.reminders.due()
 row=dict(server.engine.store.db.execute('SELECT * FROM alarms').fetchone());valid=native.calls[0]['actions'][2]
 # Wrong owner and wrong nonce have no effect, even when IDs match.
 await server.match_signal(1,':999.invalid',row['action_token'],'snooze');assert server.engine.store.db.execute('SELECT status FROM alarms').fetchone()[0]=='notified'
 native.ActionInvoked(1,'snooze:stale');await asyncio.sleep(.1);assert server.engine.store.db.execute('SELECT status FROM alarms').fetchone()[0]=='notified'
 native.ActionInvoked(1,valid);await asyncio.sleep(.1);assert server.engine.store.db.execute('SELECT status FROM alarms').fetchone()[0]=='snoozed'
 assert (await request('snapshot'))['result']['eventCount']==1
 # CLI preview never saves; explicit confirmation and duplicate replay use typed requests.
 helper=Path(__file__).resolve().parents[3]/'scripts/senomy-calendar-batch'
 data='date,title,notes,kind\n2026-10-20,CLI note,Remember documentation,note\n'
 async def run_cli(*options):
  process=await asyncio.create_subprocess_exec(str(helper),*options,stdin=asyncio.subprocess.PIPE,stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.PIPE)
  stdout,stderr=await process.communicate(data.encode());assert process.returncode==0,stderr.decode();return json.loads(stdout)
 assert (await run_cli())['state']=='preview-only'
 assert (await request('snapshot'))['result']['eventCount']==1
 assert (await run_cli('--confirm'))['result']['imported']==1
 assert (await run_cli('--confirm'))['result']['imported']==0
 assert (await request('snapshot'))['result']['eventCount']==2
 writer.close();await writer.wait_closed();service_task.cancel()
 try:await service_task
 except asyncio.CancelledError:pass
 if server.bus:server.bus.disconnect()
 server.engine.store.db.close();server.lock.close()
 # Closed-renderer and daemon restart retain a snooze; no duplicate delivery.
 restarted=Server(root,runtime);restarted.engine.clock=server.engine.clock;restarted.reminders.reconcile();assert not restarted.reminders.due()
 # An ambiguous crash after Notify began must not automatically resend.
 restarted.reminders.action(row['key'],'snooze',1);restarted.engine.clock=lambda:server.engine.clock()+61
 restarted.reminders.delivery_started(row['key']);restarted.engine.store.db.close();restarted.lock.close()
 again=Server(root,runtime);again.engine.clock=restarted.engine.clock;again.reminders.reconcile();assert not again.reminders.due();assert again.engine.snapshot()['reminders'][0]['status']=='delivery-unconfirmed'
 again.engine.store.db.close();again.lock.close();native_bus.disconnect()
 print('PASS: private socket, single owner, closed UI alarm, native notification delivery, stale action rejection and persistent restart/uncertain delivery')
asyncio.run(scenario())
