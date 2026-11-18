#!/usr/bin/env python3
"""Senomy display/workspace operations. Native facts, durable intent, guarded writes.

No shell interpolation. Every mutation uses the Lua API and checks readback.
Preview recovery is a separately supervised user unit, armed before the first write.
"""
from contextlib import contextmanager
from copy import deepcopy
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import secrets
import shlex
import subprocess
import sys
import tempfile
import time

TIMEOUT = 15
LIMIT = 65536
MAX_OUTPUTS = 16
ACTIVE_STATES = ('arming', 'applying', 'preview', 'reverting', 'recovery-failed', 'committing')


def config_dir():
    return Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'senomyos'


def runtime_dir():
    return Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')) / 'senomyos'


def state_path():
    return runtime_dir() / 'display-change.json'


def store_path():
    return config_dir() / 'display-manager.json'


def boottime():
    return time.clock_gettime(time.CLOCK_BOOTTIME)


def instance():
    return os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')


def read_json(path, default=None):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return deepcopy(default)


def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temporary = tempfile.mkstemp(prefix=path.name + '.', dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, 'w') as stream:
            json.dump(data, stream, ensure_ascii=True, separators=(',', ':'))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        Path(temporary).unlink(missing_ok=True)


@contextmanager
def locked():
    directory = runtime_dir()
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (directory / 'display-manager.lock').open('a') as stream:
        os.chmod(stream.name, 0o600)
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def store():
    value = read_json(store_path(), {'schemaVersion': 2, 'identities': {}, 'profiles': {},
                                   'workspaceMode': 'independent', 'workspaceLifecycleVersion': 1, 'managedShortcuts': True, 'workspaces': {},
                                   'primary': '', 'rail': {}, 'reconnect': 'suggest', 'autoRecovery': False})
    if value.get('schemaVersion') != 2:
        raise ValueError('Unsupported display manager store; no changes made')
    if not store_path().exists():
        try:legacy = read_json(config_dir()/'displays.json', {})
        except (ValueError,OSError):legacy={}
        if legacy.get('schemaVersion')==1 and isinstance(legacy.get('displays'),dict):
            value['legacyDefaults'] = legacy['displays']
    return value


def lua(value):
    """Lua strings use fixed three-digit byte escapes, never JSON unicode escapes."""
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if not math.isfinite(value):
            raise ValueError('Non-finite Lua number')
        return str(value)
    if isinstance(value, str):
        return '"' + ''.join(chr(b) if 32 <= b < 127 and b not in (34, 92)
                             else '\\' + f'{b:03d}' for b in value.encode()) + '"'
    raise ValueError('Unsupported Lua value')


def table(values):
    if any(not re.fullmatch('[a-z_]+', key) for key in values):
        raise ValueError('Invalid adapter field')
    return '{' + ','.join(key + '=' + lua(value) for key, value in values.items()) + '}'


def command(*args):
    result = subprocess.run(['hyprctl', *args], capture_output=True, text=True, timeout=4)
    if result.returncode:
        raise ValueError('Compositor request failed: ' + (result.stderr or result.stdout).strip()[:300])
    return result.stdout.strip()


def query(*args):
    return json.loads(command('-j', *args))


def require_lua():
    if query('status').get('configProvider') != 'lua':
        raise ValueError('Display manager requires the supported Hyprland Lua provider')


def evaluate(code):
    reply = command('eval', code)
    if reply != 'ok':
        raise ValueError('Compositor rejected operation: ' + reply[:300])


def dispatch(kind, values):
    evaluate('local result=hl.dispatch(hl.dsp.' + kind + '(' + table(values) + ')); assert(result and result.ok,result and result.error or "Missing dispatcher result")')


def mode_parts(value):
    match = re.fullmatch(r'(\d+)x(\d+)@(\d+(?:\.\d+)?)(?:Hz)?', str(value))
    if not match:
        raise ValueError('Unsupported display mode')
    w, h, hz = (float(x) for x in match.groups())
    if not 1 <= w <= 32768 or not 1 <= h <= 32768 or not 1 <= hz <= 1000:
        raise ValueError('Invalid mode dimensions or refresh rate')
    return int(w), int(h), hz


def current_mode(item):
    return f"{int(item['width'])}x{int(item['height'])}@{float(item['refreshRate']):.5f}"


def rect(item):
    width, height, _ = mode_parts(item['mode'])
    if item['transform'] % 2:
        width, height = height, width
    return item['x'], item['y'], width / item['scale'], height / item['scale']


def overlaps(a, b):
    return a[0] < b[0] + b[2] - .01 and a[0] + a[2] > b[0] + .01 and a[1] < b[1] + b[3] - .01 and a[1] + a[3] > b[1] + .01


def configuration(item):
    mode = current_mode(item) if item.get('width', 0) > 0 and item.get('height', 0) > 0 else item.get('restoreMode') or next(iter(item.get('availableModes', [])), '0x0@0')
    return dict(name=item['name'], key=item.get('key', ''), mode=mode,
                scale=float(item.get('scale') or 1), transform=int(item.get('transform') or 0),
                x=int(item.get('x') or 0), y=int(item.get('y') or 0), enabled=not item.get('disabled', False),
                mirrorOf=item.get('mirrorOf') if item.get('mirrorOf') not in ('none', None) else '')


def fingerprint(item):
    serial = str(item.get('serial') or '').strip()
    identity = [item.get('make', ''), item.get('model', ''), serial]
    strong = bool(serial and serial not in ('0', 'Unknown', 'unknown'))
    if not strong:
        identity += [item['name']]
    return hashlib.sha256(json.dumps(identity).encode()).hexdigest()[:24], strong


def normalize_monitors(raw):
    names={str(m.get('id')):m['name'] for m in raw if 'id' in m}
    result=deepcopy(raw)
    for monitor in result:
        value=monitor.get('mirrorOf')
        if value not in (None,'','none'):
            monitor['mirrorOf']=names.get(str(value),str(value))
    return result


def enumerate_displays(raw, data):
    raw=normalize_monitors(raw)
    basekeys = [fingerprint(item)[0] for item in raw]
    result = []
    for item in raw:
        key, strong = fingerprint(item)
        if basekeys.count(key) > 1:
            key = hashlib.sha256((key + item['name']).encode()).hexdigest()[:24]
            strong = False
        entry = data['identities'].get(key)
        if not entry:
            numbers = {v['number'] for v in data['identities'].values()}
            number = next(n for n in range(1, 10000) if n not in numbers)
            entry = {'number': number, 'name': item['name'], 'strong': strong,
                     'friendlyName': item.get('model') or item.get('make') or item['name']}
            data['identities'][key] = entry
        entry['name'] = item['name']
        entry['strong'] = strong
        allowed = ('name', 'make', 'model', 'width', 'height', 'refreshRate', 'scale', 'x', 'y',
                   'transform', 'disabled', 'dpmsStatus', 'focused', 'mirrorOf', 'availableModes',
                   'activeWorkspace', 'physicalWidth', 'physicalHeight', 'vrr', 'currentFormat')
        record = {k: item.get(k) for k in allowed}
        saved=next((o.get('mode') for o in data.get('lastKnownGood',[]) if o.get('key')==key),None)
        record.update(key=key, number=entry['number'], identityStrong=strong, internal=internal_display(item),restoreMode=saved,connectorInstance=item.get('id'),
                      friendlyName=entry['friendlyName'], connected=True)
        result.append(record)
    return result


def topology_digest(items):
    return hashlib.sha256(json.dumps(sorted([configuration(x) for x in items], key=lambda x: x['name']), sort_keys=True).encode()).hexdigest()


def saved_editor_draft():
    saved=read_json(runtime_dir()/'display-editor-draft.json',{})
    if not saved:
        saved=read_json(config_dir()/'display-editor-draft.json',{})
    draft = saved.get('draft')
    if not draft:
        return None
    if saved.get('instance') != instance():
        draft = dict(draft, requiresReview=True)
    return draft


def save_editor_draft(draft):
    if not isinstance(draft,dict) or not isinstance(draft.get('edits'),dict) or not isinstance(draft.get('baseline'),list) or len(draft['baseline'])>MAX_OUTPUTS or len(json.dumps(draft))>65536:
        raise ValueError('Invalid or oversized editor draft')
    target=runtime_dir()/'display-editor-draft.json'
    persistent=config_dir()/'display-editor-draft.json'
    if draft['edits']:
        value=dict(instance=instance(),draft=draft)
        atomic_json(persistent,value)
        atomic_json(target,value)
    else:
        persistent.unlink(missing_ok=True)
        target.unlink(missing_ok=True)
    return dict(ok=True,state='draft-saved')


