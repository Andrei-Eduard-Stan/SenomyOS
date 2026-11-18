"""Bluetooth transactions independent of D-Bus and presentation.

Transport calls are asynchronous. Every completion is generation + incarnation
checked; only observed properties establish the requested final state.
"""
import re
import time
import uuid

def boottime():
    return time.clock_gettime(time.CLOCK_BOOTTIME) if hasattr(time,'CLOCK_BOOTTIME') else time.monotonic()


ADAPTER = 'org.bluez.Adapter1'
DEVICE = 'org.bluez.Device1'
BATTERY = 'org.bluez.Battery1'
ACTIVE = {'running', 'cancelling'}
TIMEOUTS = {'connect': 30, 'pair': 90, 'disconnect': 15, 'forget': 10,
            'enable': 12, 'disable': 12, 'trust': 8, 'untrust': 8,
            'block': 8, 'unblock': 8, 'rename': 8, 'discoverable': 8,
            'pairable': 8, 'remove': 10, 'wake': 8}


def error_message(name, detail):
    text = (name + ' ' + detail).lower()
    if 'page-timeout' in text:
        return 'The device did not answer the Bluetooth connection request. Check that it is awake and nearby, and whether another host is using it.'
    if 'authentication' in text or 'rejected' in text:
        return 'Pairing or authentication was rejected. Check the code and the device’s pairing mode before retrying.'
    if 'notready' in text:
        return 'The Bluetooth adapter is not ready. Check its power and radio-block state.'
    if 'inprogress' in text:
        return 'BlueZ reports another operation in progress for this device. Wait for it to resolve, or cancel the pending attempt.'
    if 'notavailable' in text or 'profile' in text or 'protocol' in text:
        return 'The requested Bluetooth service is unavailable. Inspect the supported services and audio profile.'
    if 'notauthorized' in text or 'accessdenied' in text:
        return 'Bluetooth access was denied by the system. Check the session’s device permissions.'
    if 'canceled' in text or 'cancelled' in text:
        return 'The Bluetooth operation was cancelled.'
    if 'noreply' in text or 'timeout' in text:
        return 'BlueZ did not complete the request in time. Current device state is shown; you can retry.'
    return 'Bluetooth could not complete the request. Inspect the technical details and retry.'


