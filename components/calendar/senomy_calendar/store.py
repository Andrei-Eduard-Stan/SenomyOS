"""Private, transactional event storage; ICS is the canonical event representation."""
import contextlib
import json
import os
from pathlib import Path
import sqlite3
import uuid

DEFAULTS = dict(weekStart=-1, weekNumbers=False, timeFormat='24', dateFormat='iso', timezone='local', workStart='09:00', workEnd='17:00', defaultCalendar='personal', defaultReminder='10')

class StoreError(ValueError): pass

class Store:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(self.directory, 0o700)
        self.path = self.directory / 'calendar.sqlite3'
        self.db = sqlite3.connect(self.path, check_same_thread=False)
        os.chmod(self.path, 0o600)
        self.db.row_factory = sqlite3.Row
        self.db.execute('PRAGMA foreign_keys=ON')
        version = self.db.execute('PRAGMA user_version').fetchone()[0]
        if version not in (0, 1): raise StoreError('Calendar store version is unsupported; data was not modified.')
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.executescript('''
        CREATE TABLE IF NOT EXISTS sources(id TEXT PRIMARY KEY, name TEXT NOT NULL, color TEXT NOT NULL,
            visible INTEGER NOT NULL DEFAULT 1, provider TEXT NOT NULL DEFAULT 'local', url TEXT NOT NULL DEFAULT '',
            username TEXT NOT NULL DEFAULT '', writable INTEGER NOT NULL DEFAULT 1, sync_state TEXT NOT NULL DEFAULT 'local', last_sync REAL NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS events(source TEXT NOT NULL REFERENCES sources(id), uid TEXT NOT NULL,
            ics TEXT NOT NULL, revision INTEGER NOT NULL, href TEXT NOT NULL DEFAULT '', etag TEXT NOT NULL DEFAULT '',
            dirty INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, conflict TEXT NOT NULL DEFAULT '', PRIMARY KEY(source,uid));
        CREATE TABLE IF NOT EXISTS settings(id INTEGER PRIMARY KEY CHECK(id=1), data TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS alarms(key TEXT PRIMARY KEY, source TEXT NOT NULL, uid TEXT NOT NULL,
            occurrence TEXT NOT NULL, title TEXT NOT NULL, due REAL NOT NULL, status TEXT NOT NULL,
            snooze REAL NOT NULL DEFAULT 0, native_id INTEGER NOT NULL DEFAULT 0, owner TEXT NOT NULL DEFAULT '', action_token TEXT NOT NULL DEFAULT '');
        CREATE TABLE IF NOT EXISTS metadata(id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS receipts(id TEXT PRIMARY KEY, result TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS drafts(id TEXT PRIMARY KEY, data TEXT NOT NULL);
        PRAGMA user_version=1;
        ''')
        self.db.execute("INSERT OR IGNORE INTO sources(id,name,color) VALUES('personal','Personal','#a997ef')")
        self.db.execute('INSERT OR IGNORE INTO settings VALUES(1,?)', (json.dumps(DEFAULTS),))
        self.db.execute('INSERT OR IGNORE INTO metadata VALUES(1,0)')
        self.db.commit()

    @property
    def revision(self): return self.db.execute('SELECT revision FROM metadata').fetchone()[0]
    def bump(self): self.db.execute('UPDATE metadata SET revision=revision+1')
    def preferences(self): return dict(DEFAULTS, **json.loads(self.db.execute('SELECT data FROM settings').fetchone()[0]))
    def sources(self): return [dict(row) for row in self.db.execute('SELECT * FROM sources ORDER BY name')]
    def source(self, identifier):
        row = self.db.execute('SELECT * FROM sources WHERE id=?', (identifier,)).fetchone()
        if not row: raise StoreError('Calendar no longer exists.')
        return dict(row)
    def event(self, source, uid):
        row = self.db.execute('SELECT * FROM events WHERE source=? AND uid=? AND deleted=0', (source, uid)).fetchone()
        if not row: raise StoreError('Event no longer exists.')
        return dict(row)
    def receipt(self, request):
        row = self.db.execute('SELECT result FROM receipts WHERE id=?', (request,)).fetchone()
        return json.loads(row[0]) if row else None
    @contextlib.contextmanager
    def transaction(self):
        with self.db:
            yield
            self.bump()
    def save_receipt(self, request, result):
        self.db.execute('INSERT OR REPLACE INTO receipts VALUES(?,?)', (request, json.dumps(result)))
        self.db.execute('DELETE FROM receipts WHERE rowid NOT IN (SELECT rowid FROM receipts ORDER BY rowid DESC LIMIT 1000)')
    def backup(self):
        target=self.directory / ('backup-'+uuid.uuid4().hex+'.sqlite3')
        other=sqlite3.connect(target);self.db.backup(other);other.close();os.chmod(target,0o600)
        return target
