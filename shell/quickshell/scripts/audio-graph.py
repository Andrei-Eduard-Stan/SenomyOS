#!/usr/bin/env python3
"""Bounded PipeWire inventory and reviewed profile/port/stream-route adapter.

Only explicit `apply` writes; watch/query are read-only. No raw properties/logs
are returned. Tests inject graphs and command runners directly, never via CLI.
"""
import codecs
import hashlib
import json
import os
import selectors
import shutil
import signal
import subprocess
import sys
import time

MAX_BYTES = 8 * 1024 * 1024

def run(argv, timeout=5):
    result = subprocess.run(argv, capture_output=True, timeout=timeout, check=True)
    if len(result.stdout) > MAX_BYTES:
        raise ValueError('Provider inventory exceeded the size limit')
    return result.stdout.decode('utf-8')

def graph():
    if not shutil.which('pw-dump'):
        raise ValueError('pw-dump is not installed')
    return json.loads(run(['pw-dump']))

def props(obj):
    return obj.get('info', {}).get('props', {})

def label(value):
    return str(value or '')[:180]

def identity(obj, cookie):
    serial = props(obj).get('object.serial')
    if serial is None or cookie is None:
        return ''
    return f'{cookie}:{serial}'

def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

def inventory(objects, tools=None):
    tools = tools or {name: bool(shutil.which(name)) for name in ['wpctl', 'pw-metadata']}
    by_id = {o['id']: o for o in objects}
    cookie = by_id.get(0, {}).get('info', {}).get('cookie')
    nodes = []; cards = []; links = []
    for obj in objects:
        typ = obj.get('type', '').rsplit(':', 1)[-1]; p = props(obj)
        if typ == 'Node' and p.get('media.class') in ('Audio/Sink', 'Audio/Source', 'Stream/Output/Audio', 'Stream/Input/Audio'):
            node = {'id': obj['id'], 'token': identity(obj, cookie), 'name': label(p.get('node.description') or p.get('node.nick') or p.get('node.name')),
                    'class': p['media.class'], 'app': label(p.get('application.name') or p.get('application.process.binary') or p.get('node.name')),
                    'serial': str(p.get('object.serial', '')), 'deviceId': p.get('device.id'), 'profileDevice': p.get('card.profile.device'), 'movable': p.get('node.dont-move', False) not in (True, 'true'), 'routes': []}
            nodes.append(node)
        elif typ == 'Device' and p.get('media.class') == 'Audio/Device':
            params = obj.get('info', {}).get('params', {})
            profile = params.get('Profile', [{}])[0].get('index', -1) if params.get('Profile') else -1
            active = [{'index': x.get('index'), 'device': x.get('device'), 'direction': x.get('direction')} for x in params.get('Route', [])]
            profiles = [{'index': x['index'], 'name': label(x.get('description') or x.get('name')), 'available': x.get('available', 'unknown')} for x in params.get('EnumProfile', []) if 'index' in x]
            ports = [{'index': x['index'], 'name': label(x.get('description') or x.get('name')), 'direction': x.get('direction', ''), 'available': x.get('available', 'unknown'), 'profiles': x.get('profiles', []), 'devices': x.get('devices', [])} for x in params.get('EnumRoute', []) if 'index' in x]
            card = {'id': obj['id'], 'token': identity(obj, cookie), 'name': label(p.get('device.description') or p.get('device.name')), 'profile': profile,
                    'bluezPath': label(p.get('api.bluez5.path') or p.get('bluez5.path')), 'bluezAddress': label(p.get('api.bluez5.address')),
                    'profiles': profiles, 'ports': ports, 'activePorts': active, 'canProfile': tools.get('wpctl', False), 'canPort': tools.get('wpctl', False)}
            card['revision'] = digest(card)
            cards.append(card)
        elif typ == 'Link':
            info = obj.get('info', {})
            links.append({'source': info.get('output-node-id'), 'target': info.get('input-node-id'), 'state': info.get('state', 'unknown')})
    for node in nodes:
        if node['class'] == 'Stream/Output/Audio':
            node['routes'] = sorted(set(x['target'] for x in links if x['source'] == node['id'] and x['target'] is not None and x['state'] != 'error'))
        elif node['class'] == 'Stream/Input/Audio':
            node['routes'] = sorted(set(x['source'] for x in links if x['target'] == node['id'] and x['source'] is not None and x['state'] != 'error'))
        node['revision'] = digest(node)
    for card in cards:
        for port in card['ports']:
            cls = 'Audio/Source' if port['direction'] == 'Input' else 'Audio/Sink' if port['direction'] == 'Output' else ''
            candidates = [node for node in nodes if str(node['deviceId']) == str(card['id']) and node['class'] == cls and any(str(node['profileDevice']) == str(device) for device in port['devices'])]
            target = candidates[0] if len(candidates) == 1 else None
            port['nodeToken'] = target['token'] if target else ''
            port['nodeId'] = target['id'] if target else None
            port['profileDevice'] = target['profileDevice'] if target else None
        card['revision'] = digest({k:v for k,v in card.items() if k != 'revision'})
    metadata = any(o.get('type') == 'PipeWire:Interface:Metadata' and o.get('props', {}).get('metadata.name') == 'default' for o in objects)
    return {'available': cookie is not None, 'generation': str(cookie or ''), 'nodes': nodes[:1024], 'cards': cards[:64], 'canMove': bool(tools.get('pw-metadata') and metadata), 'error': ''}

