#!/usr/bin/env python3
"""Toggle one native window, never the global Rail or display configuration."""
from __future__ import annotations
import argparse,contextlib,fcntl,hashlib,json,os,re,stat,subprocess,sys,tempfile,time
from pathlib import Path
LIMIT=262144

class FullscreenError(Exception):pass

def states(window):
    internal=window.get('fullscreen');client=window.get('fullscreenClient',window.get('fullscreen_client'))
    if any(type(x) is not int or not 0<=x<=3 for x in [internal,client]):
        raise FullscreenError('Compositor returned an unsupported fullscreen state.')
    return [internal,client]

def identity(window):
    pid=window.get('pid')
    if type(pid) is not int or pid<=0:raise FullscreenError('Window process identity is unavailable.')
    try:start=Path('/proc',str(pid),'stat').read_text().rsplit(') ',1)[1].split()[19]
    except (OSError,IndexError):start=''
    fields=[pid,start,window.get('initialClass',''),window.get('initialTitle','')]
    return hashlib.sha256(json.dumps(fields,ensure_ascii=True).encode()).hexdigest()

def transition(current,mode,saved=None):
    full=bool(current[0]&2)
    base=list(saved) if full and saved is not None else [current[0]&1,current[1]&1] if full else list(current)
    same=full and bool(current[1]&2)==(mode=='fullscreen')
    return (base if same else [2,2 if mode=='fullscreen' else 0]),base,same

