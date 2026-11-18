#!/usr/bin/python3 -I
"""Narrow TLP battery-care transaction. No sysfs writer or shell evaluation.

Installed root-owned by the existing system deployer. pkexec authenticates each
apply/restore. CLI accepts no path/environment overrides. Tests inject a system.
"""
import base64
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import time
import uuid

BATTERIES = ('BAT0', 'BAT1')
HEADER = '# SenomyOS battery care v1; managed by authenticated transactions.\n'
UNITS = ('tlp.service', 'tlp-pd.service', 'power-profiles-daemon.service', 'tuned.service', 'tuned-ppd.service', 'auto-cpufreq.service', 'system76-power.service')
SAFE_ENV = {'PATH': '/usr/bin:/bin', 'LC_ALL': 'C', 'LANG': 'C'}


class Refused(Exception):
    pass


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def text(p):
    try:
        return p.read_text().strip()
    except OSError:
        return None


def number(p, scale=1):
    try:
        n = float(text(p)) / scale
        return n if math.isfinite(n) and n >= 0 else None
    except (TypeError, ValueError):
        return None


def pair(value):
    if not isinstance(value, list) or len(value) != 2 or any(type(x) is not int for x in value):
        raise Refused('Thresholds must be integer start/stop pairs.')
    a, b = value
    if not 0 <= a <= 99 or not 1 <= b <= 100 or a >= b:
        raise Refused('This driver requires start 0–99, stop 1–100 and start < stop.')
    return value


def managed_values(data):
    if data is None:
        return {}
    s = base64.b64decode(data['bytes']).decode('ascii')
    if not s.startswith(HEADER):
        raise Refused('The managed drop-in contains unrecognised content. Preserve it and review manually.')
    values = {}
    for line in s[len(HEADER):].splitlines():
        m = re.fullmatch(r'(START|STOP)_CHARGE_THRESH_(BAT[01])=(\d{1,3})', line)
        if not m or (m[2], m[1]) in values:
            raise Refused('The managed drop-in is invalid; no overwrite is allowed.')
        values[m[2], m[1]] = int(m[3])
    result = {}
    for b in BATTERIES:
        if (b, 'START') in values or (b, 'STOP') in values:
            result[b] = pair([values.get((b, 'START')), values.get((b, 'STOP'))])
    return result


def render(values):
    return (HEADER + ''.join(f'{kind}_CHARGE_THRESH_{b}={v}\n' for b in sorted(values) for kind, v in zip(('START', 'STOP'), pair(values[b])))).encode()


def request_valid(request, restore=False):
    keys = {'token', 'receipt'} if restore else {'token', 'changes', 'persistent'}
    if not isinstance(request, dict) or set(request) != keys or not isinstance(request.get('token'), str) or not re.fullmatch(r'[0-9a-f]{64}', request['token']):
        raise Refused('Invalid battery-care request. Refresh and review again.')
    if restore:
        if not isinstance(request['receipt'], str) or not re.fullmatch(r'[0-9a-f]{32}', request['receipt']):
            raise Refused('Invalid recovery receipt.')
    else:
        if type(request['persistent']) is not bool or not isinstance(request['changes'], dict) or not 1 <= len(request['changes']) <= 2:
            raise Refused('Choose runtime or persistent changes for one or two supported packs.')
        for b, v in request['changes'].items():
            if b not in BATTERIES:
                raise Refused('Unsupported battery target.')
            pair(v)