def prepare(request, current):
    if not isinstance(request, dict) or request.get('kind') not in ('profile', 'port', 'move'):
        raise ValueError('Unsupported audio operation')
    kind = request['kind']; items = current['nodes'] if kind == 'move' else current['cards']
    obj = next((x for x in items if x['token'] == request.get('token') and x['revision'] == request.get('revision')), None)
    if not obj:
        raise ValueError('Device, stream, provider or current route changed; review again')
    target = request.get('target')
    if kind == 'move':
        direction = {'Stream/Output/Audio': 'Audio/Sink', 'Stream/Input/Audio': 'Audio/Source'}.get(obj['class'])
        endpoint = next((x for x in current['nodes'] if x['token'] == target and x['class'] == direction), None)
        if not current['canMove'] or not obj['movable'] or not endpoint or not endpoint['serial']:
            raise ValueError('Stream routing is unavailable for this target')
        if obj['routes'] == [endpoint['id']]:
            raise ValueError('Stream is already routed to this target')
        return ['pw-metadata', '-n', 'default', str(obj['id']), 'target.object', 'Spa:Id', endpoint['serial']], obj, endpoint
    if type(target) is not int or target < 0:
        raise ValueError('Invalid option')
    options = obj['profiles'] if kind == 'profile' else obj['ports']
    option = next((x for x in options if x['index'] == target and x['available'] != 'no'), None)
    if not option or not obj['canProfile' if kind == 'profile' else 'canPort']:
        raise ValueError('This device option is unavailable')
    if kind == 'port' and option['profiles'] and obj['profile'] not in option['profiles']:
        raise ValueError('Port is not available in the current profile')
    if (kind == 'profile' and obj['profile'] == target) or (kind == 'port' and any(x['index'] == target for x in obj['activePorts'])):
        raise ValueError('This option is already selected')
    if kind == 'port':
        endpoint = next((node for node in current['nodes'] if node['token'] == option.get('nodeToken')), None)
        if endpoint is None or endpoint['profileDevice'] is None:
            raise ValueError('No unambiguous current endpoint exists for this port')
        # wpctl set-route accepts a NODE: it derives card/profile-device internally.
        return ['wpctl', 'set-route', str(endpoint['id']), str(target)], obj, option
    return ['wpctl', 'set-profile', str(obj['id']), str(target)], obj, option

