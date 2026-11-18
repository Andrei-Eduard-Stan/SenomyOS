#!/usr/bin/env python3
"""Global Hyprland Lua input configuration: observe, preview, confirm, restore.

No shell evaluation, legacy keywords, device disabling, or implicit migration.
The compositor owns preview expiry; Quickshell and this helper need not survive.
Readback verifies global configuration, not unexposed libinput/device overrides.
"""
import contextlib
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import uuid
import xml.etree.ElementTree as ET

SCHEMA = 2
PREVIEW_MS = 20000
# UI field -> (fixed compositor option, scalar type, hardware class).
FIELDS = {
    'sensitivity': ('input:sensitivity', float, 'pointer'),
    'naturalScroll': ('input:touchpad:natural_scroll', bool, 'touchpad'),
    'tapToClick': ('input:touchpad:tap-to-click', bool, 'touchpad'),
    'repeatRate': ('input:repeat_rate', int, 'keyboard'),
    'repeatDelay': ('input:repeat_delay', int, 'keyboard'),
    'mouseNaturalScroll': ('input:natural_scroll', bool, 'mouse'),
    'mouseScrollFactor': ('input:scroll_factor', float, 'mouse'),
    'touchpadScrollFactor': ('input:touchpad:scroll_factor', float, 'touchpad'),
    'disableWhileTyping': ('input:touchpad:disable_while_typing', bool, 'touchpad'),
    'leftHanded': ('input:left_handed', bool, 'pointer'),
}
LAYOUT_FIELDS = {'layout', 'variant', 'usFallback'}
EXTRA_OPTIONS = ['input:kb_layout', 'input:kb_variant', 'input:kb_file', 'input:accel_profile']
OPTIONS = list(dict.fromkeys([d[0] for d in FIELDS.values()] + EXTRA_OPTIONS))
GLOBAL = 'senomy_input_preview_v2'
DEADLINE = None


class InputError(Exception):
    def __init__(self, state, message, detail=''):
        super().__init__(message)
        self.state, self.detail = state, detail[:500]


def run(args):
    remaining = 4 if DEADLINE is None else min(4, DEADLINE - time.monotonic())
    if remaining <= 0:
        raise InputError('timed-out', 'Input operation exceeded its deadline. Refresh before retrying.')
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=remaining)
    except FileNotFoundError as error:
        raise InputError('unavailable', 'Hyprland control is unavailable.') from error
    except subprocess.TimeoutExpired as error:
        raise InputError('timed-out', 'Hyprland did not respond in time. The result is uncertain; refresh before retrying.') from error
    except OSError as error:
        raise InputError('transport-failed', 'Could not contact the compositor.') from error
    if result.returncode != 0:
        raise InputError('transport-failed', 'Hyprland control failed. Refresh before retrying.', result.stderr)
    return result.stdout.strip()


def hypr(*args):
    binary = shutil.which('hyprctl')
    if not binary:
        raise InputError('unavailable', 'Hyprland control is not installed.')
    return run([binary, *args])


def evaluate(source):
    response = hypr('eval', source)
    if response != 'ok':
        if 'input state changed before submission' in response:
            raise InputError('stale', 'Input values changed immediately before application. Your external changes were preserved.', response)
        raise InputError('rejected', 'Hyprland rejected the change. No preference was saved.', response)


def lua(value):
    """Byte-escape strings, including quotes/control/Unicode; never accept code."""
    if type(value) is bool:
        return 'true' if value else 'false'
    if type(value) in (int, float) and math.isfinite(value):
        return json.dumps(value, allow_nan=False)
    if isinstance(value, str):
        return '"' + ''.join('\\%03d' % b for b in value.encode('utf-8')) + '"'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    raise ValueError('Unsupported Lua data type')


def table(values):
    tree = {}
    for option, value in values.items():
        if option not in OPTIONS:
            raise ValueError('Option outside fixed input allowlist')
        node = tree
        parts = option.split(':')
        for part in parts[:-1]:
            node = node.setdefault(part, {})
        node[parts[-1]] = value
    return lua(tree)