class Machine:
    def __init__(self, sysroot=Path('/sys'), etc=Path('/etc'), state=Path('/var/lib/senomyos/battery-care')):
        self.sysroot, self.etc, self.state = sysroot, etc, state
        self.deadline = None
        self.config = etc/'tlp.d/99-senomyos-battery-care.conf'

    def run(self, argv, timeout=10):
        if self.deadline is not None:
            remaining = self.deadline - time.monotonic()
            if remaining <= 0:
                raise Refused('Battery-care operation deadline expired. Inspect readback/recovery records; do not assume completion.')
            timeout = min(timeout, remaining)
        return subprocess.run(argv, capture_output=True, text=True, timeout=timeout, env=SAFE_ENV)

    def bus(self, *args):
        p = self.run(['/usr/bin/busctl', '--system', '--json=short', '--auto-start=no', *args])
        if p.returncode:
            raise Refused('UPower ownership/state could not be read. Writes are disabled.')
        return json.loads(p.stdout)['data']

    def upower(self):
        owner = self.bus('call', 'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'GetNameOwner', 's', 'org.freedesktop.UPower')[0]
        paths = self.bus('call', owner, '/org/freedesktop/UPower', 'org.freedesktop.UPower', 'EnumerateDevices')[0]
        result = {}
        for path in paths[:16]:
            d = self.bus('call', owner, path, 'org.freedesktop.DBus.Properties', 'GetAll', 's', 'org.freedesktop.UPower.Device')[0]
            d = {k: v['data'] for k, v in d.items()}
            b = d.get('NativePath')
            if b in BATTERIES and d.get('IsPresent') is True:
                result[b] = {k: d.get(k) for k in ('EnergyFull', 'EnergyFullDesign', 'ChargeCycles', 'ChargeStartThreshold', 'ChargeEndThreshold', 'ChargeThresholdEnabled')}
        if self.bus('call', 'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'GetNameOwner', 's', 'org.freedesktop.UPower')[0] != owner:
            raise Refused('UPower ownership changed during discovery. Refresh before a request.')
        return owner, result

    def file_image(self, path):
        if not path.exists() and not path.is_symlink():
            return None
        s = path.lstat()
        if not stat.S_ISREG(s.st_mode) or s.st_uid != 0 or s.st_mode & 0o022 or s.st_size > 262144:
            raise Refused('TLP configuration must be bounded, root-owned and not writable by other accounts.')
        return {'bytes': base64.b64encode(path.read_bytes()).decode(), 'mode': stat.S_IMODE(s.st_mode), 'uid': s.st_uid, 'gid': s.st_gid}

    def configurations(self):
        paths = [Path('/usr/share/tlp/defaults.conf'), *sorted((self.etc/'tlp.d').glob('*.conf')), self.etc/'tlp.conf']
        images = {str(p): self.file_image(p) for p in paths}
        own = images.get(str(self.config))
        values = managed_values(own)
        conflict = False
        for name, image in images.items():
            if image is None or name == str(self.config):
                continue
            s = base64.b64decode(image['bytes']).decode('utf-8')
            # Conservatively refuse any other active threshold policy, including
            # unusual assignments. Never parse/evaluate arbitrary shell syntax.
            conflict |= any(re.search(r'(START|STOP)_CHARGE_THRESH_', line) is not None for line in s.splitlines() if line.strip() and not line.lstrip().startswith('#'))
        return images, values, conflict

    def snapshot(self):
        units = self.run(['/usr/bin/systemctl', 'show', *UNITS, '-p', 'Id', '-p', 'ActiveState', '-p', 'InvocationID', '-p', 'MainPID'])
        if units.returncode:
            raise Refused('Power-policy service ownership is unavailable.')
        records = [dict(line.split('=', 1) for line in block.splitlines() if '=' in line) for block in units.stdout.strip().split('\n\n')]
        active = [d.get('Id') for d in records if d.get('ActiveState') == 'active']
        if 'tlp.service' not in active or any(u not in ('tlp.service', 'tlp-pd.service') for u in active):
            raise Refused('TLP is inactive or another power-policy writer is active.')
        owner, up = self.upower()
        # Catch unmanaged compatible profile owners too. tlp-pd not installed on
        # this reviewed backend; fail closed rather than infer its identity.
        names = self.bus('call', 'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'ListNames')[0]
        if any(n in names for n in ('net.hadess.PowerProfiles', 'org.freedesktop.UPower.PowerProfiles')) or 'tlp-pd.service' in active:
            raise Refused('This care adapter requires the reviewed TLP-only ownership boundary.')
        images, configured, config_conflict = self.configurations()
        plugin = Path('/usr/share/tlp/bat.d/05-thinkpad')
        version = self.run(['/usr/bin/tlp', '--version']).stdout.strip()
        supported = (re.fullmatch(r'TLP(?: version)? 1\.10\.2', version) is not None and (self.sysroot/'module/thinkpad_acpi').is_dir() and plugin.is_file())
        packs = []
        stable = {}
        for p in sorted((self.sysroot/'class/power_supply').glob('*')):
            if text(p/'type') != 'Battery' or text(p/'present') == '0':
                continue
            effective = [number(p/'charge_control_start_threshold'), number(p/'charge_control_end_threshold')]
            eligible = text(p/'serial_number') not in (None, '', 'Unknown') and supported and p.name in BATTERIES and all(v is not None and int(v) == v for v in effective) and up.get(p.name, {}).get('ChargeThresholdEnabled') is False
            effective = [int(v) if v is not None and int(v) == v else v for v in effective]
            try:
                pair(effective)
            except Refused:
                eligible = False
            fingerprint = digest([str(p.resolve()), *[text(p/n) for n in ('serial_number', 'manufacturer', 'model_name', 'technology')]])
            kernel = {k: number(p/n, scale) for k, n, scale in (('fullWh', 'energy_full', 1e6), ('designWh', 'energy_full_design', 1e6), ('cycles', 'cycle_count', 1))}
            full, design = kernel['fullWh'], kernel['designWh'];basis = 'kernel energy_full / energy_full_design'
            if not full or not design:
                full, design = number(p/'charge_full'), number(p/'charge_full_design');basis = 'kernel charge_full / charge_full_design (same units)'
            health = full / design * 100 if full and design else None
            reported = up.get(p.name, {})
            mismatch = kernel['fullWh'] is not None and isinstance(reported.get('EnergyFull'), (int, float)) and abs(kernel['fullWh'] - reported['EnergyFull']) > 0.01
            warnings = []
            if mismatch: warnings.append('UPower and kernel full capacities differ; aggregate uses UPower.')
            if kernel['designWh'] is not None and isinstance(reported.get('EnergyFullDesign'), (int,float)) and abs(kernel['designWh'] - reported['EnergyFullDesign']) > 0.01: warnings.append('Design-capacity sources differ.')
            if kernel['cycles'] is not None and isinstance(reported.get('ChargeCycles'), (int,float)) and reported['ChargeCycles'] >= 0 and kernel['cycles'] != reported['ChargeCycles']: warnings.append('Cycle-count sources differ.')
            if health is not None and health > 100: warnings.append('Full capacity exceeds design; treat the capacity ratio cautiously.')
            packs.append({'name': p.name, 'sourceWarnings': warnings, 'identity': fingerprint, 'effective': effective, 'supported': eligible, 'startRange': [0, 99] if eligible else None, 'stopRange': [1, 100] if eligible else None, 'configured': configured.get(p.name), 'kernel': kernel, 'upower': reported, 'healthPercent': health, 'healthBasis': basis if health is not None else 'Unavailable: matching full/design capacity missing', 'capacityMismatch': mismatch, 'reason': 'TLP 1.10.2 thinkpad/natacpi; start < stop, 0/100 off. Capability revalidated after authentication.' if eligible else 'Unsupported/unverified driver, missing thresholds or UPower care enabled. No generic range is assumed.'})
            stable[p.name] = [fingerprint, effective, eligible, reported.get('ChargeThresholdEnabled')]
        sources = {p.name: text(p/'online') for p in (self.sysroot/'class/power_supply').glob('*') if text(p/'type') in ('Mains', 'USB', 'USB_C')}
        identity = digest([hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), records, owner, version, self.file_image(Path('/usr/bin/tlp')), self.file_image(plugin) if plugin.exists() else None])
        token = digest([identity, stable, sources, images])
        return {'ok': True, 'schemaVersion': 1, 'observedAt': int(time.time()), 'identity': identity, 'token': token, 'sources': sources, 'packs': packs, 'persistentAvailable': not config_conflict, 'persistenceReason': 'Another TLP file contains active threshold keys; preserve it and resolve ownership before saving.' if config_conflict else 'One managed TLP drop-in; all other TLP files preserved. Lifecycle acceptance pending.', 'configurationDigest': digest(images), 'otherConfigurationDigest': digest({n:v for n,v in images.items() if n != str(self.config)})}

    def validate_driver(self):
        p = self.run(['/usr/bin/tlp-stat', '-b'], timeout=15)
        # The privileged report is not returned to QML or evidence (serials).
        if p.returncode or not all(s in p.stdout for s in ('Plugin: thinkpad', 'natacpi (thinkpad_acpi) = active', 'START_CHARGE_THRESH_BAT0/1:  0(off)..96(default)..99', 'STOP_CHARGE_THRESH_BAT0/1:   1..100(default)')):
            raise Refused('TLP does not confirm the reviewed driver/ranges. No thresholds were submitted.')

    def set_pair(self, b, values):
        return self.run(['/usr/bin/tlp', 'setcharge', str(values[0]), str(values[1]), b], timeout=20).returncode == 0

    def verify_config(self, image):
        p = self.run(['/usr/bin/tlp-stat', '-c'], timeout=15)
        if p.returncode:
            return False
        output = re.sub(r'\x1b\[[0-9;]*m', '', p.stdout)
        parsed = {(m[1],m[0]):int(m[2]) for m in re.findall(r'(?m)^[^\n]*?\b(START|STOP)_CHARGE_THRESH_(BAT[01])="?(\d+)"?\s*$', output)}
        expected = {(b,kind):v for b,values in managed_values(image).items() for kind,v in zip(('START','STOP'),values)}
        return parsed == expected

    def replace_config(self, image):
        if image is None:
            self.config.unlink(missing_ok=True)
        else:
            self.config.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
            fd, name = tempfile.mkstemp(prefix='.senomy-battery-', dir=self.config.parent)
            try:
                with os.fdopen(fd, 'wb') as f:
                    f.write(base64.b64decode(image['bytes'])); f.flush(); os.fsync(f.fileno())
                    os.fchmod(f.fileno(), image['mode']); os.fchown(f.fileno(), image['uid'], image['gid'])
                os.replace(name, self.config)
            finally:
                Path(name).unlink(missing_ok=True)
        fd = os.open(self.config.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)

    def write_record(self, identifier, suffix, value):
        self.state.mkdir(mode=0o700, parents=True, exist_ok=True)
        trusted(self.state)
        st = self.state.lstat()
        if not stat.S_ISDIR(st.st_mode) or st.st_uid != 0 or st.st_mode & 0o077:
            raise Refused('Battery-care receipt directory is unsafe.')
        path = self.state/(identifier + suffix)
        fd, name = tempfile.mkstemp(prefix='.checkpoint-', dir=self.state)
        try:
            with os.fdopen(fd, 'w') as f:
                os.fchmod(f.fileno(), 0o600)
                json.dump(value, f); f.flush(); os.fsync(f.fileno())
            os.replace(name, path)
            fd = os.open(self.state, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(fd)
            finally:
                os.close(fd)
        finally:
            Path(name).unlink(missing_ok=True)

    def save(self, receipt):
        self.write_record(receipt['id'], '.json', {k:v for k,v in receipt.items() if not k.startswith('_')})

    def finalize(self, receipt):
        # A receipt alone is diagnostic. Publish its integrity-bound commit only
        # AFTER the complete receipt and directory have been durably synced.
        self.save(receipt)
        self.write_record(receipt['id'], '.commit', {'schemaVersion':2, 'id':receipt['id'], 'digest':digest(receipt)})

    def read_record(self, path):
        st = path.lstat()
        if not stat.S_ISREG(st.st_mode) or st.st_uid != 0 or st.st_mode & 0o077 or st.st_size > 1048576:
            raise Refused('Unsafe recovery receipt.')
        return json.loads(path.read_text())

    def load(self, identifier, uid):
        trusted(self.state)
        receipt = self.read_record(self.state/(identifier + '.json'))
        if receipt.get('uid') != uid or receipt.get('id') != identifier:
            raise Refused('This recovery receipt belongs to another account or transaction.')
        try:
            commit = self.read_record(self.state/(identifier + '.commit'))
        except (OSError, ValueError, Refused):
            commit = None
        receipt['_committed'] = commit == {'schemaVersion':2, 'id':identifier, 'digest':digest(receipt)}
        return receipt

    def history(self, uid):
        current = self.snapshot()
        receipts = []
        if self.state.exists():
            trusted(self.state)
            paths = sorted(self.state.glob('*.json'), key=lambda p: p.stat().st_mtime_ns, reverse=True)
            if len(paths) > 128:
                raise Refused('Receipt limit exceeded. An administrator must archive reviewed records.')
            for path in paths:
                if not re.fullmatch(r'[0-9a-f]{32}', path.stem):
                    continue
                try:
                    v = self.load(path.stem, uid)
                except (OSError, ValueError, TypeError, Refused):
                    continue
                if restorable(v, current):
                    receipts.append({'receipt':v['id'], 'previous':v['restoreChanges'], 'persistent':v['persistent'], 'restorableToken':v['afterToken']})
        return {'ok':True, 'state':'verified', 'snapshot':current, 'history':receipts, 'message':'Recovery records read. Restore still requires an explicit review and exact state match.'}


def checked(system, token):
    s = system.snapshot()
    if s['token'] != token:
        raise Refused('Provider, battery, source, thresholds or configuration changed. Refresh and review; no blind overwrite.')
    return s


def pack_state(snapshot):
    return {p['name']:{k:p[k] for k in ('identity','effective','supported')} for p in snapshot['packs']}


def restorable(receipt, current):
    """Only a committed, complete and still-exact transaction grants Restore."""
    try:
        if (receipt.get('schemaVersion') != 2 or receipt.get('_committed') is not True
                or receipt.get('checkpoint') != 'complete' or receipt.get('recoveryVerified') is not True or receipt.get('recoveryEligible') is not True
                or receipt.get('restored') or receipt['providerIdentity'] != current['identity']
                or receipt['sources'] != current['sources'] or receipt['afterToken'] != current['token']
                or receipt['afterPacks'] != pack_state(current)):
            return False
        expected = {}
        for b, result in receipt['results'].items():
            pair(receipt['previous'][b]); pair(result['requested'])
            if b not in BATTERIES or result['outcome'] not in ('untouched','unchanged','modified'):
                return False
            if result['outcome'] == 'modified':
                if result['attempted'] is not True or result['effective'] != current_pack(current, b)['effective']:
                    return False
                expected[b] = receipt['previous'][b]
        return receipt['restoreChanges'] == expected and bool(expected or receipt['configurationModified'])
    except (KeyError, TypeError, ValueError, AttributeError, StopIteration, Refused):
        return False


def current_pack(snapshot, name):
    return next(p for p in snapshot['packs'] if p['name'] == name)


def recovery_matches(system, receipt, before, current, image, wanted, config_written):
    if (current['identity'] != before['identity'] or current['sources'] != before['sources']
            or current['otherConfigurationDigest'] != before['otherConfigurationDigest']
            or set(pack_state(current)) != set(pack_state(before))):
        return False
    for p in current['packs']:
        old = current_pack(before, p['name']); result = receipt['results'].get(p['name'])
        if p['identity'] != old['identity'] or p['supported'] != old['supported']:
            return False
        if result and result['outcome'] == 'uncertain':
            return False  # timeout/lost reply can still complete late; never guess
        effective = result['effective'] if result and result['outcome'] == 'modified' else old['effective']
        if p['effective'] != effective:
            return False
    if config_written:
        return system.file_image(system.config) == wanted
    return current['configurationDigest'] == before['configurationDigest'] and system.file_image(system.config) == image


def operation(system, request, uid, restoring=False):
    request_valid(request, restoring)
    system.validate_driver()
    before = checked(system, request['token'])
    original = system.load(request['receipt'], uid) if restoring else None
    if original is not None:
        if not restorable(original, before):
            raise Refused('Recovery checkpoint is incomplete, unverified, already restored or its provider/state changed. No external work was overwritten.')
        changes = original['restoreChanges']
        persistent = original['persistent'] and original['configurationModified']
    else:
        changes, persistent = request['changes'], request['persistent']
    available = {p['name']:p for p in before['packs']}
    for b, values in changes.items():
        pair(values)
        if b not in available or not available[b]['supported']:
            raise Refused('One selected battery is unsupported or unavailable. Nothing was submitted.')
    if persistent and not before['persistentAvailable']:
        raise Refused(before['persistenceReason'])
    if sum(1 for _ in system.state.glob('*.json')) >= 128:
        raise Refused('Recovery receipt limit reached. Archive reviewed records before another operation.')
    image = system.file_image(system.config)
    receipt = {'schemaVersion':2, 'id':uuid.uuid4().hex, 'uid':uid, 'createdAt':int(time.time()),
               'previous':{b:available[b]['effective'] for b in changes}, 'persistent':persistent,
               'configBefore':image, 'beforeToken':before['token'], 'providerIdentity':before['identity'],
               'sources':before['sources'], 'afterToken':None, 'checkpoint':'in-progress',
               'recoveryEligible':False, 'recoveryVerified':False, 'restoreChanges':{}, 'configurationModified':False,
               'results':{b:{'requested':v, 'effective':available[b]['effective'], 'verified':False,
                             'alreadyEffective':False, 'attempted':False, 'outcome':'untouched'} for b,v in changes.items()},
               'restored':False, 'restoringReceipt':request.get('receipt')}
    system.save(receipt)  # durable preimage, never recovery authority
    current = before; config_written = False; wanted = image; journal_failed = False
    def save_progress():
        nonlocal journal_failed
        try:
            system.save(receipt)
        except Exception:
            journal_failed = True
            raise
    def finalize(ok):
        nonlocal journal_failed
        receipt['verified'] = ok
        receipt['recoveryVerified'] = True
        receipt['restoreChanges'] = {b:receipt['previous'][b] for b,r in receipt['results'].items() if r['outcome'] == 'modified'}
        receipt['configurationModified'] = config_written and wanted != image
        receipt['recoveryEligible'] = bool(receipt['restoreChanges'] or receipt['configurationModified'])
        receipt['afterPacks'] = pack_state(current)
        receipt['afterToken'] = current['token'] if receipt['recoveryEligible'] else None
        receipt['checkpoint'] = 'complete'
        try:
            system.finalize(receipt)
        except Exception:
            journal_failed = True
            raise
    try:
        for b, values in changes.items():
            checked(system, current['token'])
            result = receipt['results'][b]
            already = current_pack(current, b)['effective'] == values
            result['alreadyEffective'] = already
            if not already:
                # Write-ahead intent is uncertain until the call RETURNS and its
                # exact effects are read back; an interrupted record cannot restore.
                result['attempted'] = None  # crash between intent and call: possibly issued
                result['outcome'] = 'uncertain'; save_progress()
                result['attempted'] = True
            accepted = already or system.set_pair(b, values)
            after = system.snapshot(); actual = current_pack(after, b)['effective']
            same_context = (after['identity'] == before['identity'] and after['sources'] == before['sources']
                and after['configurationDigest'] == before['configurationDigest']
                and set(pack_state(after)) == set(pack_state(current))
                and all(p['identity'] == current_pack(current,p['name'])['identity']
                        and p['supported'] == current_pack(current,p['name'])['supported']
                        and (p['name'] == b or p['effective'] == current_pack(current,p['name'])['effective']) for p in after['packs']))
            # A completed but rejected command can have a known partial pair.
            known = same_context and all(actual[i] in (result['effective'][i], values[i]) for i in (0,1))
            result.update(effective=actual, verified=bool(accepted and actual == values and same_context),
                          outcome=('unchanged' if actual == receipt['previous'][b] else 'modified') if known else 'uncertain')
            current = after; save_progress()  # still no afterToken or commit
            if not result['verified']:
                raise Refused('TLP rejected the request, readback differed, or ownership/state drifted. Inspect per-pack results; no automatic rollback.')
        if persistent:
            checked(system, current['token'])
            if original is not None:
                wanted = original['configBefore']
            else:
                values = managed_values(image); values.update(changes)
                wanted = dict(image or {'mode':0o644,'uid':0,'gid':0}, bytes=base64.b64encode(render(values)).decode())
            receipt['configWanted'] = wanted; save_progress()
            system.replace_config(wanted); config_written = True
            if system.file_image(system.config) != wanted or not system.verify_config(wanted):
                raise Refused('Configuration readback did not match. Runtime may already have changed.')
            after = system.snapshot()
            if (after['otherConfigurationDigest'] != before['otherConfigurationDigest'] or after['identity'] != current['identity']
                    or after['sources'] != current['sources'] or pack_state(after) != pack_state(current)):
                raise Refused('State changed while saving configuration. Do not assume hardware success.')
            current = after
        # Revalidate immediately before publishing recovery authority.
        current = checked(system, current['token'])
        if not recovery_matches(system, receipt, before, current, image, wanted, config_written):
            raise Refused('Recovery state could not be established. Inspect the diagnostic receipt.')
        finalize(True)
        if original is not None:
            original['restored'] = True; system.save(original)
        return {'ok':True, 'state':'verified', 'results':receipt['results'], 'receipt':receipt['id'],
                'previous':receipt['restoreChanges'], 'persistent':persistent, 'restorableToken':receipt['afterToken'],
                'snapshot':current, 'message':'Threshold readback verified' + (' and managed configuration/TLP parser readback verified.' if persistent else '; runtime only.') + ' Actual charging behaviour and lifecycle persistence are not verified.'}
    except Exception as error:
        receipt.update(afterToken=None, recoveryEligible=False, recoveryVerified=False, checkpoint='diagnostic', verified=False)
        current = None
        try:
            current = system.snapshot()
            # Only normal, completed calls with positively reconciled effects
            # may form a VERIFIED recovery checkpoint after a failed operation.
            if not journal_failed and recovery_matches(system, receipt, before, current, image, wanted, config_written):
                finalize(False)
            else:
                save_progress()
        except Exception:
            receipt.update(afterToken=None, recoveryEligible=False, recoveryVerified=False, checkpoint='diagnostic')
            try:
                system.save(receipt)
            except Exception:
                pass  # uncommitted diagnostic preimage remains; no Restore authority
        changed = current is not None and (pack_state(current) != pack_state(before) or current['configurationDigest'] != before['configurationDigest'])
        state = 'partially-applied' if changed else 'rejected' if current is not None and isinstance(error, Refused) else 'unverified'
        return {'ok':False, 'state':state, 'results':receipt['results'], 'receipt':receipt['id'],
                'previous':receipt['restoreChanges'], 'persistent':persistent, 'restorableToken':receipt['afterToken'],
                'snapshot':current, 'message':str(error) if isinstance(error, Refused) else 'Operation interrupted or persistence failed. Inspect readback and the recovery receipt; no automatic retry/rollback.'}


def trusted(path):
    # No writable interpreter modules, script or parent paths at privilege boundary.
    for p in (path, *path.parents):
        s = p.lstat()
        if stat.S_ISLNK(s.st_mode) or s.st_uid != 0 or s.st_mode & 0o022:
            raise Refused('The installed helper and parents must be root-owned and protected.')


def main(argv):
    system = Machine()
    try:
        if len(argv) == 2 and argv[1] == 'get':
            result = system.snapshot()
        elif (len(argv) == 3 and argv[1] in ('apply', 'restore')) or (len(argv) == 2 and argv[1] == 'history'):
            if os.geteuid() != 0:
                raise Refused('Use the installed helper through normal polkit authentication.')
            trusted(Path(__file__).absolute())
            os.chdir('/'); os.umask(0o077)
            for p in (Path('/etc/tlp.d'), Path('/var/lib'), Path('/run/lock')):
                trusted(p)
            lock = Path('/run/lock/senomyos-battery-care.lock')
            fd = os.open(lock, os.O_CREAT | os.O_NOFOLLOW | os.O_RDWR, 0o600)
            if os.fstat(fd).st_uid != 0 or os.fstat(fd).st_mode & 0o077:
                raise Refused('Unsafe operation lock.')
            try:
                try:
                    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    raise Refused('Another battery-care operation is running. Refresh after it finishes.')
                system.deadline = time.monotonic() + 90
                uid = int(os.environ.get('PKEXEC_UID', '0'))
                result = system.history(uid) if argv[1] == 'history' else operation(system, json.loads(argv[2]), uid, argv[1] == 'restore')
            finally:
                os.close(fd)
        else:
            raise Refused('Usage: senomy-battery-care get | history | apply JSON | restore JSON')
    except Exception as error:
        result = {'ok': False, 'state': 'rejected', 'message': str(error) if isinstance(error, Refused) else 'Battery-care state or operation unavailable. Nothing is assumed successful.'}
    print(json.dumps(result, allow_nan=False))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