def snapshot(include_clients=True):
    raw = query('monitors', 'all')
    if not isinstance(raw, list) or len(raw) > MAX_OUTPUTS:
        raise ValueError('Invalid or unsupported output inventory')
    workspaces = query('workspaces')
    with locked():
        data = store()
        original = deepcopy(data)
        displays = enumerate_displays(raw, data)
        workspace_records(data, workspaces, displays)
        if data != original:
            atomic_json(store_path(), data)
    clients = query('clients') if include_clients else []
    return dict(displays=displays, workspaces=[dict({k: w.get(k) for k in
                ('id', 'name', 'monitor', 'monitorID', 'windows', 'hasfullscreen', 'ispersistent')}, **workspace_presentation(w, data, displays)) for w in workspaces],
                windows=[{k: c.get(k) for k in ('address', 'pid', 'class', 'initialClass', 'workspace', 'monitor', 'floating', 'fullscreen', 'at', 'size', 'pinned')} for c in clients],
                policy={k: data.get(k) for k in ('workspaceMode', 'workspaces', 'primary', 'rail', 'reconnect', 'workspaceDefaultHome', 'externalWorkspaceIndicators', 'projectionMode', 'autoRecovery')},
                profiles=[{'id': k, 'name': p['name'], 'displayCount': len(p['outputs']), 'match': 'matched' if {o['key'] for o in p['outputs']}=={d['key'] for d in displays} else 'partial'} for k, p in data['profiles'].items()],
                legacyDefaultsPending=bool(data.get('legacyDefaults')),
                savedLayout=saved_layout_status(data, displays), projection=projection_status(displays),editorDraft=saved_editor_draft(),
                startup=read_json(runtime_dir()/'display-startup.json', {}),
                recovery=recovery_health(data,displays),
                digest=topology_digest(displays), instance=instance(), transaction=public_state())


def saved_layout_status(data, displays):
    saved = data.get('lastKnownGood') or []
    if not saved:
        return {'status':'none'}
    live = {m['key']:m for m in displays}
    if {o['key'] for o in saved} != set(live):
        return {'status':'different-setup'}
    names = {o['name']:live[o['key']]['name'] for o in saved}
    mapped = [dict(o, name=live[o['key']]['name'], mirrorOf=names.get(o.get('mirrorOf'),o.get('mirrorOf',''))) for o in saved]
    return {'status':'matching' if all(matches(o,live[o['key']]) for o in mapped) else 'changed'}


def validate(outputs, inventory):
    if not isinstance(outputs, list) or not 1 <= len(outputs) <= MAX_OUTPUTS:
        raise ValueError('No outputs selected')
    live = {i['name']: i for i in inventory}
    if len({o['name'] for o in outputs}) != len(outputs) or set(live) != {o['name'] for o in outputs}:
        raise ValueError('Connected outputs changed; detect again before applying')
    for out in outputs:
        item = live[out['name']]
        if out.get('key') != item.get('key'):
            raise ValueError('Display identity changed')
        if type(out.get('enabled')) is not bool:
            raise ValueError('Invalid enabled state')
        if not out['enabled']:
            continue
        mode_parts(out['mode'])
        actual = mode_parts(out['mode'])
        supported = [mode_parts(m) for m in item.get('availableModes') or []]
        if not any(actual[:2] == m[:2] and abs(actual[2] - m[2]) <= .06 for m in supported):
            raise ValueError('Requested mode is not reported by ' + item['name'])
        if type(out['scale']) not in (int, float) or not .5 <= out['scale'] <= 4 or not math.isfinite(out['scale']):
            raise ValueError('Scale must be between 0.5 and 4')
        if type(out['transform']) is not int or out['transform'] not in range(8):
            raise ValueError('Invalid transform')
        for axis in ('x', 'y'):
            if type(out[axis]) is not int or abs(out[axis]) > LIMIT:
                raise ValueError('Position must be an integer in supported bounds')
        _, _, w, h = rect(out)
        if abs(w - round(w)) > .02 or abs(h - round(h)) > .02:
            raise ValueError('This mode and scale do not produce integer logical dimensions')
    extended = [o for o in outputs if o['enabled'] and not o.get('mirrorOf')]
    lid_closed = any('closed' in p.read_text().lower() for p in Path('/proc/acpi/button/lid').glob('*/state'))
    usable = [o for o in extended if (live[o['name']].get('physicalWidth') or 0)>0
              and not (lid_closed and o['name'].startswith(('eDP-','LVDS-','DSI-')))]
    if not usable:
        raise ValueError('The final independent physical display cannot be disabled or mirrored')
    for index, a in enumerate(extended):
        for b in extended[index + 1:]:
            if overlaps(rect(a), rect(b)):
                raise ValueError('Extended displays overlap: ' + a['name'] + ' and ' + b['name'])
    for out in outputs:
        if out['enabled'] and out.get('mirrorOf'):
            source = next((s for s in extended if s['name'] == out['mirrorOf']), None)
            if not source or source['name'] == out['name']:
                raise ValueError('Mirror source must be an independent enabled output')
    return deepcopy(outputs)


def output_rule(out):
    fields = dict(output=out['name'], disabled=not out['enabled'])
    if out['enabled']:
        fields.update(mode=re.sub('Hz$', '', out['mode']), position=f"{out['x']}x{out['y']}",
                      scale=out['scale'], transform=out['transform'], mirror=out.get('mirrorOf') or '')
    # Lua monitor rules merge the existing connector rule, preserving unrelated colour/VRR fields.
    return 'hl.monitor(' + table(fields) + ')'


def apply_output(out):
    evaluate(output_rule(out))


def pin_layout(outputs):
    # A connector rule mixed with position=auto rules moves untouched outputs.
    # Schedule one native refresh after all current positions/modes are explicit.
    evaluate(';'.join(output_rule(out) for out in outputs))


def mode_load(out):
    # Ordering heuristic only: EDID blanking, colour depth and DSC remain unknown.
    if not out.get('enabled'):
        return 0
    width, height, refresh = mode_parts(out['mode'])
    return width * height * refresh


def reduces_mode_load(out, actual):
    return bool(out['enabled'] and not out.get('mirrorOf') and actual
                and not actual.get('disabled')
                and mode_load(out) < mode_load(configuration(actual)))


def transition_order(outputs, actual):
    # Keep usable destinations before retiring sources, but release shared-link
    # payload before requesting a larger mode on another enabled output.
    return sorted(outputs, key=lambda out: (not out['enabled'], bool(out.get('mirrorOf')),
                  not reduces_mode_load(out, actual.get(out['name']))))


def matches(out, actual):
    if not out['enabled']:
        return bool(actual.get('disabled'))
    if actual.get('disabled'):
        return False
    mirror = actual.get('mirrorOf') or ''
    if mirror == 'none':
        mirror = ''
    if mirror != (out.get('mirrorOf') or ''):
        return False
    w, h, hz = mode_parts(out['mode'])
    if (int(actual.get('width') or 0), int(actual.get('height') or 0)) != (w, h) or abs(float(actual.get('refreshRate') or 0) - hz) > .08:
        return False
    if out.get('mirrorOf'):
        return True
    return abs(float(actual.get('scale') or 1) - out['scale']) < .01 and int(actual.get('transform') or 0) == out['transform'] and int(actual.get('x') or 0) == out['x'] and int(actual.get('y') or 0) == out['y'] and actual.get('dpmsStatus', True)


def verify(outputs, timeout=3):
    deadline = boottime() + timeout
    while True:
        actual = {i['name']: i for i in normalize_monitors(query('monitors', 'all'))}
        if all(o['name'] in actual and matches(o, actual[o['name']]) for o in outputs):
            return
        if boottime() >= deadline:
            failed = [o for o in outputs if o['name'] not in actual or not matches(o,actual[o['name']])]
            details = []
            for out in failed:
                observed = actual.get(out['name'])
                if not observed:
                    details.append(out['name']+': disconnected')
                elif out['enabled'] and (mode_parts(out['mode'])[:2] != (observed.get('width'),observed.get('height')) or abs(mode_parts(out['mode'])[2]-float(observed.get('refreshRate') or 0)) > .08):
                    details.append(out['name']+': requested '+out['mode']+', actual '+current_mode(observed)+'. The GPU/dock/link rejected this mode with the current setup; try a lower resolution or refresh rate, including on other outputs')
                else:
                    details.append(out['name']+': requested layout was not accepted (position, scale, orientation, mirror or enabled state)')
            raise ValueError('Compositor readback does not match requested layout: '+'; '.join(details))
        time.sleep(.08)


def public_state():
    try:
        state = read_json(state_path(), {})
    except (ValueError, OSError):
        return {'state':'recovery-failed','message':'Display recovery journal is unreadable; do not apply another layout.'}
    if not state:
        return {'state': 'idle'}
    if state.get('instance') and state['instance']!=instance():
        return {'state':'abandoned','message':'Previous compositor session ended; stale preview was not replayed.'}
    result={key:state[key] for key in ('state','message','token','deadline','kind') if key in state}
    if state.get('state')=='preview':result['deadline']=int(time.time()*1000+max(0,(state['bootDeadline']-boottime())*1000))
    return result


def transaction_active():
    state = read_json(state_path(), {})
    if state.get('instance') and state['instance'] != instance():
        return False
    return state.get('state') in ACTIVE_STATES


