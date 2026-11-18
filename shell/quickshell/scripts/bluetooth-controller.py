#!/usr/bin/env python3
"""One event-driven BlueZ connection for inventory, operations, discovery and agent.

Private line protocol on stdin/stdout; no shell commands, pairing persistence or
raw logs. --snapshot is read-only. A private bus address is test-only via env.
"""
import json
import os
import signal
import sys
import time
try:
    from gi.repository import Gio, GLib
except ImportError:
    print(json.dumps({'type':'state','state':{'available':False,'error':'Bluetooth requires python-gobject with Gio. The dependency is unavailable.','adapters':[],'devices':[],'operations':{},'scan':{'state':'idle','owned':False},'prompt':None}}),flush=True)
    raise SystemExit(3)
from bluetooth_model import Controller, ADAPTER, DEVICE, BATTERY, ACTIVE

AGENT_XML = '''<node><interface name="org.bluez.Agent1">
<method name="Release"/><method name="Cancel"/>
<method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
<method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
<method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
<method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
<method name="RequestAuthorization"><arg type="o" direction="in"/></method>
<method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
</interface></node>'''


class Backend:
    agent_path = '/org/senomyos/BluetoothAgent'

    def __init__(self, snapshot_only=False):
        self.snapshot_only = snapshot_only
        self.loop = GLib.MainLoop()
        self.model = Controller(self.call, self.schedule)
        self.prompt = None
        self.invocation = None
        self.prompt_counter = 0
        self.agent_registered = ''
        self.pending_emit = 0
        self.tick_source = 0
        self.stopping = False
        self.last_output = ''
        address = os.environ.get('SENOMY_BLUETOOTH_TEST_BUS') or Gio.dbus_address_get_for_bus_sync(Gio.BusType.SYSTEM, None)
        # Own connection: scan ownership and the application agent never share a
        # caller with another process or Quickshell's native Bluetooth singleton.
        self.bus = Gio.DBusConnection.new_for_address_sync(address,
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, None, None)
        self.manager = Gio.DBusObjectManagerClient.new_sync(self.bus,
            Gio.DBusObjectManagerClientFlags.DO_NOT_AUTO_START, 'org.bluez', '/', None, None, None)
        self.manager.connect('object-added', self.object_added)
        self.manager.connect('object-removed', lambda *_: self.refresh())
        self.manager.connect('interface-added', lambda *_: self.refresh())
        self.manager.connect('interface-removed', lambda *_: self.refresh())
        self.manager.connect('interface-proxy-properties-changed', self.properties_changed)
        self.manager.connect('interface-proxy-signal', self.proxy_signal)
        self.manager.connect('notify::name-owner', self.owner_changed)
        self.agent_registration = 0
        self.refresh()
        self.last_tick = time.monotonic()

    def objects(self):
        result = {}
        for obj in self.manager.get_objects():
            interfaces = {}
            for proxy in obj.get_interfaces():
                name = proxy.get_interface_name()
                if name not in (ADAPTER, DEVICE, BATTERY, 'org.bluez.Input1'):
                    continue
                # Deliberately omit manufacturer payloads, service data, logs.
                keys = ('Alias','Name','Address','AddressType','Icon','Adapter','Paired','Bonded','Trusted',
                        'Blocked','Connected','ServicesResolved','UUIDs','Powered','PowerState','Discovering',
                        'Discoverable','Pairable','Percentage','Class','Appearance','Modalias','LegacyPairing','WakeAllowed','RSSI','TxPower','ReconnectMode')
                interfaces[name] = {key: proxy.get_cached_property(key).unpack() for key in keys if proxy.get_cached_property(key) is not None}
            if interfaces:
                result[obj.get_object_path()] = interfaces
        return result

    def owner_changed(self, *_):
        self.agent_registered = ''
        self.reject_prompt('The Bluetooth service changed.')
        self.refresh()

    def object_added(self, manager, obj):
        proxy = obj.get_interface(DEVICE)
        observed = proxy is not None and proxy.get_cached_property('RSSI') is not None and bool(self.model.owner) and manager.get_name_owner() == self.model.owner
        self.refresh((obj.get_object_path(),) if observed else ())

    def proxy_signal(self, manager, obj, proxy, sender, name, parameters):
        if proxy.get_interface_name() == DEVICE and name == 'Disconnected' and sender == self.model.owner:
            reason, message = parameters.unpack()
            self.model.disconnections[obj.get_object_path()] = {'reason':reason[:180], 'message':message[:300], 'at':int(time.time()*1000)}
            self.schedule()

    def properties_changed(self, manager, obj, proxy, changed, invalidated):
        keys = changed.unpack()
        fresh = (obj.get_object_path(),) if any(key in keys for key in ('RSSI','TxPower')) else ()
        self.refresh(fresh)

    def refresh(self, fresh=()):
        owner = self.manager.get_name_owner() or ''
        objects = self.objects()
        if owner != self.model.owner:
            self.model.provider(owner, objects)
        else:
            self.model.update(objects, fresh)
        if self.prompt and (not self.model.context or self.prompt['path'] not in objects):
            self.reject_prompt('The pairing view or device closed.')
        if self.prompt:
            op = self.model.operations.get(self.prompt['path'], {})
            if op.get('phase') not in ACTIVE:
                self.reject_prompt('The pairing operation ended.')

    def schedule(self):
        if self.snapshot_only or self.stopping:
            return
        if not self.pending_emit:
            self.pending_emit = GLib.timeout_add(35, self.emit)
        needs_tick = any(self.model.clock()-seen < 45 for seen in self.model.seen.values()) or bool(self.prompt) or any(op['phase'] in ACTIVE for op in self.model.operations.values()) or self.model.scan['state'] in ('starting','running','stopping')
        if needs_tick and not self.tick_source:
            self.tick_source = GLib.timeout_add(250, self.tick)

    def snapshot(self):
        result = self.model.snapshot()
        result['prompt'] = {k:v for k,v in self.prompt.items() if k != 'deadline'} if self.prompt else None
        return result

    def emit(self):
        self.pending_emit = 0
        value = json.dumps({'type': 'state', 'state': self.snapshot()}, separators=(',', ':'), ensure_ascii=True)
        if value != self.last_output:
            try:
                print(value, flush=True)
            except BrokenPipeError:
                self.close()
                return False
            self.last_output = value
        return False

    def tick(self):
        self.model.tick()
        if self.prompt and self.model.clock() >= self.prompt['deadline']:
            path = self.prompt['path']
            self.reject_prompt('Pairing approval timed out.')
            self.model.cancel(path, timed_out=True)
        active = any(self.model.clock()-seen < 45 for seen in self.model.seen.values()) or bool(self.prompt) or any(op['phase'] in ACTIVE for op in self.model.operations.values()) or self.model.scan['state'] in ('starting','running','stopping')
        if not active:
            self.tick_source = 0
        return active

    def dbus_call(self, path, interface, method, parameters, done, timeout=12000):
        owner = self.model.owner
        if not owner:
            done('org.freedesktop.DBus.Error.NameHasNoOwner', 'BlueZ is unavailable')
            return
        def finished(bus, result):
            name = detail = ''
            try:
                bus.call_finish(result)
            except GLib.Error as error:
                name = Gio.DBusError.get_remote_error(error) or 'org.freedesktop.DBus.Error.Failed'
                detail = error.message
                # Keep only bounded method error text, never pairing input.
                if ': ' in detail: detail = detail.split(': ', 1)[-1]
            if owner == self.model.owner:
                self.refresh()
                done(name, detail[:400])
        self.bus.call(owner, path, interface, method, parameters, None,
                      Gio.DBusCallFlags.NO_AUTO_START, timeout, None, finished)

    def call(self, op, stage, callback):
        path, action, ident = op['path'], op['action'], op['id']
        def done(name='', detail=''):
            callback(path, ident, stage, name, detail)
            if action == 'pair':
                current = self.model.operations.get(path, {})
                if current.get('id') == ident and current.get('phase') not in ACTIVE:
                    self.reject_prompt('Pairing ended.')
        if action == 'pair' and stage == 'start' and self.agent_registered != self.model.owner:
            if not self.agent_registration:
                info = Gio.DBusNodeInfo.new_for_xml(AGENT_XML).interfaces[0]
                self.agent_registration = self.bus.register_object(self.agent_path, info, self.agent_call, None, None)
            def registered(name, detail):
                if name:
                    done(name, detail)
                    return
                self.agent_registered = self.model.owner
                current = self.model.operations.get(path, {})
                if current.get('id') != ident or current.get('phase') != 'running':
                    done('org.bluez.Error.Canceled', 'Pairing cancelled before agent registration')
                    return
                self.dbus_call(path, DEVICE, 'Pair', None, done, 100000)
            self.dbus_call('/org/bluez', 'org.bluez.AgentManager1', 'RegisterAgent', GLib.Variant('(os)', (self.agent_path, 'KeyboardDisplay')), registered)
            return
        if action in ('connect','pair','disconnect'):
            method = ('Disconnect' if action == 'connect' else 'CancelPairing') if stage == 'cleanup' else {'connect':'Connect','pair':'Pair','disconnect':'Disconnect'}[action]
            if stage == 'cleanup' and self.prompt and self.prompt['path'] == path:
                self.reject_prompt('Pairing cancelled.')
            self.dbus_call(path, DEVICE, method, None, done, 100000 if stage == 'start' and action == 'pair' else 45000 if stage == 'start' and action == 'connect' else 12000)
        elif action in ('forget','remove'):
            self.dbus_call(op['adapter'], ADAPTER, 'RemoveDevice', GLib.Variant('(o)', (path,)), done)
        elif action == 'scan':
            self.dbus_call(path, ADAPTER, 'StopDiscovery' if stage == 'cleanup' else 'StartDiscovery', None, done)
        else:
            interface = ADAPTER if action in ('enable','disable','pairable','discoverable') else DEVICE
            key = {'enable':'Powered','disable':'Powered','trust':'Trusted','untrust':'Trusted',
                   'block':'Blocked','unblock':'Blocked','rename':'Alias','pairable':'Pairable','discoverable':'Discoverable','wake':'WakeAllowed'}[action]
            value = op['value'] if action in ('rename','pairable','discoverable','wake') else action in ('enable','trust','block')
            params = GLib.Variant('(ssv)', (interface, key, GLib.Variant('s' if action == 'rename' else 'b', value)))
            if action in ('discoverable','pairable') and value:
                # Explicitly bounded visibility; never turn either on permanently.
                timeout_key = 'DiscoverableTimeout' if action == 'discoverable' else 'PairableTimeout'
                self.dbus_call(path, 'org.freedesktop.DBus.Properties', 'Set',
                    GLib.Variant('(ssv)', (interface, timeout_key, GLib.Variant('u',180))),
                    lambda name, detail: done(name,detail) if name else self.dbus_call(path,'org.freedesktop.DBus.Properties','Set',params,done) if self.model.operations.get(path,{}).get('id') == ident and self.model.operations[path]['phase'] == 'running' else None)
            else:
                self.dbus_call(path, 'org.freedesktop.DBus.Properties', 'Set', params, done)

    def agent_call(self, connection, sender, path, interface, method, parameters, invocation):
        if sender != self.model.owner:
            invocation.return_dbus_error('org.bluez.Error.Rejected', 'Unrecognized caller')
            return
        if method in ('Cancel','Release'):
            self.reject_prompt('BlueZ cancelled authentication.')
            if method == 'Release': self.agent_registered = ''
            invocation.return_value(None)
            return
        args = parameters.unpack()
        device = args[0]
        op = self.model.operations.get(device, {})
        if not self.model.context or op.get('action') != 'pair' or op.get('phase') != 'running':
            invocation.return_dbus_error('org.bluez.Error.Rejected', 'No explicit pairing request is active')
            return
        if self.invocation:
            invocation.return_dbus_error('org.bluez.Error.Rejected', 'Another authentication decision is pending')
            return
        self.prompt_counter += 1
        self.prompt = {'id':str(self.prompt_counter), 'path':device, 'kind':method,
                       'name':self.model.state(device).get('Alias') or 'Bluetooth device', 'code':'',
                       'entered':0, 'deadline':self.model.clock()+45}
        if method in ('DisplayPasskey','RequestConfirmation'):
            self.prompt['code'] = f'{args[1]:06d}'
            if method == 'DisplayPasskey': self.prompt['entered'] = args[2]
        elif method == 'DisplayPinCode':
            self.prompt['code'] = args[1]
        elif method == 'AuthorizeService':
            self.prompt['service'] = args[1]
        if method in ('DisplayPinCode','DisplayPasskey'):
            invocation.return_value(None)
            self.invocation = None
        else:
            self.invocation = invocation
        self.schedule()

    def reject_prompt(self, reason):
        if self.invocation:
            self.invocation.return_dbus_error('org.bluez.Error.Canceled', reason)
        self.invocation = None
        self.prompt = None
        self.schedule()

    def answer(self, request):
        if not self.prompt or self.prompt['id'] != request.get('id'):
            return
        if type(request.get('accept')) is not bool:
            return
        if not request['accept']:
            path = self.prompt['path']
            self.reject_prompt('Pairing rejected by the user.')
            self.model.cancel(path)
            return
        if not self.invocation:
            return
        kind, value = self.prompt['kind'], request.get('value','')
        if kind == 'RequestPasskey':
            if not isinstance(value,str) or not value.isascii() or not value.isdigit() or len(value) > 6 or len(value) < 1:
                return
            self.invocation.return_value(GLib.Variant('(u)', (int(value),)))
        elif kind == 'RequestPinCode':
            if not isinstance(value,str) or not 1 <= len(value) <= 16 or any(ord(c)<32 for c in value):
                return
            self.invocation.return_value(GLib.Variant('(s)', (value,)))
        else:
            self.invocation.return_value(None)
        self.invocation = None
        self.prompt = None
        self.schedule()

    def handle(self, request):
        if not isinstance(request,dict): return
        verb = request.get('command')
        if verb == 'request':
            ok, message = self.model.request(request)
            print(json.dumps({'type':'ack','requestId':request.get('requestId'), 'ok':ok,'message':message}),flush=True)
        elif verb == 'cancel':
            op = self.model.operations.get(request.get('path'), {})
            if op.get('id') == request.get('id'): self.model.cancel(op['path'])
        elif verb == 'context': self.model.set_context(request.get('active') is True)
        elif verb == 'scan': self.model.start_scan(request.get('path'))
        elif verb == 'stopScan': self.model.stop_scan()
        elif verb == 'refresh': self.refresh()
        elif verb == 'answer': self.answer(request)
        self.schedule()

    def input_ready(self, fd, condition):
        if condition & (GLib.IO_HUP | GLib.IO_ERR):
            self.close()
            return False
        try:
            data = os.read(fd, 16384)
        except BlockingIOError:
            return True
        if not data:
            self.close()
            return False
        self.buffer += data
        if len(self.buffer) > 65536:
            self.close()
            return False
        while b'\n' in self.buffer:
            line, self.buffer = self.buffer.split(b'\n',1)
            try:
                self.handle(json.loads(line))
            except (ValueError, TypeError, KeyError):
                print(json.dumps({'type':'protocolError','message':'Invalid Bluetooth request.'}),flush=True)
        return True

    def close(self):
        if self.stopping: return
        self.stopping = True
        self.reject_prompt('Bluetooth interface closed.')
        # Closing this bus releases only our discovery and scoped agent. Existing
        # device connections are deliberately left untouched.
        self.bus.close_sync(None)
        self.loop.quit()

    def run(self):
        self.buffer = b''
        os.set_blocking(sys.stdin.fileno(), False)
        GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self.input_ready)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, lambda: self.close() or False)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, lambda: self.close() or False)
        self.emit()
        self.loop.run()


def main():
    try:
        backend = Backend(snapshot_only='--snapshot' in sys.argv)
        if backend.snapshot_only:
            print(json.dumps(backend.snapshot(),separators=(',',':')))
        else:
            backend.run()
    except (GLib.Error, OSError) as error:
        print(json.dumps({'type':'state','state':{'available':False,'error':'Bluetooth D-Bus connection is unavailable. Reopen Bluetooth to retry.',
              'adapters':[],'devices':[],'operations':{},'scan':{'state':'idle','owned':False},'prompt':None}}),flush=True)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
