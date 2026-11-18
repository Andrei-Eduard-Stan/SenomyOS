#!/usr/bin/env python3
"""Only the private WP01 bus fixture activates this harmless GUI application."""
from pathlib import Path
import json,os,signal,subprocess
from gi.repository import Gio
base=Path(os.environ['WP01_WORK'])
class Application(Gio.Application):
    def __init__(self):
        super().__init__(application_id=os.environ['WP01_DBUS_ID'],flags=Gio.ApplicationFlags.HANDLES_OPEN)
        self.events=[];self.context={};self.child=None
    def do_startup(self):
        Gio.Application.do_startup(self);self.hold()
        self.child=subprocess.Popen(['/usr/bin/qs','--path',str(base/'gui.qml'),'--no-color'],env=dict(os.environ,WP01_GUI_RECORD=str(base/'dbus-gui.json')),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    def do_before_emit(self,platform_data):
        self.context=platform_data.unpack()
    def record(self,operation,uris=()):
        self.events.append({'operation':operation,'uris':list(uris),'context':str(self.context)})
        record={'pid':os.getpid(),'uid':os.getuid(),'euid':os.geteuid(),'cgroup':Path('/proc/self/cgroup').read_text(),'events':self.events}
        (base/'dbus-app.json').write_text(json.dumps(record))
    def do_activate(self):self.record('activate')
    def do_open(self,files,n_files,hint):self.record('open',[f.get_uri() for f in files])
    def do_shutdown(self):
        if self.child and self.child.poll() is None:self.child.terminate();self.child.wait(timeout=4)
        Gio.Application.do_shutdown(self)
app=Application()
signal.signal(signal.SIGTERM,lambda *_:app.quit())
raise SystemExit(app.run(None))
