#!/usr/bin/env python3
"""Unprivileged care transport. Only the protected installed helper is elevated."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
SOURCE = Path(__file__).resolve().parents[3]/'components/power/battery_care.py'
INSTALLED = Path('/usr/local/libexec/senomy-battery-care')
spec = importlib.util.spec_from_file_location('battery_care', SOURCE)
core = importlib.util.module_from_spec(spec); spec.loader.exec_module(core)


def ready():
    try:
        core.trusted(INSTALLED)
        return INSTALLED.is_file() and os.access(INSTALLED, os.X_OK) and INSTALLED.read_bytes() == SOURCE.read_bytes() and os.access('/usr/bin/pkexec', os.X_OK)
    except (OSError, core.Refused):
        return False


def statefile():
    return Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state')))/'senomyos/battery-care-last.json'


def last():
    try:
        p = statefile()
        if p.stat().st_size > 16384:
            return None
        v = json.loads(p.read_text())
        return v if isinstance(v, dict) else None
    except (OSError, ValueError):
        return None


def authenticated(argv, capture_output=True, text=True, timeout=180):
    # Never signal an authenticated root child on a UI-side timeout. Its own
    # command budget and durable receipt are responsible for bounded recovery.
    # An anonymous output file stays valid for that child if our wait expires.
    with tempfile.TemporaryFile(mode='w+') as output:
        child = subprocess.Popen(argv, stdout=output, stderr=subprocess.DEVNULL, text=True)
        code = child.wait(timeout=timeout)
        output.seek(0)
        return subprocess.CompletedProcess(argv, code, output.read(1048576), '')


def invoke(action, request, runner=authenticated):
    if action != 'history':
        core.request_valid(request, action == 'restore')
    if not ready():
        return {'ok': False, 'state': 'unavailable', 'message': 'The reviewed root-owned battery-care helper is not installed. No privileged request was submitted.'}
    try:
        # argv only; no shell, interpreter or source path at privilege boundary.
        argv = ['/usr/bin/pkexec', str(INSTALLED), action]
        if action != 'history': argv.append(json.dumps(request))
        p = runner(argv, capture_output=True, text=True, timeout=180)
    except subprocess.TimeoutExpired:
        return {'ok': False, 'state': 'unverified', 'message': 'Authentication/operation timed out; it may still finish. Refresh before any further request. No automatic retry or rollback.'}
    except OSError:
        return {'ok': False, 'state': 'unverified', 'message': 'Authentication transport failed; the request outcome could not be verified. Refresh before any further operation.'}
    try:
        result = json.loads(p.stdout)
        if not isinstance(result, dict) or type(result.get('ok')) is not bool:
            raise ValueError()
        if p.returncode and result.get('ok'):
            raise ValueError()
    except (ValueError, TypeError):
        return {'ok': False, 'state': 'rejected' if p.returncode in (126, 127) else 'unverified', 'message': 'Local authentication was denied/cancelled or the helper returned no verifiable receipt. Refresh; no success is assumed.'}
    if result.get('receipt') or action == 'history':
        record = {k: result.get(k) for k in ('receipt', 'previous', 'persistent', 'restorableToken')}
        if action == 'history':
            record = next((v for v in result.get('history', []) if v.get('restorableToken') == result.get('snapshot', {}).get('token')), None)
        if action == 'restore' and result.get('ok'):
            record = None
        try:
            p = statefile(); p.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            fd, name = tempfile.mkstemp(prefix='.battery-care-', dir=p.parent)
            temporary = Path(name)
            with os.fdopen(fd,'w') as f:
                os.fchmod(f.fileno(), 0o600); json.dump(record, f); f.flush(); os.fsync(f.fileno())
            temporary.replace(p)
        except OSError:
            result['message'] += ' Local recovery shortcut could not be saved; retain receipt ' + result.get('receipt', '(use authenticated recovery records)') + ' for attended recovery.'
    return result


def main(argv):
    try:
        if len(argv) == 2 and argv[1] == 'get':
            result = core.Machine().snapshot()
        elif len(argv) == 2 and argv[1] == 'history':
            result = invoke('history', None)
        elif len(argv) == 3 and argv[1] in ('apply', 'restore'):
            result = invoke(argv[1], json.loads(argv[2]))
        else:
            raise core.Refused('Unsupported battery-care operation.')
        result['installed'] = ready(); result['lastReceipt'] = last()
    except Exception as e:
        result = {'ok': False, 'state': 'unavailable', 'message': str(e) if isinstance(e, core.Refused) else 'Battery-care status could not be verified.'}
    print(json.dumps(result, allow_nan=False)); return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