def catalog():
    try:
        root = ET.parse('/usr/share/X11/xkb/rules/base.xml').getroot()
        return {e.findtext('configItem/name'): [''] + [v.findtext('configItem/name') for v in e.findall('variantList/variant')]
                for e in root.findall('layoutList/layout')}
    except (OSError, ET.ParseError) as error:
        raise InputError('unavailable', 'The system XKB layout/variant catalog is unavailable.') from error


def same(a, b):
    if type(a) in (float, int) and type(b) in (float, int):
        return math.isclose(a, b, abs_tol=0.00001, rel_tol=0)
    return type(a) is type(b) and a == b


def option_values():
    # Hyprland's JSON batch is a stream of JSON objects, not a JSON array.
    text = hypr('-j', '--batch', ';'.join('getoption ' + x for x in OPTIONS))
    decoder, result = json.JSONDecoder(), {}
    try:
        while text.strip():
            item, end = decoder.raw_decode(text.lstrip())
            text = text.lstrip()[end:]
            key = item['option']
            if key not in OPTIONS or key in result:
                raise ValueError('unexpected or duplicate option')
            types = [t for t in ('bool', 'int', 'float', 'str') if t in item]
            if len(types) != 1:
                raise ValueError('invalid option type')
            value = item[types[0]]
            expected = next((d[1] for d in FIELDS.values() if d[0] == key), str)
            if expected is float:
                if type(value) not in (int, float) or not math.isfinite(value):
                    raise ValueError('invalid numeric readback')
                value = float(value)
            elif type(value) is not expected:
                raise ValueError('invalid readback type')
            if value == '[[EMPTY]]':
                value = ''  # hl.get_config pushes the empty sentinel as "".
            result[key] = value
    except (ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        raise InputError('verification-unavailable', 'Effective compositor input values could not be read. Nothing was saved.') from error
    if set(result) != set(OPTIONS):
        raise InputError('verification-unavailable', 'Some input options lack authoritative readback; applying is disabled.')
    return result


def device_info():
    try:
        data = json.loads(hypr('-j', 'devices'))
        if not isinstance(data, dict) or any(not isinstance(data.get(k), list) for k in ('mice', 'keyboards', 'touch', 'tablets')):
            raise ValueError('missing device lists')
    except (ValueError, TypeError) as error:
        raise InputError('verification-unavailable', 'Connected input devices could not be identified.') from error
    # Join udev classification conservatively by normalized kernel name. Never
    # infer a touchpad from a model-name substring or write to event devices.
    kernel = {}
    for event in Path('/sys/class/input').glob('event*'):
        try:
            name = (event / 'device/name').read_text().strip().lower().replace(' ', '-')
            reply = run(['udevadm', 'info', '--query=property', '--path=' + str(event)])
            props = dict(l.split('=', 1) for l in reply.splitlines() if '=' in l)
            kind = ('touchpad' if props.get('ID_INPUT_TOUCHPAD') == '1' else
                    'keyboard' if props.get('ID_INPUT_KEYBOARD') == '1' else
                    'touchscreen' if props.get('ID_INPUT_TOUCHSCREEN') == '1' else
                    'pointer' if props.get('ID_INPUT_MOUSE') == '1' else 'unknown')
            kernel.setdefault(name, []).append(kind)
        except (OSError, InputError):
            continue
    devices = []
    for group in ('mice', 'keyboards', 'touch', 'tablets'):
        for item in data[group]:
            if not isinstance(item, dict) or not isinstance(item.get('name'), str) or not isinstance(item.get('address'), str):
                raise InputError('verification-unavailable', 'Input device identity data is invalid.')
            kinds = kernel.get(item['name'], [])
            kind = kinds[0] if len(kinds) == 1 else 'unknown'
            devices.append({'name': item['name'], 'sessionId': item['address'], 'kind': kind,
                            'group': group, 'main': item.get('main') is True,
                            'layout': item.get('layout'), 'variant': item.get('variant'),
                            'activeKeymap': item.get('active_keymap'),
                            'capabilityEvidence': 'udev class and compositor options; physical driver support unverified',
                            'perDeviceEditing': False})
    return devices


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def identity_digest(devices):
    return digest([{k: d.get(k) for k in ('name', 'sessionId', 'kind', 'group', 'main')} for d in devices])


def path_config():
    return Path(os.environ.get('XDG_CONFIG_HOME') or str(Path.home() / '.config')) / 'senomyos/input.json'


def path_state():
    return Path(os.environ.get('XDG_STATE_HOME') or str(Path.home() / '.local/state')) / 'senomyos/input'


def read_json(path):
    if path.is_symlink():
        raise InputError('invalid-preferences', 'Input state is a symbolic link; it was preserved without following it.')
    try:
        if path.stat().st_uid != os.getuid() or not stat.S_ISREG(path.stat().st_mode) or path.stat().st_size > 65536:
            raise ValueError('unsafe owner, size or file type')
        return json.loads(path.read_text())
    except FileNotFoundError:
        return None
    except (OSError, ValueError) as error:
        raise InputError('invalid-preferences', 'Input state is invalid or unreadable; the existing file was preserved.') from error


def atomic(path, value):
    if path.parent.is_symlink() or path.is_symlink():
        raise OSError('Refusing linked preference/state paths')
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.parent.stat().st_uid != os.getuid() or path.parent.stat().st_mode & 0o022:
        raise OSError('Unsafe preference directory owner or permissions')
    fd, name = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, indent=2, allow_nan=False); stream.write('\n'); stream.flush(); os.fsync(stream.fileno())
        os.chmod(name, 0o600)
        os.replace(name, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(name):
            os.unlink(name)


@contextlib.contextmanager
def locked():
    parent = path_state(); parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if parent.is_symlink() or parent.stat().st_uid != os.getuid() or parent.stat().st_mode & 0o077:
        raise InputError('unavailable', 'Input transaction directory is not private.')
    fd = os.open(parent / 'lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise InputError('busy', 'Another input operation is pending. Wait for its result.') from error
        yield
    finally:
        os.close(fd)


def validate(changes, layouts):
    if not isinstance(changes, dict) or not changes or set(changes) - (set(FIELDS) | LAYOUT_FIELDS):
        raise InputError('rejected', 'Input changes contain an unsupported setting.')
    for key, value in changes.items():
        if key in ('naturalScroll', 'tapToClick', 'usFallback', 'mouseNaturalScroll', 'disableWhileTyping', 'leftHanded'):
            valid = type(value) is bool
        elif key in ('repeatRate', 'repeatDelay'):
            valid = type(value) is int and (0 <= value <= 200 if key == 'repeatRate' else 0 <= value <= 2000)
        elif key in ('sensitivity', 'mouseScrollFactor', 'touchpadScrollFactor'):
            low, high = (-1, 1) if key == 'sensitivity' else (0, 2)
            valid = type(value) in (int, float) and math.isfinite(value) and low <= value <= high
        else:
            valid = isinstance(value, str)
        if not valid:
            raise InputError('rejected', 'The requested ' + key + ' value is invalid or out of range.')
    if set(changes) & LAYOUT_FIELDS:
        if not LAYOUT_FIELDS <= set(changes) or changes['layout'] not in layouts or changes['variant'] not in layouts[changes['layout']]:
            raise InputError('rejected', 'Choose an installed XKB layout and its matching variant.')
    changes = dict(changes)
    if changes.get('layout') == 'us':
        changes['usFallback'] = False
    return changes


def saved_preferences(layouts):
    data = read_json(path_config())
    if data is None:
        return {}, 'not-saved'
    if not isinstance(data, dict):
        raise InputError('invalid-preferences', 'Input preferences must be an object; the file was preserved.')
    if 'schemaVersion' not in data:
        legacy = {'sensitivity', 'naturalScroll', 'tapToClick', 'layout', 'usFallback', 'repeatRate', 'repeatDelay'}
        if set(data) - legacy:
            raise InputError('invalid-preferences', 'Unrecognized custom input preferences were preserved without replacement.')
        return {}, 'legacy-unverified'  # Never replay G03 false successes.
    if data.get('schemaVersion') != SCHEMA or data.get('verified') is not True:
        raise InputError('invalid-preferences', 'The input preference version or verification metadata is unsupported; the file was preserved.')
    try:
        if set(data) != {'schemaVersion', 'verified', 'preferences'}:
            raise InputError('invalid-preferences', 'Input preferences contain unknown metadata; the custom file was preserved.')
        return validate(data['preferences'], layouts), 'saved'
    except (InputError, KeyError):
        raise InputError('invalid-preferences', 'Saved input preferences are invalid; they were preserved and not restored.')


def pending_status():
    text = hypr('repl', 'local p=_G.' + GLOBAL + '; return (p and (p.token..":"..p.state) or "none")..(_G.senomy_input_restore_v2==true and ":durable" or ":runtime")')
    status, separator, durability = text.rpartition(':')
    if not separator or durability not in ('durable', 'runtime'):
        raise InputError('verification-unavailable', 'Input preview capability data is invalid.')
    if status == 'none':
        return {'state': 'none', 'token': '', 'persistenceReady': durability == 'durable'}
    match = re.fullmatch(r'([0-9a-f]{32}):([a-z-]+)', status)
    if not match:
        raise InputError('verification-unavailable', 'Input preview status could not be verified.')
    return {'token': match[1], 'state': match[2], 'persistenceReady': durability == 'durable'}


def snapshot():
    options, devices, layouts = option_values(), device_info(), catalog()
    effective = {key: options[desc[0]] for key, desc in FIELDS.items()}
    names, variants = options['input:kb_layout'].split(','), options['input:kb_variant'].split(',')
    editable = (not options['input:kb_file'] and len(names) <= 2 and names[0] in layouts and
                (len(names) == 1 or names[1] == 'us') and (variants[0] if variants else '') in layouts.get(names[0], []) and
                (len(variants) <= len(names)) and (len(variants) < 2 or not variants[1]))
    effective.update(layout=names[0], variant=variants[0], usFallback=len(names) == 2 and names[1] == 'us')
    capabilities = {key: any(x['kind'] == desc[2] or desc[2] == 'mouse' and x['kind'] == 'pointer' or desc[2] == 'pointer' and x['kind'] == 'touchpad' for x in devices) for key, desc in FIELDS.items()}
    editable = editable and all(x['layout'] == options['input:kb_layout'] for x in devices if x['kind'] == 'keyboard')
    capabilities.update({key: editable and any(x['kind'] == 'keyboard' for x in devices) for key in LAYOUT_FIELDS})
    warning = ''
    try:
        saved, persistence = saved_preferences(layouts)
    except InputError as error:
        saved, persistence, warning = {}, error.state, str(error)
    pending = pending_status()
    record = read_json(path_state() / 'preview.json')
    if record is not None and not isinstance(record, dict):
        raise InputError('invalid-preferences', 'Input preview state is invalid; it was preserved. Any compositor safety timer remains independent.')
    if record and record.get('token') == pending['token']:
        pending['requested'] = record.get('changes', {})
        pending['deadline'] = record.get('deadline', 0)
        pending['deviceChanged'] = record.get('deviceFingerprint') != identity_digest(devices)
    return {'schemaVersion': SCHEMA, 'ok': True, 'state': 'observed', 'available': True,
            'effective': effective, 'rawOptions': options, 'layouts': sorted(layouts), 'variants': layouts,
            'devices': devices, 'capabilities': capabilities, 'keyboardEditable': editable,
            'fingerprint': digest({'options': options, 'devices': devices}), 'deviceFingerprint': identity_digest(devices),
            'saved': saved, 'persistence': persistence, 'firstRun': persistence != 'saved',
            'externalConflict': any(not same(effective.get(k), v) for k, v in saved.items()),
            'pending': pending, 'persistenceReady': pending['persistenceReady'], 'verification': 'global-compositor-configuration',
            'message': warning, 'scope': 'Global defaults; per-device overrides and physical driver effects are not exposed by readback.'}


def to_options(changes):
    result = {FIELDS[k][0]: v for k, v in changes.items() if k in FIELDS}
    if set(changes) & LAYOUT_FIELDS:
        fallback = changes['usFallback'] and changes['layout'] != 'us'
        result['input:kb_layout'] = changes['layout'] + (',us' if fallback else '')
        result['input:kb_variant'] = changes['variant'] + (',' if fallback else '')
    return result


def config_code(values):
    return 'hl.config(' + table(values) + '); hl.exec_scheduled_prop_refresh_immediately()'


def restore_code(previous, proposed):
    # Only restore our own still-current values. Preserve a later external edit.
    lines = ['local function eq(a,b) if type(a)=="number" and type(b)=="number" then return math.abs(a-b)<0.00001 end; return a==b end; local conflict=false; local values={}']
    for key, value in proposed.items():
        lines += ['local v=hl.get_config(' + lua(key) + '); if eq(v,' + lua(value) + ') then values[' + lua(key) + ']=' + lua(previous[key]) +
                  ' elseif not eq(v,' + lua(previous[key]) + ') then conflict=true end']
    # A fixed option path map builds only allowlisted nested config tables.
    for key in proposed:
        # Separate calls avoid runtime-generated option names or evaluating text.
        lines.append('if values[' + lua(key) + ']~=nil then hl.config(' + table({key: previous[key]}) + ') end')
    lines.append('hl.exec_scheduled_prop_refresh_immediately()')
    lines.append('p.state=conflict and "external-change" or "rolled-back"')
    for key in previous:
        lines.append('if not eq(hl.get_config(' + lua(key) + '),' + lua(previous[key]) + ') then p.state="rollback-incomplete" end')
    return '; '.join(lines)


def arm_preview(token, previous, proposed):
    restore = restore_code(previous, proposed)
    checks = '; '.join('if not eq(hl.get_config(' + lua(k) + '),' + lua(v) + ') then error("input state changed before submission") end' for k, v in previous.items())
    source = ('local function eq(a,b) if type(a)=="number" and type(b)=="number" then return math.abs(a-b)<0.00001 end; return a==b end; ' + checks + '; if _G.' + GLOBAL + ' and _G.' + GLOBAL + '.state=="preview" then error("input preview already pending") end; '
              'local p={token=' + lua(token) + ',state="preview"}; _G.' + GLOBAL + '=p; '
              'p.restore=function() if p.state~="preview" then return end; ' + restore + ' end; '
              'p.timer=hl.timer(function() p.restore() end,{timeout=' + str(PREVIEW_MS) + ',type="oneshot"}); '
              'if not p.timer then error("preview timer unavailable") end; ' + config_code(proposed))
    evaluate(source)


def finish_preview(token, confirm):
    if not re.fullmatch('[0-9a-f]{32}', token):
        raise InputError('rejected', 'Input preview identity is invalid.')
    source = ('local p=_G.' + GLOBAL + '; if not p or p.token~=' + lua(token) + ' or p.state~="preview" then error("preview expired or replaced") end; ')
    source += ('p.state="confirmed"' if confirm else 'p.restore()')
    evaluate(source)


def result(state, message, ok=False, **extra):
    try:
        data = snapshot()
    except InputError:
        data = {'schemaVersion': SCHEMA, 'available': False, 'effective': {}, 'capabilities': {}}
    data.update(ok=ok, state=state, message=message, **extra)
    return data


def preview(request):
    if not isinstance(request, dict):
        raise InputError('rejected', 'Invalid input transaction.')
    changes = validate(request.get('changes'), catalog())
    before = snapshot()
    if before['persistence'] == 'invalid-preferences':
        raise InputError('invalid-preferences', 'Preserve and repair the invalid input preference file before applying.')
    if before['pending']['state'] == 'preview':
        raise InputError('busy', 'Confirm or revert the pending input preview first.')
    if request.get('fingerprint') != before['fingerprint']:
        raise InputError('stale', 'Input configuration or devices changed. Refresh and review your changes again.')
    if any(not before['capabilities'].get(k) for k in changes):
        raise InputError('unsupported', 'This global setting is unavailable for the connected input devices or custom keymap.')
    proposed = to_options(changes)
    # repeat_delay lacks a refresh bit in 0.56.2. A same-value repeat_rate
    # schedules the input refresh; it is observed and guarded with the change.
    if 'repeatDelay' in changes:
        proposed.setdefault('input:repeat_rate', before['rawOptions']['input:repeat_rate'])
    previous = {k: before['rawOptions'][k] for k in proposed}
    token = uuid.uuid4().hex
    record = {'token': token, 'changes': changes, 'previous': previous, 'proposed': proposed,
              'deviceFingerprint': before['deviceFingerprint'], 'deadline': int(time.time() * 1000) + PREVIEW_MS}
    atomic(path_state() / 'preview.json', record)
    try:
        arm_preview(token, previous, proposed)
        after = snapshot()
        if after['deviceFingerprint'] != before['deviceFingerprint']:
            raise InputError('device-unavailable', 'An input device changed during application. The preview is being reverted.')
        if any(not same(after['rawOptions'][k], v) for k, v in proposed.items()):
            raise InputError('readback-mismatch', 'Hyprland did not report the requested compositor values. No preference was saved.')
        if 'layout' in changes and any(x['layout'] != proposed['input:kb_layout'] or (x['variant'] or '').rstrip(',') != proposed['input:kb_variant'].rstrip(',') for x in after['devices'] if x['kind'] == 'keyboard'):
            raise InputError('readback-mismatch', 'A keyboard did not report the requested layout and variant. No preference was saved.')
        if after['pending']['token'] != token or after['pending']['state'] != 'preview':
            raise InputError('verification-unavailable', 'The input safety preview could not be confirmed.')
    except InputError as error:
        if error.state == 'stale':
            return result('stale', str(error), cause=error.state, persisted=False)
        try:
            finish_preview(token, False)
            actual = option_values()
            restored = all(same(actual[k], v) for k, v in previous.items())
        except InputError:
            try:
                actual = option_values(); restored = all(same(actual[k], v) for k, v in previous.items())
            except InputError:
                restored = False
        return result(('rejected' if error.state == 'rejected' else 'rolled-back') if restored else 'partially-applied', str(error) + (' Previous compositor values were restored.' if restored else ' Restoration could not be confirmed. Review current values; the compositor timer may still be active.'),
                      cause=error.state, detail=error.detail, persisted=False)
    return result('preview', 'Compositor values verified. Keep within 20 seconds to save, or they revert automatically. Physical device behavior is not yet verified.',
                  True, persisted=False)


def complete(token, confirm):
    current = snapshot(); record = read_json(path_state() / 'preview.json')
    if record is not None and (not isinstance(record, dict) or not all(k in record for k in ('token', 'previous', 'proposed', 'changes', 'deviceFingerprint'))):
        raise InputError('invalid-preferences', 'The preview record is incomplete. Nothing was saved; the compositor safety timer remains independent.')
    if not record or current['pending']['token'] != token or current['pending']['state'] != 'preview':
        raise InputError('stale', 'The input preview expired or changed. Nothing was saved.')
    if confirm and (current['deviceFingerprint'] != record['deviceFingerprint'] or
                    any(not same(current['rawOptions'][k], v) for k, v in record['proposed'].items())):
        finish_preview(token, False)
        return result('external-change', 'Devices or configuration changed during preview. Nothing was saved; refresh and review again.', persisted=False)
    finish_preview(token, confirm)
    if not confirm:
        actual = option_values()
        restored = all(same(actual[k], v) for k, v in record['previous'].items())
        return result('rolled-back' if restored else 'rollback-incomplete',
                      'Previous compositor values restored.' if restored else 'An external change prevented complete restoration. Review current values.', restored, persisted=False)
    confirmed = snapshot()
    actual = confirmed['rawOptions']
    if confirmed['deviceFingerprint'] != record['deviceFingerprint']:
        return result('device-unavailable', 'A device changed before saving. Confirmed global values may remain temporarily active; no preference was saved.', persisted=False)
    if any(not same(actual[k], v) for k, v in record['proposed'].items()):
        return result('verification-unavailable', 'Compositor values changed before saving. Nothing was saved.', persisted=False)
    if not current['persistenceReady']:
        return result('applied-not-persisted', 'Confirmed compositor values are active only for now. The reload persistence hook is not active; no preference was saved.', persisted=False)
    try:
        saved, status = saved_preferences(catalog())
        if status == 'legacy-unverified':
            # Preserve the original false-success-era file before explicit migration.
            original = path_config()
            backup = path_state() / ('legacy-input-' + str(time.time_ns()) + '.json')
            atomic(backup, read_json(original))
        merged = dict(saved, **record['changes'])
        atomic(path_config(), {'schemaVersion': SCHEMA, 'verified': True, 'preferences': merged})
    except (OSError, InputError) as error:
        return result('applied-persistence-failed', 'The confirmed compositor change is active, but durable saving could not be confirmed.', persisted=False, detail=str(error)[:300])
    return result('applied-verified', 'Compositor values verified and saved. Per-device overrides and physical behavior remain separate.', True, persisted=True)


def restore():
    if pending_status()['state'] == 'preview':
        raise InputError('busy', 'Confirm or revert the pending preview before restoring preferences.')
    changes, persistence = saved_preferences(catalog())
    if persistence != 'saved':
        return result('not-restored', 'No verified input preferences to restore. Existing configuration was preserved.', True, persisted=False)
    # Called only by the owned config.reloaded hook: defaults have just reset.
    # No missing-device rejection: these are global defaults for future hotplug.
    previous = option_values(); proposed = to_options(changes)
    if 'repeatDelay' in changes:
        proposed.setdefault('input:repeat_rate', previous['input:repeat_rate'])
    try:
        evaluate(config_code(proposed))
        current = option_values()
        if any(not same(current[k], v) for k, v in proposed.items()):
            raise InputError('readback-mismatch', 'Saved compositor input values could not be verified.')
    except InputError as error:
        old = {k: previous[k] for k in proposed}
        try:
            evaluate('local p={}; ' + restore_code(old, proposed))
            actual = option_values(); restored = all(same(actual[k], v) for k, v in old.items())
        except InputError:
            restored = False
        return result('rolled-back' if restored else 'partially-applied', 'Input restore failed; saved preferences were not altered.', cause=error.state)
    return result('restored-verified', 'Saved global compositor input values restored and verified.', True, persisted=True)


def main(argv):
    global DEADLINE
    operation = argv[1] if len(argv) > 1 else 'get'
    DEADLINE = time.monotonic() + (8 if operation == 'get' else 25)
    request_id = ''
    try:
        if operation == 'get' and len(argv) <= 3:
            request_id = argv[2] if len(argv) == 3 else ''
            data = snapshot()
        elif operation in ('apply', 'confirm', 'revert', 'restore'):
            if operation != 'restore' and len(argv) != 3:
                raise InputError('rejected', 'Missing input transaction payload.')
            payload = json.loads(argv[2]) if operation != 'restore' else {}
            if not isinstance(payload, dict):
                raise InputError('rejected', 'Input transaction payload must be an object.')
            request_id = payload.get('requestId', '')
            with locked():
                data = preview(payload) if operation == 'apply' else restore() if operation == 'restore' else complete(payload.get('token', ''), operation == 'confirm')
        else:
            raise InputError('unsupported', 'Unsupported input settings operation.')
    except InputError as error:
        data = result(error.state, str(error), detail=error.detail, persisted=False) if operation != 'get' else {'schemaVersion': SCHEMA, 'ok': False, 'available': False, 'state': error.state, 'message': str(error), 'effective': {}, 'capabilities': {}}
    except (OSError, ValueError, TypeError, KeyError) as error:
        data = result('failed', 'Input operation could not be completed. Refresh current values before retrying.', detail=str(error)[:300], persisted=False)
    # Display-only compatibility for a cached pre-WP02 QML instance. Legacy
    # apply payloads remain rejected; this alias contains observed values only.
    if data.get('available') is True:
        data['preferences'] = data.get('effective', {})
    if not data['ok']:
        data['error'] = data['message']
    data['requestId'] = request_id
    print(json.dumps(data, separators=(',', ':'), allow_nan=False))
    return 0 if data['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
