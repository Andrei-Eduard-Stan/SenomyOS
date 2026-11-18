"""Disposable status notifier and DBusMenu server, never the user's bus."""
import asyncio,os,sys,tempfile
from dbus_next import Variant,Message,MessageType
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface,method,dbus_property
from dbus_next.constants import PropertyAccess
class StatusItem(ServiceInterface):
 def __init__(self):super().__init__('org.kde.StatusNotifierItem')
 @dbus_property(access=PropertyAccess.READ)
 def Category(self)->'s':return 'ApplicationStatus'
 @dbus_property(access=PropertyAccess.READ)
 def Id(self)->'s':return 'senomy-private-menu-fixture'
 @dbus_property(access=PropertyAccess.READ)
 def Title(self)->'s':return 'Private menu fixture'
 @dbus_property(access=PropertyAccess.READ)
 def Status(self)->'s':return 'Active'
 @dbus_property(access=PropertyAccess.READ)
 def IconName(self)->'s':return 'firefox'
 @dbus_property(access=PropertyAccess.READ)
 def IconPixmap(self)->'a(iiay)':return []
 @dbus_property(access=PropertyAccess.READ)
 def ItemIsMenu(self)->'b':return False
 @dbus_property(access=PropertyAccess.READ)
 def Menu(self)->'o':return '/Menu'
 @dbus_property(access=PropertyAccess.READ)
 def ToolTip(self)->'(sa(iiay)ss)':return ['',[],'Private menu fixture','']
 @method()
 def Activate(self,x:'i',y:'i'):pass
 @method()
 def SecondaryActivate(self,x:'i',y:'i'):pass
 @method()
 def Scroll(self,delta:'i',orientation:'s'):pass
class Menu(ServiceInterface):
 def __init__(self):super().__init__('com.canonical.dbusmenu');self.clicks=[]
 @dbus_property(access=PropertyAccess.READ)
 def Version(self)->'u':return 3
 @dbus_property(access=PropertyAccess.READ)
 def TextDirection(self)->'s':return 'ltr'
 @dbus_property(access=PropertyAccess.READ)
 def Status(self)->'s':return 'normal'
 @dbus_property(access=PropertyAccess.READ)
 def IconThemePath(self)->'as':return []
 def properties(self,id):
  labels={0:'',1:'&Open native window',2:'Disabled native command',3:'Native check',4:'More commands',5:'Nested native command'}
  p={'label':Variant('s',labels[id]),'enabled':Variant('b',id!=2),'visible':Variant('b',True)}
  if id in (0,4):p['children-display']=Variant('s','submenu')
  if id==3:p.update({'toggle-type':Variant('s','checkmark'),'toggle-state':Variant('i',1)})
  return p
 @method()
 def GetLayout(self,parent:'i',depth:'i',names:'as')->'u(ia{sv}av)':
  def node(id,remaining):
   children=([1,2,3,4] if id==0 else [5] if id==4 else []) if remaining!=0 else []
   return [id,self.properties(id),[Variant('(ia{sv}av)',node(child,remaining-1)) for child in children]]
  return [1,node(parent,depth)]
 @method()
 def GetGroupProperties(self,ids:'ai',names:'as')->'a(ia{sv})':return [[id,self.properties(id)] for id in ids]
 @method()
 def AboutToShow(self,id:'i')->'b':return False
 @method()
 def Event(self,id:'i',event:'s',data:'v',timestamp:'u'):
  if event=='clicked':self.clicks.append(id)
async def main():
 bus=await MessageBus().connect();menu=Menu();bus.export('/StatusNotifierItem',StatusItem());bus.export('/Menu',menu)
 logfile=tempfile.TemporaryFile()
 process=await asyncio.create_subprocess_exec('qs','--path',sys.argv[1],'--no-color',stdout=logfile,stderr=asyncio.subprocess.STDOUT)
 try:
  for _ in range(100):
   result=await bus.call(Message(destination='org.kde.StatusNotifierWatcher',path='/StatusNotifierWatcher',interface='org.kde.StatusNotifierWatcher',member='RegisterStatusNotifierItem',signature='s',body=[bus.unique_name]))
   if result.message_type!=MessageType.ERROR:break
   await asyncio.sleep(.03)
  await asyncio.wait_for(process.wait(),20)
  assert process.returncode==0
  assert menu.clicks==[5],menu.clicks
  print('PASS: native DBusMenu server received exactly one clicked event for the selected nested command')
 finally:
  if process.returncode is None:process.terminate();await process.wait()
  logfile.seek(0);print(logfile.read().decode());logfile.close()
  bus.disconnect()
asyncio.run(main())
