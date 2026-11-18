#!/usr/bin/env python3
"""Power-policy adapter. Reads never activate services or write preferences.

TLP remains the policy owner. The only writes are a reviewed profile request
to its existing executable, or Properties.Set on an already owned profile API.
No sysfs/configuration writes, service changes, thresholds or session actions.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import time

PROFILES = ('power-saver', 'balanced', 'performance')
ENDPOINTS = (
    ('org.freedesktop.UPower.PowerProfiles', '/org/freedesktop/UPower/PowerProfiles'),
    ('net.hadess.PowerProfiles', '/net/hadess/PowerProfiles'),
)
UNITS = ('tlp.service', 'tlp-pd.service', 'power-profiles-daemon.service',
         'tuned.service', 'tuned-ppd.service', 'auto-cpufreq.service', 'system76-power.service')


class Problem(Exception):
    def __init__(self, state, message):
        super().__init__(message)
        self.state = state


def scalar(path):
    try:
        return path.read_text()[:4096].strip()
    except OSError:
        return None


def number(path, scale=1):
    try:
        value = float(scalar(path)) / scale
        return value if math.isfinite(value) and value >= 0 else None
    except (ValueError, TypeError):
        return None


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def choose(tlp, endpoints, units, pkexec):
    """Pure ownership decision; never infer profiles from CPU governor names."""
    active = [name for name in UNITS[2:] if units.get(name, {}).get('ActiveState') == 'active']
    def family(name):
        return 'tuned' if name in ('tuned', 'tuned-ppd') else 'tlp' if name == 'tlp-pd' else name
    def owner_family(endpoint):
        # tlp-pd is Python. Tie the bus peer PID to its system unit rather than
        # assuming /proc/PID/exe names the script or trusting an argv basename.
        pid = endpoint.get('pid')
        for name in UNITS[1:]:
            unit = units.get(name, {})
            if pid and unit.get('MainPID') == str(pid) and unit.get('ActiveState') == 'active':
                return family(name.removesuffix('.service'))
        return family(endpoint['executable'])
    writers = {family(name.removesuffix('.service')) for name in active}
    writers.update(owner_family(e) for e in endpoints)
    if tlp['active']: writers.add('tlp')
    conflict = len(endpoints) > 1 and len({e['owner'] for e in endpoints}) > 1
    conflict |= bool(tlp['active'] and (active or any(owner_family(e) != 'tlp' for e in endpoints)))
    conflict |= len(writers) > 1
    base = {'kind': 'none', 'identity': '', 'active': '', 'profiles': [], 'holds': [],
            'available': False, 'reason': '', 'conflict': conflict,
            'semantics': 'No user preference is written by SenomyOS.', 'degraded': ''}
    if conflict:
        return dict(base, reason='Conflicting power-policy owners detected. Profile writes are disabled; review the services separately.')
    if endpoints:
        e = endpoints[0]
        profiles = [p.get('Profile') for p in e['properties'].get('Profiles', [])
                    if p.get('Profile') in PROFILES]
        current = e['properties'].get('ActiveProfile', '')
        return dict(base, kind='dbus', identity=e['owner'], endpoint=e,
                    active=current if current in PROFILES else '', profiles=list(dict.fromkeys(profiles)),
                    available=current in profiles,
                    reason='' if current in profiles else 'The provider did not report a valid active profile.',
                    holds=e['properties'].get('ActiveProfileHolds', [])[:32],
                    degraded=str(e['properties'].get('PerformanceDegraded', '') or e['properties'].get('PerformanceInhibited', ''))[:200],
                    semantics='The provider owns persistence and power-source switching. A manual selection can release application holds; SenomyOS saves no profile override.')
    if tlp['active']:
        supported = tlp['modern'] and tlp['profile'] in PROFILES
        return dict(base, kind='tlp', identity=tlp['identity'], active=tlp['profile'],
                    profiles=list(PROFILES) if supported else [], available=supported and pkexec,
                    reason='' if supported and pkexec else 'TLP requires a readable 1.9+ profile state and normal polkit authentication support.',
                    semantics='TLP owns AC/battery switching and reboot defaults. This requests a runtime TLP profile, not a saved startup preference. Holds require tlp-pd; none are created here.')
    return dict(base, reason='No active supported power-profile owner. No daemon was started or installed.')


class System:
    def __init__(self, sysroot=Path('/sys'), runroot=Path('/run')):
        from gi.repository import Gio, GLib
        self.Gio, self.GLib = Gio, GLib
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.sysroot, self.runroot = sysroot, runroot

    def call(self, name, path, interface, method, signature=None, args=(), timeout=3000):
        value = self.GLib.Variant(signature, args) if signature else None
        return self.bus.call_sync(name, path, interface, method, value, None,
                                  self.Gio.DBusCallFlags.NO_AUTO_START, timeout, None).unpack()

    def command(self, argv, timeout=4):
        try:
            return subprocess.run(argv, capture_output=True, text=True, timeout=timeout,
                                  env=dict(os.environ, LC_ALL='C'))
        except subprocess.TimeoutExpired as e:
            raise Problem('unverified', 'The operation timed out. It may still finish; refresh before retrying. No automatic rollback or retry was attempted.') from e
        except OSError as e:
            raise Problem('unavailable', 'A required power-management executable is unavailable.') from e

    @staticmethod
    def bus_problem(error):
        # A missing reply is uncertain, not a demonstrated backend refusal.
        if hasattr(error, 'matches'):
            from gi.repository import Gio
            uncertain = error.matches(Gio.io_error_quark(), Gio.IOErrorEnum.TIMED_OUT)
            uncertain |= any(error.matches(Gio.dbus_error_quark(), code) for code in (Gio.DBusError.NO_REPLY, Gio.DBusError.TIMEOUT, Gio.DBusError.TIMED_OUT))
            if uncertain:
                return Problem('unverified', 'The provider reply timed out or was lost. The request may still finish; refresh before retrying. No automatic rollback was attempted.')
        return Problem('rejected', 'The provider refused the profile or authorization. Refresh to inspect the current state.')

    def units(self):
        result = self.command(['/usr/bin/systemctl', 'show', *UNITS, '--no-pager',
                               '-p', 'Id', '-p', 'ActiveState', '-p', 'InvocationID', '-p', 'MainPID'])
        if result.returncode:
            raise Problem('unavailable', 'Power-policy service state could not be verified.')
        records = {}
        for block in result.stdout.strip().split('\n\n'):
            fields = dict(line.split('=', 1) for line in block.splitlines() if '=' in line)
            if fields.get('Id'):
                records[fields['Id']] = fields
        return records

    def endpoints(self):
        result = []
        for name, path in ENDPOINTS:
            try:
                owner = self.call('org.freedesktop.DBus', '/org/freedesktop/DBus',
                                  'org.freedesktop.DBus', 'GetNameOwner', '(s)', (name,))[0]
            except self.GLib.Error as e:
                if 'NameHasNoOwner' in str(e):
                    continue
                raise Problem('unavailable', 'Power-profile bus ownership could not be verified.') from e
            try:
                props = self.call(owner, path, 'org.freedesktop.DBus.Properties', 'GetAll', '(s)', (name,))[0]
                pid = self.call('org.freedesktop.DBus', '/org/freedesktop/DBus',
                                'org.freedesktop.DBus', 'GetConnectionUnixProcessID', '(s)', (owner,))[0]
                executable = Path(os.readlink('/proc/' + str(pid) + '/exe')).name
            except (self.GLib.Error, OSError) as e:
                raise Problem('unavailable', 'The power-profile owner changed or could not be inspected. Refresh before retrying.') from e
            result.append({'name': name, 'path': path, 'owner': owner, 'pid': pid, 'executable': executable, 'properties': props})
        return result

    def status(self):
        units = self.units()
        tlp = {'active': units.get('tlp.service', {}).get('ActiveState') == 'active',
               'version': '', 'modern': False, 'profile': '', 'mode': '', 'identity': ''}
        settings = scalar(self.runroot/'tlp/run.conf') or ''
        tlp['rules'] = {key: value for key, value in re.findall(r'(?m)^(TLP_ENABLE|TLP_AUTO_SWITCH|TLP_PROFILE_AC|TLP_PROFILE_BAT|TLP_PERSISTENT_DEFAULT)="?([A-Za-z0-9_-]+)"?$', settings)}
        if tlp['rules'].get('TLP_ENABLE') == '0':
            tlp['active'] = False
        if Path('/usr/bin/tlp').exists():
            version = self.command(['/usr/bin/tlp', '--version'])
            match = re.search(r'\b(\d+)\.(\d+)(?:\.\d+)?\b', version.stdout)
            tlp['version'] = match[0] if match else ''
            tlp['modern'] = bool(match and tuple(map(int, match.group(1, 2))) >= (1, 9))
            if tlp['active']:
                mode = self.command(['/usr/bin/tlp-stat', '-m'])
                match = re.fullmatch(r'(performance|balanced|power-saver)/(AC|BAT|SAV)(?: \((manual|default)\))?', mode.stdout.strip()) if mode.returncode == 0 else None
                if match:
                    tlp['profile'], tlp['mode'] = match[1], match[3] or 'origin-not-reported'
            stat = Path('/usr/bin/tlp').stat()
            tlp['identity'] = digest([units.get('tlp.service'), stat.st_ino, stat.st_mtime_ns, tlp['version']])
        endpoints = self.endpoints()
        backend = choose(tlp, endpoints, units, os.access('/usr/bin/pkexec', os.X_OK))
        if backend['kind'] == 'tlp':
            auto = {'0':'automatic switching disabled', '1':'automatic source switching', '2':'smart source switching'}.get(tlp['rules'].get('TLP_AUTO_SWITCH'), 'switching rules unavailable')
            names = {'PRF':'performance', 'BAL':'balanced', 'SAV':'power-saver'}
            ac = names.get(tlp['rules'].get('TLP_PROFILE_AC'), 'unreported')
            bat = names.get(tlp['rules'].get('TLP_PROFILE_BAT'), 'unreported')
            backend['semantics'] += ' Current rules: ' + auto + '; assigned AC=' + ac + ', battery=' + bat + '. This does not establish who last selected the current profile. Selecting a profile clears TLP\'s traditional manual AC/BAT override. The previous profile button does not restore that manual-mode flag.'
        sources = {p.name: scalar(p/'online') for p in (self.sysroot/'class/power_supply').glob('*') if scalar(p/'type') in ('Mains', 'USB', 'USB_C')}
        backend['token'] = digest([backend['identity'], backend['kind'], backend['profiles'], backend['active'], sources, units, [(e['owner'], e['name']) for e in endpoints]])
        # Bound output to selected properties; never expose arbitrary provider data.
        endpoint = backend.pop('endpoint', None)
        if endpoint:
            backend.update(busName=endpoint['name'], objectPath=endpoint['path'])
        return {'ok': True, 'schemaVersion': 1, 'observedAt': int(time.time()),
                'backend': backend, 'tlp': tlp, 'sources': sources}

    def set_profile(self, request):
        if not isinstance(request, dict) or set(request) != {'profile', 'token'} or request['profile'] not in PROFILES or not isinstance(request['token'], str):
            raise Problem('unsupported', 'Select one supported power profile and review it again.')
        before = self.status(); backend = before['backend']
        if not backend['available'] or request['profile'] not in backend['profiles']:
            raise Problem('unavailable', backend['reason'] or 'The requested profile is unavailable.')
        if request['token'] != backend['token']:
            raise Problem('stale', 'The provider, power source or profile changed during review. Nothing was submitted.')
        if request['profile'] == backend['active']:
            return dict(before, state='verified', message='The requested profile is already reported; no operation was needed.')
        error = None
        try:
            if backend['kind'] == 'tlp':
                operation = self.command(['/usr/bin/pkexec', '/usr/bin/tlp', request['profile']], timeout=90)
                if operation.returncode:
                    error = Problem('rejected', 'Authorization was denied/cancelled, or TLP refused the request. No preference was saved.')
            elif backend['kind'] == 'dbus':
                self.call(backend['identity'], backend['objectPath'], 'org.freedesktop.DBus.Properties', 'Set',
                          '(ssv)', (backend['busName'], 'ActiveProfile', self.GLib.Variant('s', request['profile'])), timeout=90000)
            else:
                raise Problem('unavailable', 'No safe power-profile write path.')
        except self.GLib.Error as e:
            error = self.bus_problem(e)
        except Problem as e:
            error = e
        try:
            after = self.status()
        except Exception:
            return {'ok': False, 'state': 'unverified', 'message': 'Request submitted, but readback is unavailable. Do not assume success or retry automatically.'}
        if error:
            if after['backend']['identity'] != backend['identity']:
                return dict(after, ok=False, state='unverified', message='The policy owner changed after a failed or missing reply. The request outcome is uncertain; inspect current state before retrying.')
            changed = after['backend']['active'] != backend['active']
            return dict(after, ok=False, state='partially-applied' if changed else error.state,
                        message=str(error) + (' Reported state changed; no compensating write was attempted.' if changed else ' Previous reported profile is unchanged.'))
        if after['backend']['identity'] != backend['identity'] or after['backend']['conflict']:
            return dict(after, ok=False, state='unverified', message='The power-policy owner changed during the request. Inspect current state; no automatic retry.')
        if after['backend']['active'] != request['profile']:
            return dict(after, ok=False, state='unverified', message='Request accepted, but the provider does not report the requested profile. No preference was saved.')
        return dict(after, state='verified', message='The provider reports the requested profile. This verifies reported policy, not CPU frequency or measured energy savings.')

    def details(self):
        packs = []
        for p in sorted((self.sysroot/'class/power_supply').glob('*')):
            if scalar(p/'type') != 'Battery' or scalar(p/'scope') == 'Device' or scalar(p/'present') == '0':
                continue
            full, design = number(p/'energy_full', 1e6), number(p/'energy_full_design', 1e6)
            full_wh, design_wh = full, design
            if full is None or design is None:
                full, design = number(p/'charge_full'), number(p/'charge_full_design')
            health = full/design*100 if full is not None and full > 0 and design and design > 0 else None
            packs.append({'name': p.name, 'model': scalar(p/'model_name'), 'state': scalar(p/'status'),
                          'healthPercent': health, 'fullEnergyWh': full_wh, 'designEnergyWh': design_wh, 'cycleCount': number(p/'cycle_count'),
                          'startThreshold': number(p/'charge_control_start_threshold'),
                          'stopThreshold': number(p/'charge_control_end_threshold'),
                          'thresholdEditing': False,
                          'thresholdReason': 'Read-only: safe vendor ranges and an authorized persistent TLP configuration transaction must be reviewed before editing. No generic 0–100 range is assumed.'})
        cpus = []
        for p in sorted((self.sysroot/'devices/system/cpu/cpufreq').glob('policy*')):
            cpus.append({key: scalar(p/name) for key, name in (
                ('policy', 'affected_cpus'), ('driver', 'scaling_driver'), ('governor', 'scaling_governor'),
                ('governors', 'scaling_available_governors'), ('epp', 'energy_performance_preference'),
                ('eppChoices', 'energy_performance_available_preferences'), ('minimumKHz', 'scaling_min_freq'), ('maximumKHz', 'scaling_max_freq'))})
        inhibitors, policy, error = [], {}, ''
        try:
            manager = 'org.freedesktop.login1.Manager'
            raw = self.call('org.freedesktop.login1', '/org/freedesktop/login1', manager, 'ListInhibitors')[0]
            inhibitors = [{'who': str(row[1])[:120], 'what': str(row[0])[:120], 'why': str(row[2])[:240], 'mode': str(row[3])[:24], 'pid': row[5]} for row in raw[:64]]
            props = self.call('org.freedesktop.login1', '/org/freedesktop/login1', 'org.freedesktop.DBus.Properties', 'GetAll', '(s)', (manager,))[0]
            policy = {k: props.get(k) for k in ('IdleAction', 'HandleLidSwitch', 'HandleLidSwitchDocked', 'HandleLidSwitchExternalPower', 'LidClosed', 'Docked')}
        except self.GLib.Error:
            error = 'Logind policy/inhibitors unavailable; an empty list is not proof that nothing inhibits sleep.'
        return {'ok': True, 'packs': packs, 'cpus': cpus[:32], 'inhibitors': inhibitors,
                'policy': policy, 'error': error,
                'platformProfile': scalar(self.sysroot/'firmware/acpi/platform_profile'),
                'platformChoices': scalar(self.sysroot/'firmware/acpi/platform_profile_choices'),
                'boostDisabled': scalar(self.sysroot/'devices/system/cpu/intel_pstate/no_turbo'),
                'fanControl': 'Not exposed: no supported writable fan-policy interface integrated.',
                'observedAt': int(time.time())}

    def watch(self):
        """One shell-owned subscription; event coalescing + 60s reconciliation."""
        queued = [False]
        def emit():
            queued[0] = False
            try:
                output(self.status())
            except Exception:
                output({'ok': False, 'message': 'Power-profile observation is unavailable. Battery reporting remains independent.'})
            return False
        def queue(*_):
            if not queued[0]:
                queued[0] = True
                self.GLib.timeout_add(500, emit)
        def owner_changed(_bus, _sender, _path, _iface, _signal, args):
            if args.unpack()[0] in {e[0] for e in ENDPOINTS} | {'org.freedesktop.UPower', 'org.freedesktop.systemd1'}:
                queue()
        def properties_changed(_bus, _sender, _path, _iface, _signal, args):
            interface = args.unpack()[0]
            unit_paths = {'/org/freedesktop/systemd1/unit/' + name.replace('-', '_2d').replace('.', '_2e') for name in UNITS}
            if interface in {e[0] for e in ENDPOINTS} | {'org.freedesktop.UPower'} or interface == 'org.freedesktop.systemd1.Unit' and _path in unit_paths:
                queue()
        self.bus.signal_subscribe('org.freedesktop.DBus', 'org.freedesktop.DBus', 'NameOwnerChanged', '/org/freedesktop/DBus', None, self.Gio.DBusSignalFlags.NONE, owner_changed)
        self.bus.signal_subscribe(None, 'org.freedesktop.DBus.Properties', 'PropertiesChanged', None, None, self.Gio.DBusSignalFlags.NONE, properties_changed)
        self.bus.signal_subscribe('org.freedesktop.login1', 'org.freedesktop.login1.Manager', 'PrepareForSleep', '/org/freedesktop/login1', None, self.Gio.DBusSignalFlags.NONE, queue)
        try:
            self.call('org.freedesktop.systemd1', '/org/freedesktop/systemd1', 'org.freedesktop.systemd1.Manager', 'Subscribe')
        except self.GLib.Error:
            pass  # Bounded reconciliation still detects service changes.
        monitors = []
        for path in (self.runroot, self.runroot/'tlp'):
            if path.is_dir():
                monitor = self.Gio.File.new_for_path(str(path)).monitor_directory(self.Gio.FileMonitorFlags.NONE, None)
                monitor.connect('changed', lambda _m, file, _other, _event: queue() if file.get_basename() in ('tlp', 'last_pwr', 'run.conf') else None)
                monitors.append(monitor)
        def reconcile():
            queue()
            return True
        self.GLib.timeout_add_seconds(60, reconcile)
        emit()
        self.GLib.MainLoop().run()


def output(payload):
    print(json.dumps(payload, separators=(',', ':'), allow_nan=False), flush=True)


def main(argv):
    try:
        if len(argv) < 2 or argv[1] not in ('get', 'watch', 'details', 'set') or len(argv) != (3 if argv[1] == 'set' else 2):
            raise Problem('unsupported', 'Usage: energy-provider.py {get|watch|details|set JSON}')
        system = System()
        if argv[1] == 'watch':
            system.watch()
            return 0
        payload = system.set_profile(json.loads(argv[2])) if argv[1] == 'set' else system.details() if argv[1] == 'details' else system.status()
        output(payload)
        return 0 if payload.get('ok') else 1
    except Problem as e:
        output({'ok': False, 'state': e.state, 'message': str(e)})
    except Exception:
        output({'ok': False, 'state': 'unavailable', 'message': 'Power-management data is unavailable or invalid. Refresh; no preference was saved.'})
    return 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