def arm_watchdog(token):
    unit = 'senomy-display-recovery-' + token
    args = ['systemd-run', '--user', '--quiet', '--collect', '--unit=' + unit,
            '--property=Type=exec', '--property=Restart=on-failure', '--property=RestartSec=1']
    for key in ('HOME', 'XDG_RUNTIME_DIR', 'XDG_CONFIG_HOME', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY'):
        if key in os.environ:
            args += ['--setenv=' + key + '=' + os.environ[key]]
    args += [sys.executable, str(Path(__file__).resolve()), 'watchdog', token]
    result = subprocess.run(args, capture_output=True, text=True, timeout=4)
    if result.returncode:
        raise ValueError('Independent recovery service could not be armed; no displays changed')
    ready = runtime_dir() / ('display-ready-' + token)
    end = time.monotonic() + 4
    while not ready.exists():
        if time.monotonic() >= end:
            raise ValueError('Recovery service did not acknowledge readiness; no displays changed')
        time.sleep(.03)
    ready.unlink(missing_ok=True)


def move_workspace(wsid, monitor):
    dispatch('workspace.move', {'workspace': int(wsid), 'monitor': monitor})


def rollback(state):
    state['state'] = 'reverting'
    state['recoveryAttempts'] = state.get('recoveryAttempts',0)+1
    atomic_json(state_path(), state)
    actual = {m['name']: m for m in normalize_monitors(query('monitors', 'all'))}
    present = [o for o in state['before'] if o['name'] in actual]
    enabled = [o for o in present if o['enabled'] and not o.get('mirrorOf')]
    errors = []
    if not enabled:
        survivors = [m for m in actual.values() if not m['name'].startswith(('HEADLESS-', 'WL-', 'X11-'))]
        if not survivors:
            raise ValueError('No physical output remains connected; recovery journal retained')
        fallback = configuration(survivors[0])
        fallback.update(enabled=True, mirrorOf='', scale=1, transform=0, x=0, y=0,
                        mode=next(iter(survivors[0].get('availableModes', [])), fallback['mode']))
        enabled = [fallback]
        present = [fallback]
    for out in transition_order(present, actual):
        try:
            # Even a rejected mode can leave a bad requested monitor rule behind.
            # Restore attempted rules, without reprogramming unrelated links.
            if out['name'] in state.get('attempted', [o['name'] for o in present]) or not matches(out, actual[out['name']]):
                apply_output(out)
                if reduces_mode_load(out, actual.get(out['name'])):
                    verify([out])
        except Exception as exc:
            errors.append(str(exc))
    current_workspaces = {w['id']: w for w in query('workspaces')}
    for old in state.get('workspaces', []):
        ws = current_workspaces.get(old['id'])
        if ws and old['monitor'] in actual and ws['monitor'] != old['monitor']:
            try:
                move_workspace(old['id'], old['monitor'])
            except Exception as exc:
                errors.append(str(exc))
    # Restore real active groups only if they survived and still belong here.
    # Never recreate an empty workspace merely to restore an old active ID.
    restored_groups={w['id']:w['monitor'] for w in query('workspaces')}
    usable={m['name'] for m in normalize_monitors(query('monitors','all')) if not m.get('disabled') and m.get('mirrorOf') in ('',None,'none')}
    for name,wid in state.get('activeWorkspaces',{}).items():
        if name in usable and restored_groups.get(wid)==name:
            try:
                dispatch('focus',{'monitor':name});dispatch('focus',{'workspace':wid})
            except Exception as exc:errors.append(str(exc))
    if state.get('focusedBefore') in usable:
        try:dispatch('focus',{'monitor':state['focusedBefore']})
        except Exception as exc:errors.append(str(exc))
    try:
        verify(present)
    except Exception as exc:
        errors.append(str(exc))
    if errors:
        state.update(state='recovery-failed', message='; '.join(errors)[:600])
        atomic_json(state_path(), state)
        raise ValueError(state['message'])
    if 'commitStoreBefore' in state:
        previous = state['commitStoreBefore']
        homes = {o['key']:o['name'] for o in present if o['enabled'] and not o.get('mirrorOf')}
        for wid in state.get('policyPatch', {}).get('workspaces', {}):
            record = previous.get('workspaces', {}).get(wid)
            if record and record.get('persistent') and record['home'] in homes:
                install_binding(int(wid), homes[record['home']], True)
            else:
                remove_binding(int(wid))
        atomic_json(store_path(),state['commitStoreBefore'])
    state.update(state='reverted', message=('Confirmed working display layout restored after fallback.' if state.get('safeRecovery') else 'Previous connected display layout restored. Disconnected outputs remain unavailable.'))
    atomic_json(state_path(), state)
    return dict(ok=True, state='reverted', message=state['message'])


def begin(request):
    require_lua()
    snap = snapshot()
    with locked():
        current = read_json(state_path(), {})
        if request.get('startup') and current.get('instance') == instance():
            raise ValueError('Startup restore yielded to a display action already performed in this session')
        if current.get('instance') and current['instance']!=instance():
            current={'state':'abandoned'}
        if current.get('state') in ('arming', 'applying', 'preview', 'reverting', 'recovery-failed', 'committing'):
            raise ValueError('A display preview or failed recovery must be resolved first')
        # Snapshot again under operation ownership; no stale draft silently wins.
        raw = query('monitors', 'all')
        data = store()
        inventory = enumerate_displays(raw, data)
        if request.get('baseDigest') != topology_digest(inventory):
            raise ValueError('Layout changed outside this editor; review or discard the draft')
        outputs = validate(request['outputs'], inventory)
        if request.get('autoRecovery') and not (data.get('autoRecovery') is True and recovery_health(data,inventory)['needed']):
            raise ValueError('Automatic recovery yielded: display state or policy changed')
        policy_patch=deepcopy(request.get('policyPatch') or {})
        if not isinstance(policy_patch,dict):raise ValueError('Invalid display policy patch')
        if any(not o['enabled'] or o.get('mirrorOf') for o in outputs) and projection_status(inventory)['mode'] in ('extend','custom'):
            policy_patch.setdefault('projectionReturn',projection_return(snap))
        targets=request.get('workspaceTargets') or {}
        if not isinstance(targets,dict) or len(targets)>4096 or any(not str(wid).isdigit() or int(wid)<=0 or home not in {o['key'] for o in outputs if o['enabled'] and not o.get('mirrorOf')} for wid,home in targets.items()):
            raise ValueError('Workspace restoration targets are invalid')
        observed_before=[configuration(i) for i in inventory]
        safe_before=None
        if data.get('autoRecovery') is True and recovery_health(data,inventory)['needed']:
            safe_before=confirmed_layout(data,inventory)
        token = secrets.token_hex(12)
        state = dict(token=token, instance=instance(), kind='topology', state='arming',
                     message='Arming independent recovery', before=safe_before or observed_before, observedBefore=observed_before, safeRecovery=bool(safe_before),
                     proposed=outputs, workspaces=query('workspaces'),
                     activeWorkspaces={m['name']:(m.get('activeWorkspace') or {}).get('id') for m in inventory},
                     focusedBefore=next((m['name'] for m in inventory if m.get('focused')),''), primary=request.get('primary', data.get('primary', '')),
                     policyPatch=policy_patch, workspaceTargets=targets,
                     deadline=time.time() * 1000 + 22000, bootDeadline=boottime() + 7)
        atomic_json(state_path(), state)
        try:
            arm_watchdog(token)
        except Exception:
            state.update(state='failed', message='Recovery could not be armed; no outputs changed')
            atomic_json(state_path(), state)
            raise
        state.update(state='applying', message='Applying layout', bootDeadline=boottime()+8)
        atomic_json(state_path(), state)
        try:
            lid_closed=any('closed' in p.read_text().lower() for p in Path('/proc/acpi/button/lid').glob('*/state'))
            candidates=[o for o in outputs if o['enabled'] and not o.get('mirrorOf')
                        and next(m for m in inventory if m['name']==o['name']).get('physicalWidth',0)>0
                        and not (lid_closed and o['name'].startswith(('eDP-','LVDS-','DSI-')))]
            destination=next((o for o in candidates if o['key']==state['primary']),candidates[0])
            original_by_name = {m['name']:m for m in inventory}
            state['attempted'] = [o['name'] for o in state['before']]
            atomic_json(state_path(),state)
            pin_layout(observed_before)
            verify(observed_before)
            try:
                # Enable/wake destinations before retiring sources. No changes during dragging.
                for out in transition_order(outputs, original_by_name):
                    if matches(out, original_by_name[out['name']]):
                        continue
                    if boottime() >= state['bootDeadline']:
                        raise ValueError('Display application exceeded its safety deadline')
                    if not out['enabled'] or out.get('mirrorOf'):
                        verify([destination])
                        for workspace in query('workspaces'):
                            if workspace['monitor'] == out['name'] and workspace['id'] > 0:
                                move_workspace(workspace['id'], destination['name'])
                    if out['name'] not in state['attempted']:state['attempted'].append(out['name'])
                    atomic_json(state_path(), state)
                    apply_output(out)
                    if out['enabled'] and not out.get('mirrorOf') and next(m for m in raw if m['name']==out['name']).get('dpmsStatus') is False:
                        dispatch('dpms',{'action':'on','monitor':out['name']})
                    if reduces_mode_load(out, original_by_name.get(out['name'])):
                        verify([out])
                verify(outputs)
            except ValueError:
                # One bounded whole-topology retry can avoid transient per-output
                # MST allocations. It cannot add physical transport bandwidth.
                retryable=data.get('autoRecovery') is True and all(o['enabled'] and not o.get('mirrorOf') for o in outputs) and all(not m.get('disabled') and m.get('mirrorOf') in ('',None,'none') for m in inventory)
                mode_change=any(mode_parts(o['mode'])!=mode_parts(current_mode(original_by_name[o['name']])) for o in outputs)
                if not retryable or not mode_change or state['bootDeadline']-boottime()<2.2:raise
                state['coordinatedRetry']=True;atomic_json(state_path(),state)
                pin_layout(outputs)
                verify(outputs,timeout=2)
            if boottime()>=state['bootDeadline']:raise ValueError('Display application exceeded its safety deadline')
            targets = {o['key']:o['name'] for o in outputs if o['enabled'] and not o.get('mirrorOf')}
            existing_ids = {w['id'] for w in query('workspaces')}
            assignments=dict(state.get('policyPatch',{}).get('workspaces',{}))
            assignments.update({wid:{'home':home} for wid,home in state.get('workspaceTargets',{}).items()})
            for wid, record in assignments.items():
                target = targets.get(record['home'])
                if target and int(wid) in existing_ids:
                    if boottime()>=state['bootDeadline']:raise ValueError('Workspace migration exceeded display preview deadline')
                    move_workspace(int(wid),target)
                    wait_workspace(int(wid),target)
            state.update(state='preview', message='Verify the displays, then Keep or Revert.',
                         bootDeadline=boottime() + TIMEOUT, deadline=int((time.time() + TIMEOUT) * 1000))
            atomic_json(state_path(), state)
            return dict(ok=True, token=token, deadline=state['deadline'], state='preview')
        except Exception as exc:
            try:
                rollback(state)
            except Exception as recovery:
                state.update(state='recovery-failed', message=str(recovery)[:600])
                atomic_json(state_path(), state)
                raise ValueError(str(exc) + '; recovery: ' + str(recovery)) from exc
            raise ValueError(str(exc) + ('; confirmed working layout restored' if state.get('safeRecovery') else '; previous layout restored')) from exc


def confirm(token, persist=True):
    with locked():
        state = read_json(state_path(), {})
        if state.get('token') != token or state.get('state') != 'preview':
            raise ValueError('Preview is no longer awaiting confirmation')
        if state.get('instance') != instance():
            state.update(state='abandoned',message='Compositor session changed; stale preview was not replayed.')
            atomic_json(state_path(),state)
            raise ValueError(state['message'])
        if boottime() >= state['bootDeadline']:
            rollback(state)
            raise ValueError('Confirmation expired; layout reverted')
        verify(state['proposed'])
        if boottime()>=state['bootDeadline']:
            rollback(state)
            raise ValueError('Confirmation expired during verification; layout reverted')
        if persist:
            data = store()
            state['commitStoreBefore']=deepcopy(data)
            state.update(state='committing')
            atomic_json(state_path(),state)
            data['lastKnownGood'] = state['proposed']
            data['primary'] = state['primary']
            patch = state.get('policyPatch',{})
            for key in ('workspaceMode','workspaces','rail','workspaceDefaultHome','externalWorkspaceIndicators','projectionMode','projectionReturn'):
                if key in patch:data[key]=patch[key]
            if 'workspaces' in patch:
                targets = {o['key']:o['name'] for o in state['proposed'] if o['enabled'] and not o.get('mirrorOf')}
                for wid,record in data['workspaces'].items():
                    if record.get('persistent') and record['home'] in targets:
                        install_binding(int(wid),targets[record['home']],True)
                if data.get('managedShortcuts'):install_shortcuts(data)
            atomic_json(store_path(), data)
        state.update(state='committed', message='Layout confirmed' + (' and saved for startup.' if persist else ' for this session.'))
        atomic_json(state_path(), state)
        return dict(ok=True, state='committed', message=state['message'])


def revert(token, expired_only=False):
    with locked():
        state = read_json(state_path(), {})
        if state.get('token') != token:
            raise ValueError('Unknown preview token')
        if expired_only and boottime()<state.get('bootDeadline',0):
            return dict(ok=True,waiting=True)
        if state.get('state') == 'reverted':
            return dict(ok=True, state='reverted')
        if state.get('state') not in ACTIVE_STATES:
            raise ValueError('Preview already completed')
        if state.get('instance') != instance():
            raise ValueError('Compositor session changed; refusing stale recovery')
        try:
            return rollback(state)
        except Exception as exc:
            state.update(state='recovery-failed',message=str(exc)[:600])
            atomic_json(state_path(),state)
            raise


def watchdog(token):
    ready = runtime_dir() / ('display-ready-' + token)
    ready.touch(mode=0o600)
    while True:
        state = read_json(state_path(), {})
        if state.get('token') != token or state.get('state') in ('failed', 'reverted', 'committed', 'abandoned'):
            ready.unlink(missing_ok=True)
            return
        if state.get('instance') != instance():
            return
        if state.get('recoveryAttempts',0)>=3:
            return
        if boottime() >= state.get('bootDeadline', 0):
            result=revert(token,expired_only=True)
            if result.get('waiting'):continue
            return
        time.sleep(.15)


def profile_operation(operation, request):
    if operation == 'profile-apply':
        snap = snapshot()
        with locked():
            profile = store()['profiles'].get(request['id'])
        if not profile:
            raise ValueError('Profile no longer exists')
        live = {m['key']: m for m in snap['displays']}
        if any(o['key'] not in live for o in profile['outputs']):
            raise ValueError('Profile displays are disconnected or cannot be identified')
        outputs = []
        for out in profile['outputs']:
            matched = live[out['key']]
            if not matched['identityStrong'] and matched['name'] != out['name']:
                raise ValueError('Ambiguous display identity; configure this setup manually')
            outputs.append(dict(out, name=matched['name']))
        mapping = {o['name']: live[o['key']]['name'] for o in profile['outputs']}
        for out in outputs:
            out['mirrorOf'] = mapping.get(out.get('mirrorOf'), out.get('mirrorOf', ''))
        if len(outputs) != len(snap['displays']):
            raise ValueError('Connected display set differs from profile; review manually')
        profile=deepcopy(profile)
        if profile.get('instance')!=instance():profile['workspaces']={k:r for k,r in profile.get('workspaces',{}).items() if r.get('persistent')}
        if profile.get('workspaceLifecycleVersion')!=1:
            profile['workspaces']={k:dict(r,persistent=False) if int(k) in range(1,11) and r.get('home')==profile.get('workspaceDefaultHome') and not r.get('defaultHomeOverride') else r for k,r in profile.get('workspaces',{}).items()}
        return begin(dict(outputs=outputs, baseDigest=snap['digest'], primary=profile.get('primary', ''),
                          policyPatch={k:profile[k] for k in ('workspaceMode','workspaces','rail','workspaceDefaultHome','externalWorkspaceIndicators','projectionMode','projectionReturn') if k in profile}))
    with locked():
        data = store()
        if transaction_active():
            raise ValueError('Keep or revert the display preview before changing profiles')
        if operation == 'profile-import-legacy':
            legacy=data.get('legacyDefaults',{})
            if not legacy:raise ValueError('No legacy startup defaults to import')
            raw=enumerate_displays(query('monitors','all'),data)
            outputs=[]
            for monitor in raw:
                out=configuration(monitor)
                allowed={k:v for k,v in legacy.get(monitor['name'],{}).items() if k in ('mode','scale','transform','x','y')}
                out.update(allowed);outputs.append(out)
            validate(outputs,raw)
            data['profiles'][secrets.token_hex(8)]={'name':'Imported startup defaults','outputs':outputs,'primary':data['primary'],
                                                 'workspaceMode':data['workspaceMode'],'workspaces':deepcopy(data['workspaces']),'rail':deepcopy(data['rail'])}
            data.pop('legacyDefaults',None)
        elif operation == 'profile-save':
            name = str(request.get('name', '')).strip()
            if not 1 <= len(name) <= 80 or any(ord(c) < 32 for c in name):
                raise ValueError('Profile name must contain 1–80 readable characters')
            raw = enumerate_displays(query('monitors', 'all'), data)
            workspace_records(data,query('workspaces'),raw)
            pid = request.get('id') or secrets.token_hex(8)
            data['profiles'][pid] = dict(name=name, outputs=[configuration(m) for m in raw],
                                        primary=data['primary'], workspaceMode=data['workspaceMode'], instance=instance(), workspaceLifecycleVersion=1,
                                        workspaceDefaultHome=data.get('workspaceDefaultHome',''),
                                        externalWorkspaceIndicators=data.get('externalWorkspaceIndicators',False),
                                        workspaces=deepcopy(data['workspaces']), rail=deepcopy(data['rail']))
        elif operation == 'profile-rename':
            name = str(request.get('name', '')).strip()
            if not 1 <= len(name) <= 80:
                raise ValueError('Invalid profile name')
            data['profiles'][request['id']]['name'] = name
        elif operation == 'profile-delete':
            data['profiles'].pop(request['id'], None)
        else:
            raise ValueError('Unsupported profile operation')
        atomic_json(store_path(), data)
    return dict(ok=True, message='Profile updated')


def internal_display(monitor):
    return bool(re.match(r'^(eDP|LVDS|DSI)-',monitor['name']))


def projection_return(snap):
    homes={m['name']:m['key'] for m in snap['displays']}
    return dict(outputs=[configuration(m) for m in snap['displays']],instance=instance(),primary=snap['policy'].get('primary') or effective_workspace_main(snap['policy'],snap['displays']),
                workspaces={str(w['id']):homes[w['monitor']] for w in snap['workspaces'] if w['id']>0 and w.get('windows',0)>0 and w['monitor'] in homes})


def projection_status(displays):
    enabled=[m for m in displays if not m.get('disabled')]
    internal=[m for m in displays if internal_display(m)]
    mirrors=[m for m in enabled if m.get('mirrorOf') not in ('',None,'none')]
    if mirrors and len(mirrors)==len(enabled)-1:kind='duplicate'
    elif internal and enabled and all(m in internal for m in enabled):kind='pc-only'
    elif internal and enabled and all(m not in internal for m in enabled):kind='external-only'
    elif len(enabled)==len(displays) and not mirrors:kind='extend'
    else:kind='custom'
    return dict(mode=kind,internalAvailable=bool(internal),
                mirrorSupported=True,mirrorNote='Native Hyprland mirroring; each target mode must also be accepted by the display link.')


def projection_plan(request):
    """Read-only plan. The editor stages this through the normal guarded path."""
    require_lua()
    snap=snapshot(False);data=store();displays=snap['displays']
    kind=request.get('mode')
    if kind not in ('pc-only','duplicate','extend','external-only','custom'):
        raise ValueError('Unknown projection mode')
    internal=[m for m in displays if internal_display(m)]
    external=[m for m in displays if m not in internal]
    if kind=='pc-only' and not internal:raise ValueError('No built-in display detected; choose Custom or an external output')
    selected=request.get('externals',[m['name'] for m in external])
    if not isinstance(selected,list) or not set(selected)<={m['name'] for m in external}:raise ValueError('External display selection changed')
    if kind=='external-only' and not selected:raise ValueError('Select at least one external display')
    outputs=[configuration(m) for m in displays]
    primary=next((m for m in displays if m['key']==data.get('primary')),None) or (internal[0] if internal else displays[0])
    source=next((m for m in displays if m['name']==request.get('source')),None) or primary
    previous=data.get('projectionReturn') or {}
    patch={'projectionMode':kind};workspace_targets={}
    if kind in ('pc-only','duplicate','external-only') and snap['projection']['mode'] in ('extend','custom'):
        previous=projection_return(snap)
        patch['projectionReturn']=previous
    if kind=='extend' and previous.get('outputs'):
        live={m['key']:m for m in displays}
        # Do not silently apply an old topology to a different monitor set.
        if {o['key'] for o in previous['outputs']}==set(live):
            names={o['name']:live[o['key']]['name'] for o in previous['outputs']}
            outputs=[dict(o,name=live[o['key']]['name'],mirrorOf=names.get(o.get('mirrorOf'),o.get('mirrorOf',''))) for o in previous['outputs']]
            workspace_targets={wid:home for wid,home in previous.get('workspaces',{}).items() if home in live} if previous.get('instance')==instance() else {}
            primary=next((m for m in displays if m['key']==previous.get('primary')),primary)
    if kind=='pc-only':
        primary=internal[0]
        for out in outputs:out.update(enabled=out['key']==primary['key'],mirrorOf='')
    elif kind=='external-only':
        primary=next(m for m in external if m['name'] in selected)
        for out in outputs:out.update(enabled=out['name'] in selected,mirrorOf='')
    elif kind=='duplicate':
        primary=source
        for out in outputs:out.update(enabled=True,mirrorOf='' if out['key']==source['key'] else source['name'])
    elif kind=='extend':
        for out in outputs:out.update(enabled=True,mirrorOf='')
    # A newly enabled output may report 0x0. Choose an advertised mode, then
    # arrange only overlapping independent outputs next to the existing group.
    active=[]
    for out in outputs:
        if not out['enabled'] or out.get('mirrorOf'):continue
        if any(overlaps(rect(out),rect(other)) for other in active):
            out['x']=int(max(rect(o)[0]+rect(o)[2] for o in active));out['y']=min(o['y'] for o in active)
        active.append(out)
    validate(outputs,displays)
    return dict(ok=True,state='projection-plan',mode=kind,outputs=outputs,baseDigest=snap['digest'],
                primary=primary['key'],policyPatch=patch,workspaceTargets=workspace_targets,
                message='Projection staged. Review the complete layout, Apply, then Keep to save.')


def effective_workspace_main(data, displays):
    usable=[m for m in displays if not m.get('disabled') and m.get('mirrorOf') in ('none','',None)]
    return next((m['key'] for m in usable if m['key']==data.get('workspaceDefaultHome')),
                next((m['key'] for m in usable if internal_display(m)),usable[0]['key'] if usable else ''))


def workspace_records(data, workspaces, displays):
    """Metadata only. Never create/focus/pin a workspace while rendering state."""
    by_name = {m['name']: m for m in displays}
    main = next((m for m in displays if m['key']==data.get('workspaceDefaultHome')), None)
    if not main:
        main = next((m for m in displays if internal_display(m)), displays[0] if displays else None)
    if main and not data.get('workspaceDefaultHome'):data['workspaceDefaultHome']=main['key']
    records = data['workspaces']
    if data.get('workspaceSession') and data['workspaceSession']!=instance():
        for wid in list(records):
            if not records[wid].get('persistent'):del records[wid]
    live = {str(w['id']) for w in workspaces if w['id']>0}
    for wid in list(records):
        if wid not in live and not records[wid].get('persistent'):del records[wid]
    if data.get('workspaceSession')!=instance():
        data['workspaceSession']=instance();data['workspaceInitial']={}
    initial=data.setdefault('workspaceInitial',{})
    states=data.setdefault('workspaceMonitorState',{})
    connected={m['key'] for m in displays}
    for key in list(states):
        if key not in connected:states[key]['enabled']=False
    for monitor in displays:
        previous=states.get(monitor['key'],{})
        enabled=not monitor.get('disabled') and monitor.get('mirrorOf') in ('none','',None)
        incarnation=monitor.get('connectorInstance')
        if monitor['key'] not in initial or (enabled and (not previous.get('enabled') or previous.get('id')!=incarnation)):
            initial[monitor['key']]=(monitor.get('activeWorkspace') or {}).get('id')
        states[monitor['key']]={'enabled':enabled,'id':incarnation}
    for ws in sorted(workspaces,key=lambda w:w['id']):
        if ws['id'] <= 0:continue
        key = str(ws['id']);monitor = by_name.get(ws['monitor'])
        if not monitor:continue
        if key not in records:
            slots = {r['slot'] for r in records.values() if r['home'] == monitor['key']}
            passive=bool(monitor['key']!=effective_workspace_main(data,displays) and not ws.get('windows') and not ws.get('ispersistent') and initial.get(monitor['key'])==ws['id'])
            records[key] = dict(home=monitor['key'], slot=0 if passive else next(n for n in range(1, 10000) if n not in slots),
                                label='', persistent=bool(ws.get('ispersistent')), order=len(records), homeNumber=monitor['number'],
                                used=bool(ws.get('windows')) or initial.get(monitor['key'])!=ws['id'])
        record=records[key]
        if ws.get('windows'):record['used']=True
        # Each enabled output must keep a native landing workspace. Once an
        # empty external is left, retire only its presentation/local slot;
        # never destroy compositor state or move windows during inventory.
        retired=bool(not ws.get('windows') and not ws.get('ispersistent')
                     and not record.get('persistent') and not monitor.get('focused')
                     and monitor['key']!=effective_workspace_main(data,displays)
                     and not data.get('externalWorkspaceIndicators',False))
        if retired:
            record.update(used=False,slot=0)
        if record.get('slot',0)==0 and (record.get('used') or record.get('persistent') or data.get('externalWorkspaceIndicators') or monitor['key']==effective_workspace_main(data,displays)):
            slots={r['slot'] for k,r in records.items() if k!=key and r['home']==record['home']}
            record['slot']=next(n for n in range(1,10000) if n not in slots)
    return records


def workspace_presentation(ws, data, displays):
    record=data['workspaces'].get(str(ws['id']),{})
    monitor=next((m for m in displays if m['name']==ws['monitor']),{})
    independent=data['workspaceMode']=='independent'
    label=record.get('label') or ((str(record.get('slot',ws['id'])) if record.get('slot',ws['id']) else '—') if independent else str(ws['id']))
    guest=bool(record and monitor and record['home']!=monitor['key'])
    if independent and guest:label=str(record.get('homeNumber','guest'))+'·'+label
    active_here=(monitor.get('activeWorkspace') or {}).get('id')==ws['id']
    visible=bool(ws['id']>0 and (ws.get('windows') or ws.get('ispersistent') or record.get('persistent') or (record.get('used') and monitor.get('focused') and active_here)
                 or monitor.get('key')==effective_workspace_main(data,displays) or data.get('externalWorkspaceIndicators',False)))
    return dict(displayLabel=label, indicatorVisible=visible, occupied=bool(ws.get('windows')), guest=guest)


def migrate_dynamic_workspaces(data, displays):
    """Retire only the legacy generated default pins; preserve windows and IDs."""
    if data.get('workspaceLifecycleVersion')==1:return
    home=data.get('workspaceDefaultHome')
    for wid,record in data['workspaces'].items():
        generated=bool(home and int(wid) in range(1,11) and record.get('home')==home
                       and not record.get('defaultHomeOverride') and not record.get('explicitPersistent') and int(wid) not in data.get('workspaceDefaultExcluded',[]))
        if generated:
            remove_binding(int(wid));record['persistent']=False
        elif not record.get('persistent'):remove_binding(int(wid))
    data.update(workspaceLifecycleVersion=1,workspaceMode='independent',managedShortcuts=True)
    data.pop('workspaceDefaultExcluded',None)
    # Local labels are assigned to surviving native IDs; no native renumbering.
    live=query('workspaces')
    records=data['workspaces']
    for wid in list(records):
        if not records[wid].get('persistent'):del records[wid]
    workspace_records(data,live,displays)



def workspace_operation(request):
    require_lua()
    snap = snapshot()
    with locked():
        if transaction_active():
            raise ValueError('Finish the display preview first')
        data = store()
        workspaces = query('workspaces')
        records = workspace_records(data, workspaces, snap['displays'])
        action = request['action']
        live = {w['id']: w for w in workspaces}
        monitors = {m['name']: m for m in snap['displays'] if not m.get('disabled') and m.get('mirrorOf') in ('none', '', None)}
        if action == 'dynamic-defaults':
            migrate_dynamic_workspaces(data,snap['displays'])
            data['workspaceMode']='independent';data['managedShortcuts']=True
            install_shortcuts(data)
        elif action == 'default-home':
            monitor = monitors.get(request['monitor'])
            if not monitor:raise ValueError('Main monitor disappeared')
            data['workspaceDefaultHome']=monitor['key']
        elif action == 'external-indicators':
            data['externalWorkspaceIndicators']=bool(request.get('visible'))
        elif action == 'mode':
            if request.get('mode') not in ('global', 'independent'):
                raise ValueError('Unsupported workspace model')
            # Preserve all native IDs/windows; only labels/switch policy change.
            data['workspaceMode'] = request['mode']
            data['managedShortcuts'] = True
            install_shortcuts(data)
        elif action in ('rail', 'primary'):
            monitor = monitors.get(request['monitor'])
            if not monitor:
                raise ValueError('Selected monitor disappeared')
            if action == 'rail':
                data['rail'][monitor['key']] = bool(request['visible'])
            else:
                data['primary'] = monitor['key']
        elif action == 'restore-home':
            by_key = {m['key']:m for m in monitors.values()}
            for wid, record in records.items():
                ws = live.get(int(wid))
                target = by_key.get(record['home'])
                if ws and target and ws['monitor'] != target['name']:
                    move_workspace(int(wid), target['name'])
                    wait_workspace(int(wid), target['name'])
        elif action == 'reorder':
            ids = request['ids']
            if len(set(ids)) != len(ids) or any(int(i) not in live for i in ids):
                raise ValueError('Workspace list changed')
            for order, wid in enumerate(ids):
                records[str(wid)]['order'] = order
        else:
            wid = int(request.get('id', 0))
            if action == 'create':
                monitor = monitors.get(request['monitor'])
                if not monitor:
                    raise ValueError('Selected monitor disappeared')
                occupied = set(live) | {int(k) for k in records}
                wid = next(i for i in range(1, 2147483647) if i not in occupied)
                slots = {r['slot'] for r in records.values() if r['home'] == monitor['key']}
                records[str(wid)] = dict(home=monitor['key'], slot=next(i for i in range(1, 10000) if i not in slots), label='', persistent=False, used=True, order=len(records), homeNumber=monitor['number'])
                dispatch('focus', {'monitor': monitor['name']})
                dispatch('focus', {'workspace': wid})
                wait_workspace(wid, monitor['name'])
            elif wid not in live:
                raise ValueError('Workspace no longer exists')
            elif action == 'switch':
                records[str(wid)]['used']=True
                target = live[wid]['monitor']
                dispatch('focus', {'monitor': target})
                dispatch('focus', {'workspace': wid})
                wait_workspace(wid, target, active=True)
            elif action == 'move':
                monitor = monitors.get(request['monitor'])
                if not monitor:
                    raise ValueError('Destination monitor disappeared')
                move_workspace(wid, monitor['name'])
                wait_workspace(wid, monitor['name'])
                record = records[str(wid)]
                slots = {r['slot'] for k, r in records.items() if r['home'] == monitor['key'] and k != str(wid)}
                if record['slot'] in slots:
                    record['slot'] = next(i for i in range(1, 10000) if i not in slots)
                record['home'] = monitor['key']
                record['used'] = True
                record['homeNumber'] = monitor['number']
                if record['persistent']:
                    install_binding(wid, monitor['name'], True)
            elif action == 'rename':
                label = str(request.get('label', '')).strip()
                if not 1 <= len(label) <= 48 or any(ord(c) < 32 for c in label):
                    raise ValueError('Workspace name must contain 1–48 readable characters')
                dispatch('workspace.rename', {'workspace': wid, 'name': label})
                if not any(w['id']==wid and w['name']==label for w in query('workspaces')):raise ValueError('Workspace rename was not verified')
                records[str(wid)]['label'] = label
                records[str(wid)]['used'] = True
            elif action in ('persistent', 'remove'):
                monitor = monitors[live[wid]['monitor']]
                if action == 'remove' and live[wid]['windows']:
                    raise ValueError('Move this workspace’s windows before removing its saved slot')
                persistent = bool(request.get('value', False)) if action == 'persistent' else False
                install_binding(wid, monitor['name'], persistent)
                records[str(wid)]['persistent'] = persistent
                records[str(wid)]['explicitPersistent'] = persistent
                if action == 'remove':
                    del records[str(wid)]
            elif action == 'window-move':
                address = request['address']
                clients = query('clients')
                current = next((c for c in clients if c.get('address') == address and c.get('pid') == request.get('pid') and c.get('workspace', {}).get('id') == request.get('sourceWorkspace')), None)
                if not current or not re.fullmatch(r'0x[0-9a-fA-F]+', address):
                    raise ValueError('Window closed or changed workspace; select it again')
                records[str(wid)]['used']=True
                dispatch('window.move', {'window': 'address:' + address, 'workspace': wid, 'follow': False})
                end = boottime() + 2
                while not any(c.get('address') == address and c.get('workspace', {}).get('id') == wid for c in query('clients')):
                    if boottime() > end:
                        raise ValueError('Window movement could not be verified')
                    time.sleep(.08)
            else:
                raise ValueError('Unsupported workspace operation')
        # Focus/create can change monitor ownership after the opening snapshot.
        # Retire empty indicators only against current native focus facts.
        fresh_displays=enumerate_displays(query('monitors','all'),data)
        workspace_records(data,query('workspaces'),fresh_displays)
        atomic_json(store_path(), data)
    return dict(ok=True, message='Workspace policy updated' if action in ('mode', 'reorder', 'rail', 'primary') else 'Workspace operation verified')



def install_projection_shortcut():
    shell=Path(__file__).resolve().parents[1]
    cmd=shlex.join(['qs','ipc','--path',str(shell),'call','shell','projection'])
    evaluate('hl.unbind("SUPER + CTRL + P");assert(hl.bind("SUPER + CTRL + P",hl.dsp.exec_cmd('+lua(cmd)+')),"Projection binding failed")')


def install_shortcuts(data):
    entry = Path(__file__).resolve().with_name('display-action.py')
    if not entry.exists():entry=Path(__file__).resolve().with_name('senomy-display-action')
    calls = []
    for slot in range(1, 11):
        for shift, action in ((False, 'switch'), (True, 'move')):
            key = 'SUPER + ' + ('SHIFT + ' if shift else '') + str(slot % 10)
            cmd = shlex.join([sys.executable, str(entry), 'shortcut', str(slot), action])
            calls += ['hl.unbind(' + lua(key) + ')',
                      'assert(hl.bind(' + lua(key) + ',hl.dsp.exec_cmd(' + lua(cmd) + ')),"Shortcut binding failed")']
    evaluate(';'.join(calls))


def shortcut(slot, action):
    if not 1 <= slot <= 10 or action not in ('switch', 'move'):
        raise ValueError('Invalid workspace shortcut')
    require_lua()
    snap = snapshot()
    with locked():
        if transaction_active():
            raise ValueError('Finish the display preview before changing workspace assignments')
        data = store()
        records = workspace_records(data, query('workspaces'), snap['displays'])
        monitor = next((m for m in snap['displays'] if m.get('focused') and not m.get('disabled')), None)
        if not monitor:
            raise ValueError('No focused usable monitor')
        if data['workspaceMode'] == 'independent':
            found = next((int(k) for k,r in records.items() if r['home']==monitor['key'] and r['slot']==slot), None)
            if found is None:
                used = {w['id'] for w in query('workspaces')} | {int(k) for k in records}
                found = next(i for i in range(1,2147483647) if i not in used)
                records[str(found)] = dict(home=monitor['key'],homeNumber=monitor['number'],slot=slot,label='',persistent=False,order=len(records))
            wid = found
            actual=next((w for w in snap['workspaces'] if w['id']==wid),None)
            if actual and actual['monitor']!=monitor['name']:
                raise ValueError('Workspace is temporarily hosted on '+actual['monitor']+'; restore home groups or adopt its placement in Displays')
            records[str(wid)]['used']=True
            if records[str(wid)]['persistent']:install_binding(wid,monitor['name'],True)
        else:
            wid = slot
        if action == 'switch':
            dispatch('focus',{'monitor':monitor['name']})
            dispatch('focus',{'workspace':wid})
            if data['workspaceMode']=='independent':wait_workspace(wid,monitor['name'],active=True)
            elif not any(w['id']==wid for w in query('workspaces')):raise ValueError('Workspace switch was not verified')
        else:
            window = query('activewindow')
            address = window.get('address','')
            if not re.fullmatch(r'0x[0-9a-fA-F]+',address):raise ValueError('No active window')
            dispatch('window.move',{'window':'address:'+address,'workspace':wid,'follow':False})
            if not any(c.get('address')==address and c.get('workspace',{}).get('id')==wid for c in query('clients')):
                raise ValueError('Window movement was not verified')
        atomic_json(store_path(),data)
    return dict(ok=True,message='Workspace shortcut verified')


def install_binding(wid, monitor, persistent):
    # Keep owned rule handles so a replacement disables the previous owned rule.
    slot = 'w' + str(int(wid))
    fields = table(dict(workspace=str(int(wid)), monitor=monitor, persistent=bool(persistent)))
    evaluate('senomy_workspace_rules=senomy_workspace_rules or {}; '
             'if senomy_workspace_rules.' + slot + ' then senomy_workspace_rules.' + slot + ':set_enabled(false) end; '
             'senomy_workspace_rules.' + slot + '=hl.workspace_rule(' + fields + ')')
    if not any(r.get('workspaceString')==str(int(wid)) and r.get('monitor')==monitor and r.get('enabled') is True and bool(r.get('persistent'))==bool(persistent) for r in query('workspacerules')):
        raise ValueError('Workspace binding/persistence was not verified')


def remove_binding(wid):
    slot = 'w' + str(int(wid))
    evaluate('if senomy_workspace_rules and senomy_workspace_rules.' + slot + ' then '
             'senomy_workspace_rules.' + slot + ':set_enabled(false); '
             'senomy_workspace_rules.' + slot + '=nil end')


def wait_workspace(wid, monitor, active=False):
    end = boottime() + 2
    while True:
        exists = any(w['id'] == wid and w['monitor'] == monitor for w in query('workspaces'))
        lit = not active or any(m['name'] == monitor and m.get('activeWorkspace', {}).get('id') == wid for m in query('monitors'))
        if exists and lit:
            return
        if boottime() > end:
            observed=next((w['monitor'] for w in query('workspaces') if w['id']==wid),'absent')
            raise ValueError(f'Workspace {wid} did not stay on {monitor}; observed {observed}')
        time.sleep(.08)


def restore_policy(startup=False):
    # Reaffirm previously confirmed policy after compositor configuration reloads.
    # Never applies display geometry or pulls a surviving guest workspace home.
    snap = snapshot()
    with locked():
        if transaction_active():
            return dict(ok=True, state='policy-deferred', message='Workspace policy waits for display recovery')
        data = store()
        connected = snap['displays']
        if data.get('workspaceLifecycleVersion')!=1:
            require_lua();migrate_dynamic_workspaces(data,connected)
        workspace_records(data,query('workspaces'),connected)
        atomic_json(store_path(),data)
        if data.get('managedProjectionShortcut',True):install_projection_shortcut()
        if data.get('managedShortcuts') or any(r.get('persistent') for r in data['workspaces'].values()):
            require_lua()
            homes={m['key']:m['name'] for m in connected if not m['disabled'] and m.get('mirrorOf') in ('none','',None)}
            actual={w['id']:w['monitor'] for w in snap['workspaces']}
            for wid,record in data['workspaces'].items():
                if record.get('persistent') and record['home'] in homes and actual.get(int(wid), homes[record['home']]) == homes[record['home']]:
                    install_binding(int(wid),homes[record['home']],True)
            if data.get('managedShortcuts'):install_shortcuts(data)
    return dict(ok=True, state='policy-restored', message='Saved workspace policy restored')


def restore(startup=False):
    policy = restore_policy(startup=True)
    if policy.get('state') == 'policy-deferred':return policy
    data = store()
    outputs = data.get('lastKnownGood')
    if not outputs:
        return dict(ok=True, message='No confirmed layout to restore; compositor defaults retained')
    snap = snapshot()
    live = {m['key']: m for m in snap['displays']}
    if len(live) != len(outputs) or any(o['key'] not in live for o in outputs):
        return dict(ok=True, message='Saved setup is absent or ambiguous; current safe layout retained')
    names={o['name']:live[o['key']]['name'] for o in outputs}
    mapped = [dict(o, name=live[o['key']]['name'],mirrorOf=names.get(o.get('mirrorOf'),o.get('mirrorOf',''))) for o in outputs]
    if all(matches(o, live[o['key']]) for o in mapped):
        return dict(ok=True, state='matching', message='Confirmed startup layout already matches; no outputs changed.')
    restored=begin(dict(baseDigest=snap['digest'], outputs=mapped, primary=data['primary'], startup=startup))
    return confirm(restored['token'],persist=False)


def startup_result(result):
    """Keep bounded, private evidence even when the compositor discards stdout."""
    result = dict(result, instance=instance(), recordedAt=int(time.time()))
    atomic_json(runtime_dir()/'display-startup.json', result)
    state_home = Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state')))
    atomic_json(state_home/'senomyos/display-startup.json', result)
    return result


def restore_startup(wait_seconds=20, settle_seconds=1):
    """Wait for the saved connector set once per session, without overriding edits.

    MST outputs can arrive after hyprland.start. A missing or changing setup is
    observed for a bounded interval; only an exact, settled setup is replayed.
    Recovery is still armed by begin() before any display changes.
    """
    if not instance():
        raise ValueError('Startup restore requires an explicit compositor instance')
    runtime_dir().mkdir(parents=True, exist_ok=True, mode=0o700)
    with (runtime_dir()/'display-startup.lock').open('a') as owner:
        os.chmod(owner.name, 0o600)
        try:
            fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return dict(ok=True, state='startup-running', message='Startup restoration is already running.')
        previous = read_json(runtime_dir()/'display-startup.json', {})
        if previous.get('instance') == instance():
            return previous
        end = time.monotonic() + wait_seconds
        stable_digest, stable_since = None, None
        reason = 'Saved display setup has not become ready.'
        while True:
            # Any user preview (including one already completed) takes priority.
            transaction = read_json(state_path(), {})
            if transaction.get('instance') == instance():
                return startup_result(dict(ok=True, state='startup-skipped',
                    message='A display action already ran in this session; startup did not override it.'))
            try:
                data = store()
                saved = data.get('lastKnownGood') or []
                if not saved:
                    restore_policy(startup=True)
                    return startup_result(dict(ok=True, state='startup-defaults',
                        message='No confirmed layout; compositor defaults retained.'))
                snap = snapshot(False)
                live = {m['key']:m for m in snap['displays']}
                if len(live) != len(saved) or any(o['key'] not in live for o in saved):
                    stable_digest, stable_since = None, None
                    reason = 'Saved setup is absent or ambiguous; current layout retained.'
                else:
                    names = {o['name']:live[o['key']]['name'] for o in saved}
                    mapped = [dict(o, name=live[o['key']]['name'],
                        mirrorOf=names.get(o.get('mirrorOf'),o.get('mirrorOf',''))) for o in saved]
                    validate(mapped, snap['displays'])
                    if snap['digest'] != stable_digest:
                        stable_digest, stable_since = snap['digest'], time.monotonic()
                    if time.monotonic() - stable_since >= settle_seconds:
                        # Recheck user ownership after observation, before arming.
                        if read_json(state_path(), {}).get('instance') == instance():
                            continue
                        try:
                            return startup_result(restore(startup=True))
                        except Exception as error:
                            return startup_result(dict(ok=False, state='startup-failed',
                                message=str(error)[:800]))
                    reason = 'Saved setup is connected; waiting for display enumeration to settle.'
            except (ValueError, OSError, subprocess.SubprocessError) as error:
                stable_digest, stable_since = None, None
                reason = str(error)[:800]
            if time.monotonic() >= end:
                return startup_result(dict(ok=False, state='startup-unavailable', message=reason))
            time.sleep(.2)


def confirmed_layout(data, inventory):
    """Map only an exact saved identity set; never guess another dock/setup."""
    saved=data.get('lastKnownGood') or []
    live={m['key']:m for m in inventory}
    if not saved or len(saved)!=len(live) or len({o['key'] for o in saved})!=len(saved) or any(o['key'] not in live for o in saved):
        return None
    names={o['name']:live[o['key']]['name'] for o in saved}
    return [dict(o,name=live[o['key']]['name'],mirrorOf=names.get(o.get('mirrorOf'),o.get('mirrorOf',''))) for o in saved]


def recovery_health(data, inventory):
    enabled=data.get('autoRecovery') is True
    result=dict(enabled=enabled,needed=False,canAttempt=False,state='disabled',message='Automatic display recovery is off.')
    if not enabled:return result
    proposed=confirmed_layout(data,inventory)
    if proposed is None:
        return dict(result,state='setup-unmatched',message='Waiting for the complete confirmed display setup; other layouts are left alone.')
    try:validate(proposed,inventory)
    except (ValueError,KeyError,TypeError) as error:
        return dict(result,state='setup-unavailable',message='Confirmed layout is not currently available: '+str(error)[:300])
    actual={m['name']:m for m in inventory}
    # Never counter a deliberate projection, disable, mirror or sleep action.
    if any(o['enabled']==bool(actual[o['name']].get('disabled')) or
           (o.get('mirrorOf') or '')!=('' if actual[o['name']].get('mirrorOf') in ('',None,'none') else actual[o['name']]['mirrorOf']) or
           (o['enabled'] and actual[o['name']].get('dpmsStatus') is False) for o in proposed):
        return dict(result,state='projection-changed',message='Projection or sleep state differs; automatic recovery is paused.')
    fallen=[]
    for out in proposed:
        monitor=actual[out['name']]
        w,h,_=mode_parts(out['mode'])
        if out['enabled'] and not out.get('mirrorOf') and (monitor.get('physicalWidth') or 0)>0 and \
           int(monitor.get('width') or 0)>0 and int(monitor.get('height') or 0)>0 and \
           int(monitor['width'])*int(monitor['height'])<=800*600 and w*h>=1280*720:
            fallen.append(out['name'])
    if not fallen:return dict(result,state='healthy',message='No low-resolution display fallback detected.')
    result.update(needed=True,canAttempt=True,state='fallback-detected',outputs=fallen,
                  message='Low-resolution fallback on '+', '.join(fallen)+'. Recovery uses the last confirmed complete layout.')
    if transaction_active():
        return dict(result,canAttempt=False,state='preview-active',message='Display recovery waits for the current preview or recovery to finish.')
    log=read_json(runtime_dir()/'display-auto-recovery.json',{})
    setup=hashlib.sha256(json.dumps(sorted(m['key'] for m in inventory)).encode()).hexdigest()
    if log.get('instance')==instance() and log.get('setup')==setup:
        now=boottime();attempts=[t for t in log.get('attempts',[]) if now-t<600]
        wait=max(0,60-(now-log['lastAttempt'])) if 'lastAttempt' in log else 0
        if len(attempts)>=3:wait=max(wait,600-(now-min(attempts)))
        if wait>0:return dict(result,canAttempt=False,state='cooldown',retryIn=math.ceil(wait),message='Automatic recovery paused for '+str(math.ceil(wait))+' seconds after recent attempts; no retry loop.')
    return result


def recovery_config(request):
    if type(request.get('enabled')) is not bool:raise ValueError('Recovery preference must be true or false')
    with locked():
        if transaction_active():raise ValueError('Finish the display preview before changing recovery policy')
        data=store();data['autoRecovery']=request['enabled'];atomic_json(store_path(),data)
        (runtime_dir()/'display-auto-recovery.json').unlink(missing_ok=True)
    return dict(ok=True,state='policy-updated',message='Automatic display recovery '+('enabled.' if request['enabled'] else 'disabled.'))


def auto_recover():
    """Explicitly enabled repair: stable fallback, exact setup, rate-limited guard."""
    if not instance():raise ValueError('Automatic recovery requires an explicit compositor instance')
    runtime_dir().mkdir(parents=True,exist_ok=True,mode=0o700)
    with (runtime_dir()/'display-auto-recovery.lock').open('a') as owner:
        os.chmod(owner.name,0o600)
        try:fcntl.flock(owner,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:return dict(ok=True,state='recovery-running',message='Another recovery check is running.')
        snap=snapshot(False);data=store();health=recovery_health(data,snap['displays'])
        if not health['canAttempt']:return dict(ok=True,state=health['state'],message=health['message'])
        setup=hashlib.sha256(json.dumps(sorted(m['key'] for m in snap['displays'])).encode()).hexdigest()
        path=runtime_dir()/'display-auto-recovery.json';log=read_json(path,{})
        if log.get('instance')!=instance() or log.get('setup')!=setup:log=dict(instance=instance(),setup=setup,attempts=[])
        now=boottime()
        if log.get('observedDigest')!=snap['digest']:
            log.update(observedDigest=snap['digest'],firstSeen=now);atomic_json(path,log)
            return dict(ok=True,state='recovery-observing',message='Waiting for the fallback layout to settle before recovery.')
        if now-log.get('firstSeen',now)<2:
            return dict(ok=True,state='recovery-observing',message='Waiting for the fallback layout to settle before recovery.')
        log['attempts']=[t for t in log.get('attempts',[]) if now-t<600]+[now];log['lastAttempt']=now
        atomic_json(path,log)
        try:
            proposed=confirmed_layout(data,snap['displays'])
            preview=begin(dict(baseDigest=snap['digest'],outputs=proposed,primary=data.get('primary',''),autoRecovery=True))
            confirm(preview['token'],persist=False)
            result=dict(ok=True,state='auto-recovered',message='Automatically restored the confirmed working layout after a low-resolution fallback. Requested unsupported modes were not saved.')
        except Exception as error:
            result=dict(ok=False,state='auto-recovery-failed',message=str(error)[:800])
        log['lastResult']=result;atomic_json(path,log)
        return result


def save_current():
    # Saving an already running layout does not reconfigure any output.
    snap = snapshot()
    with locked():
        if transaction_active():
            raise ValueError('Keep or revert the display preview before saving')
        data = store()
        inventory = enumerate_displays(query('monitors','all'),data)
        if topology_digest(inventory) != snap['digest']:
            raise ValueError('Displays changed while saving; detect and try again')
        outputs = validate([configuration(m) for m in inventory],inventory)
        data['lastKnownGood'] = outputs
        atomic_json(store_path(),data)
    return dict(ok=True,state='saved',message='Running display layout saved for startup. No output modes changed.')


def accept_recovery(token):
    """Explicit user acknowledgement of visible fallback; no device writes/save."""
    snap = snapshot()
    with locked():
        state = read_json(state_path(), {})
        if state.get('token') != token or state.get('state') != 'recovery-failed':
            raise ValueError('Only a failed recovery can accept a visible fallback')
        if state.get('instance') != instance():
            raise ValueError('Compositor session changed; refusing stale acknowledgement')
        inventory = enumerate_displays(query('monitors','all'),store())
        if topology_digest(inventory) != snap['digest']:
            raise ValueError('Display layout changed during acknowledgement; inspect it again')
        outputs = validate([configuration(m) for m in inventory],inventory)
        if not any(not m.get('disabled') and m.get('dpmsStatus') is True and (m.get('physicalWidth') or 0)>0 and m.get('mirrorOf') in ('none','',None) for m in inventory):
            raise ValueError('No awake independent physical display could be verified')
        verify(outputs)
        if 'commitStoreBefore' in state:
            atomic_json(store_path(),state['commitStoreBefore'])
        state.update(state='recovered-safe', recoveryError=state.get('message',''),
                     acceptedCurrent=outputs,
                     message='User confirmed the running displays are visible. Current fallback accepted for this session only; original layout was not fully restored and nothing was saved.')
        atomic_json(state_path(),state)
    return dict(ok=True,state='recovered-safe',message=state['message'])


def main(argv):
    try:
        operation = argv[1] if len(argv) > 1 else 'snapshot'
        argument = argv[2] if len(argv) > 2 else '{}'
        if operation == 'watchdog':
            watchdog(argument)
            return 0
        if operation == 'snapshot':
            result = dict(ok=True, **snapshot())
        elif operation == 'auto-recover':
            result = auto_recover()
        elif operation == 'recovery-config':
            result = recovery_config(json.loads(argument))
        elif operation == 'draft-save':
            result = save_editor_draft(json.loads(argument))
        elif operation == 'projection-plan':
            result = projection_plan(json.loads(argument))
        elif operation == 'apply-topology':
            result = begin(json.loads(argument))
        elif operation in ('keep', 'persist', 'keep-session'):
            result = confirm(argument, persist=operation != 'keep-session')
        elif operation == 'revert':
            result = revert(argument)
        elif operation == 'status':
            result = dict(ok=True, **public_state())
        elif operation.startswith('profile-'):
            result = profile_operation(operation, json.loads(argument))
        elif operation == 'shortcut':
            result = shortcut(int(argument), argv[3] if len(argv)>3 else 'switch')
        elif operation == 'workspace':
            result = workspace_operation(json.loads(argument))
        elif operation == 'restore':
            result = restore_startup()
        elif operation == 'restore-policy':
            result = restore_policy()
        elif operation == 'save-current':
            result = save_current()
        elif operation == 'accept-recovery':
            result = accept_recovery(argument)
        else:
            raise ValueError('Unsupported operation; update the display editor before applying')
        print(json.dumps(result, separators=(',', ':')))
        return 0 if result.get('ok', True) else 1
    except Exception as exc:
        print(json.dumps(dict(ok=False, error=str(exc)[:800], transaction=public_state()), separators=(',', ':')))
        return 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