class Store:
    def __init__(self,runtime,session):
        if not runtime or not session:raise FullscreenError('A Hyprland session and XDG_RUNTIME_DIR are required.')
        runtime=Path(runtime)
        if not runtime.is_dir() or runtime.is_symlink() or runtime.stat().st_uid!=os.getuid():raise FullscreenError('Session runtime directory is unavailable or unsafe.')
        self.root=runtime/'senomyos'/('fullscreen-'+hashlib.sha256(session.encode()).hexdigest()[:20])
        self.path=self.root/'state.json'
    @contextlib.contextmanager
    def locked(self):
        if self.root.is_symlink() or self.root.parent.is_symlink():raise FullscreenError('Fullscreen state directory is unsafe.')
        self.root.parent.mkdir(mode=0o700,exist_ok=True)
        self.root.mkdir(mode=0o700,exist_ok=True)
        if any(not p.is_dir() or p.stat().st_uid!=os.getuid() for p in [self.root,self.root.parent]):raise FullscreenError('Fullscreen state directory is unsafe.')
        fd=os.open(self.root/'lock',os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
        with os.fdopen(fd,'w') as lock:
            deadline=time.monotonic()+3
            while True:
                try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);break
                except BlockingIOError:
                    if time.monotonic()>deadline:raise FullscreenError('Another fullscreen request is still running; retry.')
                    time.sleep(.025)
            yield
    def read(self):
        if not self.path.exists() and not self.path.is_symlink():return {}
        fd=os.open(self.path,os.O_RDONLY|os.O_NOFOLLOW)
        with os.fdopen(fd,'rb') as f:
            info=os.fstat(f.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_uid!=os.getuid() or info.st_size>LIMIT:raise FullscreenError('Fullscreen restore state is unsafe.')
            value=json.loads(f.read(LIMIT+1))
        if not isinstance(value,dict) or len(value)>256:raise FullscreenError('Invalid fullscreen restore state.')
        for key,row in value.items():
            if not re.fullmatch(r'0x[0-9a-fA-F]+',key) or not isinstance(row,dict) or not re.fullmatch('[a-f0-9]{64}',str(row.get('identity',''))) or not isinstance(row.get('base'),list) or len(row['base'])!=2 or any(type(n) is not int or not 0<=n<=3 for n in row['base']):raise FullscreenError('Invalid fullscreen restore state.')
        return value
    def write(self,value):
        blob=(json.dumps(value,separators=(',',':'))+'\n').encode()
        if len(blob)>LIMIT or len(value)>256:raise FullscreenError('Fullscreen restore state exceeds its limit.')
        fd,name=tempfile.mkstemp(prefix='.fullscreen-',dir=self.root)
        try:
            with os.fdopen(fd,'wb') as f:f.write(blob);f.flush();os.fsync(f.fileno())
            os.replace(name,self.path)
        finally:
            if os.path.exists(name):os.unlink(name)

class Fullscreen:
    def __init__(self,hyprctl=None,runtime=None,session=None):
        self.hyprctl=hyprctl or os.environ.get('SENOMY_HYPRCTL_BIN','/usr/bin/hyprctl')
        self.store=Store(runtime if runtime is not None else os.environ.get('XDG_RUNTIME_DIR'),session if session is not None else os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'))
        self.verify_seconds=2.0
    def command(self,*args):
        try:result=subprocess.run([self.hyprctl,*args],capture_output=True,text=True,timeout=4)
        except (OSError,subprocess.SubprocessError) as e:raise FullscreenError('Compositor command could not complete.') from e
        if result.returncode:raise FullscreenError('Compositor rejected fullscreen request: '+(result.stderr or result.stdout).strip()[:240])
        return result.stdout.strip()
    def query(self,name):
        text=self.command('-j',name)
        if len(text)>2097152:raise FullscreenError('Compositor response exceeds its read limit.')
        return json.loads(text)
    def clients(self):
        rows=self.query('clients')
        if not isinstance(rows,list) or len(rows)>5000:raise FullscreenError('Invalid compositor window inventory.')
        return rows
    @staticmethod
    def target(clients,address,expected_identity=None):
        window=next((w for w in clients if w.get('address')==address),None)
        if not window or window.get('mapped') is False or window.get('hidden') is True or expected_identity is not None and identity(window)!=expected_identity:raise FullscreenError('The original window closed, changed identity or is unavailable.')
        return window
    def set_state(self,address,target):
        # Only validated hexadecimal addresses and bounded integers reach Lua.
        code='local r=hl.dispatch(hl.dsp.window.fullscreen_state({window="address:'+address+'",internal='+str(target[0])+',client='+str(target[1])+',action="set"}));assert(r and r.ok,r and r.error or "No dispatcher result")'
        if self.command('eval',code)!='ok':raise FullscreenError('Compositor did not acknowledge fullscreen state.')
    def toggle(self,mode,address=None):
        if mode not in ['fullscreen','immersive']:raise FullscreenError('Unknown fullscreen mode.')
        # Capture the shortcut's original target before waiting on another request.
        focused=self.query('activewindow') if address is None else None
        address=focused.get('address') if isinstance(focused,dict) else address
        if not isinstance(address,str) or not re.fullmatch(r'0x[0-9a-fA-F]+',address) or int(address,16)==0:raise FullscreenError('No focused application window.')
        initial_identity=identity(focused) if focused is not None else None
        status=self.query('status')
        if not isinstance(status,dict) or status.get('configProvider')!='lua':raise FullscreenError('Fullscreen requires the supported Hyprland Lua configuration.')
        with self.store.locked():
            clients=self.clients();window=self.target(clients,address,initial_identity);token=identity(window);current=states(window)
            cache=self.store.read();active={w['address']:identity(w) for w in clients if w.get('address') and type(w.get('pid')) is int and w['pid']>0}
            cache={key:row for key,row in cache.items() if active.get(key)==row['identity']}
            saved=cache.get(address);desired,base,leaving=transition(current,mode,saved['base'] if saved else None)
            # Persist restore intent before dispatch: a timeout must not lose it.
            cache[address]={'identity':token,'base':base};self.store.write(cache)
            self.set_state(address,desired)
            deadline=time.monotonic()+self.verify_seconds
            while True:
                observed=self.target(self.clients(),address,token)
                if states(observed)==desired:break
                if time.monotonic()>=deadline:raise FullscreenError('Fullscreen request was acknowledged but its window state could not be verified. Retry to restore it.')
                time.sleep(.04)
            if leaving:cache.pop(address,None)
            self.store.write(cache)
            return {'address':address,'mode':mode,'state':desired,'restored':leaving}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',nargs='?',default='fullscreen',choices=['fullscreen','immersive'])
    parser.add_argument('--window',metavar='ADDRESS',help='target a specific native window rather than current focus')
    args=parser.parse_args()
    try:Fullscreen().toggle(args.mode,args.window);return 0
    except (FullscreenError,OSError,ValueError,TypeError) as exc:
        print('SenomyOS fullscreen: '+str(exc),file=sys.stderr);return 1
if __name__=='__main__':raise SystemExit(main())
