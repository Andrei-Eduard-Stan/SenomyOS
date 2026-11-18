#!/usr/bin/env python3
"""Observe notification-name ownership; never activate or stop a provider."""
import json
import sys

NAME = 'org.freedesktop.Notifications'


def emit(available, pid=0, expected=0):
    state = ('native' if pid == expected else 'external') if pid else 'unowned'
    if not available:
        state = 'unavailable'
    messages = {
        'native': 'SenomyOS owns desktop notifications.',
        'external': 'Another application owns desktop notifications. Retained SenomyOS history remains available.',
        'unowned': 'No desktop notification provider currently owns the session bus name.',
        'unavailable': 'Desktop notification ownership could not be verified.'}
    print(json.dumps({'available': available, 'owned': available and pid > 0 and pid == expected,
                      'owner_pid': pid, 'state': state, 'message': messages[state]}), flush=True)


def main():
    if len(sys.argv) != 2 or not sys.argv[1].isdigit() or int(sys.argv[1]) <= 0:
        return 64
    expected = int(sys.argv[1])
    try:
        from gi.repository import Gio, GLib
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    except Exception:
        emit(False)
        return 1

    def query(*_):
        try:
            owner = bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                                  'org.freedesktop.DBus', 'GetNameOwner',
                                  GLib.Variant('(s)', (NAME,)), GLib.VariantType('(s)'),
                                  Gio.DBusCallFlags.NO_AUTO_START, 2000, None).unpack()[0]
            pid = bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                                'org.freedesktop.DBus', 'GetConnectionUnixProcessID',
                                GLib.Variant('(s)', (owner,)), GLib.VariantType('(u)'),
                                Gio.DBusCallFlags.NO_AUTO_START, 2000, None).unpack()[0]
            emit(True, pid, expected)
        except GLib.Error as error:
            # Name disappearance during a query is normal, not a provider error.
            absent = Gio.DBusError.is_remote_error(error) and Gio.DBusError.get_remote_error(error) == 'org.freedesktop.DBus.Error.NameHasNoOwner'
            emit(absent, expected=expected)

    bus.signal_subscribe('org.freedesktop.DBus', 'org.freedesktop.DBus',
                         'NameOwnerChanged', '/org/freedesktop/DBus', NAME,
                         Gio.DBusSignalFlags.NONE, query)
    query()
    GLib.MainLoop().run()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