def observed(request, before, current, target):
    kind = request['kind']; items = current['nodes'] if kind == 'move' else current['cards']
    obj = next((x for x in items if x['token'] == before['token']), None)
    if obj is None:
        raise ValueError('Device or stream disappeared; completion could not be verified')
    if kind == 'profile': return obj['profile'] == request['target']
    if kind == 'port': return any(x['index'] == request['target'] and str(x['device']) == str(target['profileDevice']) for x in obj['activePorts'])
    if not any(x['token'] == target['token'] for x in current['nodes']):
        raise ValueError('Route target disappeared; completion could not be verified')
    return obj['routes'] == [target['id']]

def apply(request, query=graph, execute=run, wait=time.sleep, seconds=6, tools=None):
    current = inventory(query(),tools); argv, before, target = prepare(request, current)
    execute(argv)
    deadline = time.monotonic() + seconds
    while True:
        after = inventory(query(),tools)
        if observed(request, before, after, target):
            return {'ok': True, 'message': 'The provider reports the requested audio change.'}
        if time.monotonic() >= deadline:
            return {'ok': False, 'message': 'Completion was not verified in time. The request may still finish; check the current route before retrying.'}
        wait(0.2)

def merge(cache, events):
    for item in events:
        oid = item['id']
        if not item.get('type') and item.get('info') is None:
            cache.pop(oid, None); continue
        old = cache.get(oid, {})
        if item.get('type'): old['type'] = item['type']
        old['id'] = oid
        for key, value in item.items():
            if key == 'info' and value is not None:
                info = old.setdefault('info', {})
                for field, data in value.items():
                    if field == 'params': info.setdefault(field, {}).update(data)
                    else: info[field] = data
            elif key != 'info': old[key] = value
        cache[oid] = old

def watch():
    if not shutil.which('pw-dump'): raise ValueError('pw-dump is not installed')
    child = subprocess.Popen(['pw-dump', '-m'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True)
    def stop(*args):
        if child.poll() is None: child.terminate()
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, stop); signal.signal(signal.SIGINT, stop)
    text_decoder = codecs.getincrementaldecoder('utf-8')(); decoder = json.JSONDecoder(); buffer = ''; cache = {}; previous = ''; dirty = False; next_emit = 0
    selector = selectors.DefaultSelector(); selector.register(child.stdout, selectors.EVENT_READ)
    try:
        while child.poll() is None:
            for key, _ in selector.select(0.15):
                chunk = os.read(key.fileobj.fileno(), 65536)
                if not chunk: break
                buffer += text_decoder.decode(chunk); buffer = buffer.lstrip()
                if len(buffer) > MAX_BYTES: raise ValueError('Audio event exceeded size limit')
                while buffer:
                    try: batch, end = decoder.raw_decode(buffer)
                    except json.JSONDecodeError: break
                    merge(cache, batch); buffer = buffer[end:].lstrip(); dirty = True
            if dirty and time.monotonic() >= next_emit:
                value = json.dumps(inventory(list(cache.values())), separators=(',', ':'))
                if value != previous: print(value, flush=True); previous = value
                dirty = False; next_emit = time.monotonic() + 0.25
        raise ValueError('PipeWire event subscription ended; reopen Audio to retry')
    finally:
        selector.close()
        if child.poll() is None: child.terminate()
        try: child.wait(timeout=2)
        except subprocess.TimeoutExpired: child.kill();child.wait()

def main():
    try:
        if len(sys.argv) == 2 and sys.argv[1] == 'watch': return watch()
        if len(sys.argv) == 2 and sys.argv[1] == 'query': result = inventory(graph())
        elif len(sys.argv) == 3 and sys.argv[1] == 'apply' and len(sys.argv[2]) < 4096: result = apply(json.loads(sys.argv[2]))
        else: raise ValueError('Invalid audio adapter request')
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as exc:
        result = {'available': False, 'ok': False, 'message': 'Audio operation unavailable or rejected: ' + type(exc).__name__, 'error': str(exc)[:240], 'nodes': [], 'cards': []}
    print(json.dumps(result, separators=(',', ':')), flush=True)

if __name__ == '__main__': main()