class Controller:
    def __init__(self, call, changed=lambda: None, clock=boottime):
        self.call, self.changed, self.clock = call, changed, clock
        self.objects, self.tokens, self.seen = {}, {}, {}
        self.seen_wall, self.disconnections = {}, {}
        self.operations = {}
        self.owner, self.ready, self.error = '', False, ''
        self.serial = 0
        self.context = False
        self.scan = {'state': 'idle', 'adapter': '', 'message': '', 'owned': False}
        self.scan_generation = 0
        self.epoch = uuid.uuid4().hex

    def provider(self, owner, objects):
        if owner != self.owner:
            for op in self.operations.values():
                if op['phase'] in ACTIVE:
                    self.finish(op, 'failed', 'The BlueZ service changed; the result could not be verified.')
            self.scan_generation += 1
            self.scan = {'state': 'idle', 'adapter': '', 'message': '', 'owned': False}
            self.tokens, self.seen = {}, {}
            self.seen_wall, self.disconnections = {}, {}
            self.owner = owner
        self.ready = bool(owner)
        self.error = '' if owner else 'The BlueZ service is unavailable.'
        self.update(objects)

    def update(self, objects, fresh=()):
        self.objects = objects
        for path in list(self.tokens):
            if path not in objects:
                del self.tokens[path]
                self.seen.pop(path, None)
                self.seen_wall.pop(path, None)
                self.disconnections.pop(path, None)
        for path in objects:
            if path not in self.tokens:
                self.serial += 1
                self.tokens[path] = f'{self.epoch}:{self.serial}'
        for path in fresh:
            if DEVICE in objects.get(path, {}):
                self.seen[path] = self.clock()
                self.seen_wall[path] = int(time.time()*1000)
        for op in list(self.operations.values()):
            if op['phase'] not in ACTIVE:
                continue
            if self.tokens.get(op['path']) != op['token'] or self.tokens.get(op['adapter']) != op['adapterToken']:
                # Removal is the observed completion of Forget, only for this incarnation.
                if op['action'] in ('forget','remove') and op['path'] not in objects:
                    self.finish(op, 'succeeded', 'Pairing and cached device information were removed.')
                else:
                    self.finish(op, 'failed', 'The device or adapter disappeared; the result could not be verified.')
            else:
                self.reconcile(op)
        # An adapter removal ends its discovery session. Do not retain an old
        # lease/token and permanently block scans on a replacement at this path.
        if self.scan.get('adapter') and self.scan.get('token') != self.tokens.get(self.scan['adapter']):
            self.scan_generation += 1
            self.scan = {'state': 'idle', 'adapter': '', 'message': 'Adapter changed; start a new scan when it is available.', 'owned': False}
        adapter = self.objects.get(self.scan['adapter'], {}).get(ADAPTER, {})
        if self.scan['state'] in ('running', 'starting') and not adapter.get('Powered'):
            self.stop_scan()
        self.changed()

    def state(self, path):
        return self.objects.get(path, {}).get(DEVICE, self.objects.get(path, {}).get(ADAPTER, {}))

    def expected(self, path):
        props = self.state(path)
        keys = ('Paired', 'Bonded', 'Connected', 'Trusted', 'Blocked', 'Alias', 'WakeAllowed') if DEVICE in self.objects.get(path, {}) else ('Powered', 'Discoverable', 'Pairable')
        return {key: props.get(key) for key in keys}

    def busy(self, path):
        return any(op['path'] == path and op['phase'] in ACTIVE for op in self.operations.values())

    def request(self, request):
        action, path = request.get('action'), request.get('path')
        if action not in TIMEOUTS or not self.ready or not self.context:
            return False, 'Bluetooth controls are unavailable.'
        if self.tokens.get(path) != request.get('token') or request.get('expected') != self.expected(path):
            return False, 'The device or its state changed. Review the action again.'
        props = self.state(path)
        adapter_action = action in ('enable', 'disable', 'discoverable', 'pairable')
        adapter = path if adapter_action else props.get('Adapter')
        power = self.objects.get(adapter, {}).get(ADAPTER, {})
        if request.get('adapterToken') != self.tokens.get(adapter):
            return False, 'The Bluetooth adapter changed. Review the action again.'
        if not power or self.busy(path) or (not adapter_action and self.busy(adapter)):
            return False, 'An operation is already running, or the adapter is unavailable.'
        if adapter_action and any(op['adapter'] == adapter and op['phase'] in ACTIVE for op in self.operations.values()):
            return False, 'Finish or cancel device operations before changing the adapter.'
        if not adapter_action and DEVICE not in self.objects.get(path, {}):
            return False, 'This device is no longer available.'
        if action in ('connect','pair','disconnect') and not power.get('Powered'):
            return False, 'Turn on this device’s Bluetooth adapter first.'
        if action == 'remove' and (props.get('Paired') or props.get('Bonded')):
            return False, 'This device has pairing information. Use Forget with its pairing-removal review.'
        if action == 'wake' and type(props.get('WakeAllowed')) is not bool:
            return False, 'Wake permission is not exposed for this device.'
        if action == 'connect' and (props.get('Connected') or not props.get('Paired') or props.get('Blocked')):
            return False, 'Connect requires a paired, unblocked, disconnected device.'
        if action == 'disconnect' and not props.get('Connected'):
            return False, 'This device is already disconnected.'
        if action == 'pair' and (props.get('Paired') or props.get('Blocked')):
            return False, 'Pairing requires an unpaired, unblocked device.'
        if action == 'pair' and any(op['action'] == 'pair' and op['phase'] in ACTIVE for op in self.operations.values()):
            return False, 'Finish the current pairing before pairing another device.'
        value = request.get('value')
        if action == 'rename' and (not isinstance(value, str) or len(value) > 64 or any(ord(c) < 32 for c in value)):
            return False, 'Use an alias of at most 64 characters without control characters.'
        if action in ('discoverable', 'pairable', 'wake') and type(value) is not bool:
            return False, 'Invalid adapter setting.'
        self.serial += 1
        op = {'id': str(self.serial), 'path': path, 'token': self.tokens[path], 'adapter': adapter,
              'adapterToken': self.tokens[adapter], 'action': action, 'value': value,
              'phase': 'running', 'startedAt': int(time.time()*1000), 'deadline': self.clock()+TIMEOUTS[action],
              'message': {'connect': 'Connecting…', 'pair': 'Pairing…', 'disconnect': 'Disconnecting…'}.get(action, 'Applying change…'),
              'errorName': '', 'errorDetail': '', 'cancelRequested': False, 'timedOut': False,
              'reply': False, 'cleanupReply': False, 'cleanupOk': False}
        self.operations[path] = op
        # Bound retained results; active transactions are never evicted.
        for key in list(self.operations):
            if len(self.operations) <= 64:
                break
            if self.operations[key]['phase'] not in ACTIVE:
                del self.operations[key]
        self.changed()
        self.call(op, 'start', self.reply)
        return True, ''

    def reply(self, path, ident, stage, error_name='', detail=''):
        op = self.operations.get(path)
        if not op or op['id'] != ident or op['phase'] not in ACTIVE:
            return
        if self.tokens.get(path) != op['token'] or self.tokens.get(op['adapter']) != op['adapterToken']:
            return
        if stage == 'cleanup':
            op['cleanupReply'] = True
            op['cleanupOk'] = not error_name
            if error_name:
                op['errorName'], op['errorDetail'] = error_name, detail[:400]
        else:
            op['reply'] = True
            if error_name:
                op['errorName'], op['errorDetail'] = error_name, detail[:400]
                if op['phase'] != 'cancelling':
                    if op['action'] == 'connect' and self.state(path).get('Connected'):
                        self.finish(op, 'succeeded', 'Bluetooth connected; one or more services may not be ready.')
                    elif 'NoReply' in error_name or 'Timeout' in error_name:
                        self.cancel(path, timed_out=True)
                    else:
                        self.finish(op, 'failed', error_message(error_name, detail))
                    self.changed()
                    return
        self.reconcile(op)
        self.changed()

    def reached(self, op):
        props, action = self.state(op['path']), op['action']
        if action == 'connect': return bool(props.get('Connected'))
        if action == 'pair': return bool(props.get('Paired'))
        if action == 'disconnect': return not props.get('Connected')
        if action in ('forget','remove'): return op['path'] not in self.objects
        key = {'enable': 'Powered', 'disable': 'Powered', 'trust': 'Trusted', 'untrust': 'Trusted',
               'block': 'Blocked', 'unblock': 'Blocked', 'rename': 'Alias', 'discoverable': 'Discoverable', 'pairable': 'Pairable', 'wake': 'WakeAllowed'}[action]
        value = op['value'] if action in ('rename', 'discoverable', 'pairable', 'wake') else action in ('enable', 'trust', 'block')
        # Empty alias restores the remote name.
        if action == 'rename' and value == '': value = props.get('Name') or props.get('Address')
        return props.get(key) == value

    def reconcile(self, op):
        if op['phase'] not in ACTIVE:
            return
        if op['phase'] == 'cancelling':
            if not op['reply'] or not op['cleanupReply']:
                return
            if op['action'] == 'connect' and self.state(op['path']).get('Connected'):
                self.finish(op, 'succeeded', 'The device is connected. Cancellation raced with completion; current BlueZ state is shown.')
            elif op['action'] == 'pair' and self.state(op['path']).get('Paired'):
                self.finish(op, 'succeeded', 'The device paired before cancellation completed.')
            elif op['cleanupOk']:
                self.finish(op, 'failed' if op['timedOut'] else 'cancelled',
                            'The operation timed out. Cleanup completed; current device state is shown. You can retry.' if op['timedOut'] else 'The attempt was cancelled. Current device state is shown.')
            else:
                self.finish(op, 'failed', 'Cancellation could not be confirmed. Current device state is shown; inspect the technical details before retrying.')
        elif op['reply'] and self.reached(op):
            self.finish(op, 'succeeded', {'connect': 'Bluetooth connected.', 'pair': 'Pairing completed. Use Connect to establish services.',
                                       'disconnect': 'Device disconnected.', 'forget': 'Pairing removed.', 'remove': 'Cached device information removed. A device still advertising may reappear.'}.get(op['action'], 'Bluetooth reported the requested setting.'))

    def finish(self, op, phase, message):
        op['phase'], op['message'] = phase, message
        op['finishedAt'] = int(time.time()*1000)

    def cancel(self, path, timed_out=False):
        op = self.operations.get(path)
        if not op or op['phase'] != 'running' or op['action'] not in ('connect', 'pair'):
            return False
        op.update(phase='cancelling', cancelRequested=True, timedOut=timed_out,
                  deadline=self.clock()+10, message='Time limit reached; resolving the attempt…' if timed_out else 'Cancelling; waiting for BlueZ…')
        self.changed()
        self.call(op, 'cleanup', self.reply)
        return True

    def tick(self):
        for op in list(self.operations.values()):
            if op['phase'] not in ACTIVE or self.clock() < op['deadline']:
                continue
            if op['phase'] == 'running' and op['action'] in ('connect', 'pair'):
                self.cancel(op['path'], timed_out=True)
            else:
                self.finish(op, 'failed', 'The request did not resolve before its deadline. Current backend state is shown; a delayed change may still arrive. You can retry.')
        if self.scan['state'] == 'running' and self.clock() >= self.scan.get('deadline', 0):
            self.stop_scan()
        elif self.scan['state'] in ('starting', 'stopping') and self.clock() >= self.scan.get('deadline', 0):
            self.scan.update(state='failed', stopRequested=True, message='The discovery request did not resolve. Reopen Bluetooth to reconnect the controller.')
        self.changed()

    def set_context(self, active):
        self.context = bool(active)
        if not active:
            self.stop_scan()
            for op in list(self.operations.values()):
                if op['action'] == 'pair' and op['phase'] == 'running':
                    self.cancel(op['path'])
        self.changed()

    def start_scan(self, path):
        if not self.context or not self.ready or not self.state(path).get('Powered') or self.scan.get('owned') or self.scan['state'] in ('starting', 'running', 'stopping'):
            return False
        self.scan_generation += 1
        gen = self.scan_generation
        self.scan = {'state': 'starting', 'adapter': path, 'token': self.tokens[path], 'owned': False,
                     'message': 'Starting a 30-second scan…', 'deadline': self.clock()+10, 'stopRequested': False}
        self.call({'path': path, 'id': str(gen), 'action': 'scan'}, 'start', self.scan_reply)
        self.changed()
        return True

    def stop_scan(self):
        if self.scan['state'] == 'starting':
            self.scan['stopRequested'] = True
            return True
        if self.scan['state'] not in ('running','failed') or not self.scan['owned']:
            return False
        self.scan.update(state='stopping', deadline=self.clock()+10, message='Stopping our scan…')
        self.call({'path': self.scan['adapter'], 'id': str(self.scan_generation), 'action': 'scan'}, 'cleanup', self.scan_reply)
        self.changed()
        return True

    def scan_reply(self, path, ident, stage, error_name='', detail=''):
        if ident != str(self.scan_generation) or self.scan.get('token') != self.tokens.get(path):
            return
        if error_name and stage == 'cleanup' and 'NotReady' in error_name and not self.state(path).get('Powered'):
            self.scan.update(state='idle',owned=False,message='Scanning ended when the adapter powered off.')
        elif error_name:
            self.scan.update(state='failed', message=error_message(error_name, detail), errorName=error_name, errorDetail=detail[:400])
        elif stage == 'start':
            self.scan.update(state='running', owned=True, deadline=self.clock()+30, message='Scanning for devices · stops after 30 seconds')
            if self.scan['stopRequested'] or not self.context:
                self.stop_scan()
        else:
            self.scan.update(state='idle', owned=False, message='Scan stopped. Other applications may still be scanning.')
        self.changed()

    def snapshot(self):
        adapters, devices = [], []
        for path, interfaces in self.objects.items():
            if ADAPTER in interfaces:
                p = interfaces[ADAPTER]
                adapters.append({'id': path, 'token': self.tokens[path], 'name': p.get('Alias') or p.get('Name') or path.rsplit('/',1)[-1],
                                 'powered': p.get('Powered', False), 'powerState': p.get('PowerState', 'on' if p.get('Powered') else 'off'),
                                 'discovering': p.get('Discovering', False), 'discoverable': p.get('Discoverable', False),
                                 'pairable': p.get('Pairable', False), 'expected': self.expected(path)})
            if DEVICE not in interfaces:
                continue
            p = interfaces[DEVICE]
            name = p.get('Alias') or p.get('Name') or 'Unidentified device'
            identified = bool(p.get('Name')) or bool(p.get('Alias') and re.sub(r'[:-]', '', p['Alias']).lower() != re.sub(r'[:-]', '', p.get('Address', '')).lower())
            recent = path in self.seen and self.clock()-self.seen[path] < 45
            group = 'connected' if p.get('Connected') else 'paired' if p.get('Paired') else 'nearby' if recent and identified else 'other'
            battery = interfaces.get(BATTERY, {}).get('Percentage')
            devices.append({'id': path, 'token': self.tokens[path], 'adapter': p.get('Adapter', ''), 'address': p.get('Address', ''),
                            'name': name if identified else 'Unidentified device', 'deviceName': p.get('Name', ''), 'identified': identified,
                            'icon': p.get('Icon', 'bluetooth'), 'class': p.get('Class'), 'appearance': p.get('Appearance'),
                            'modalias': p.get('Modalias'), 'legacyPairing': p.get('LegacyPairing'), 'wakeAllowed': p.get('WakeAllowed'),
                            'lastObservedAt': self.seen_wall.get(path), 'rssi': p.get('RSSI') if recent else None, 'txPower': p.get('TxPower') if recent else None,
                            'lastDisconnect': self.disconnections.get(path), 'interfaces': sorted(interfaces.keys()),
                            'reconnectMode': interfaces.get('org.bluez.Input1', {}).get('ReconnectMode'), 'paired': p.get('Paired', False), 'bonded': p.get('Bonded'),
                            'trusted': p.get('Trusted', False), 'blocked': p.get('Blocked', False), 'connected': p.get('Connected', False),
                            'servicesResolved': p.get('ServicesResolved'), 'uuids': p.get('UUIDs', []),
                            'battery': battery if type(battery) is int and 0 <= battery <= 100 else None,
                            'recent': recent, 'group': group, 'addressType': p.get('AddressType', ''),
                            'expected': self.expected(path)})
        adapters.sort(key=lambda a: a['id'])
        devices.sort(key=lambda d: (['connected','paired','nearby','other'].index(d['group']), d['name'].casefold(), d['id']))
        public_ops = {path: dict({k:v for k,v in op.items() if k != 'deadline'}, backendState=self.expected(path), remainingSeconds=max(0,int(op['deadline']-self.clock()+0.99)) if op['phase'] in ACTIVE else 0) for path, op in self.operations.items()}
        return {'available': self.ready, 'error': self.error, 'adapters': adapters, 'devices': devices,
                'operations': public_ops, 'scan': {k:v for k,v in self.scan.items() if k not in ('deadline',)}}
