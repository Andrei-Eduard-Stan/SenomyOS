#!/usr/bin/env python3
"""Export only the displayed component payload; no diagnostic command collection."""
import json, os, re, shutil, subprocess, sys, time
from pathlib import Path

def directory():
    base = Path(os.environ.get("XDG_STATE_HOME", str(Path.home()/".local/state"))) / "senomyos" / "component-reports"
    if base.is_symlink(): raise ValueError("Report directory must not be a symlink")
    base.mkdir(parents=True, exist_ok=True, mode=0o700)
    if base.stat().st_uid != os.getuid(): raise ValueError("Report directory has a different owner")
    base.chmod(0o700)
    return base

def create(component, suffix):
    path=directory() / (time.strftime("%Y%m%d-%H%M%S")+"-"+str(time.time_ns())+"-"+component+suffix)
    fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    return path,fd

def run(args):
    action,component=args[:2]
    if not re.fullmatch(r"[a-z][a-z0-9-]{0,63}",component): raise ValueError("Unknown component name")
    if action=="snapshot":
        path,fd=create(component,".png");os.close(fd)
        return {"ok":True,"path":str(path),"message":"Snapshot destination ready"}
    if action=="finish":
        path=Path(args[2]);base=directory()
        if path.parent!=base or path.is_symlink() or not path.name.endswith("-"+component+".png"):
            raise ValueError("Invalid snapshot destination")
        with path.open("rb") as f:
            if f.read(8)!=b"\x89PNG\r\n\x1a\n": raise ValueError("Snapshot was not saved as PNG")
        path.chmod(0o600)
        return {"ok":True,"path":str(path),"message":"Saved "+str(path)}
    if action not in ("copy","text"): raise ValueError("Unsupported report action")
    if len(args[2].encode())>65536: raise ValueError("Component report exceeds its size limit")
    payload=json.loads(args[2])
    report="SENOMYOS / "+component.upper()+"\nCaptured: "+time.strftime("%Y-%m-%d %H:%M:%S %Z")+"\n\n"+json.dumps(payload,ensure_ascii=False,indent=2)+"\n"
    if action=="copy":
        command=shutil.which("wl-copy")
        if not command: raise ValueError("Clipboard unavailable: wl-copy is not installed")
        subprocess.run([command,"--type","text/plain"],input=report,text=True,check=True,timeout=4,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        return {"ok":True,"message":"Component report copied"}
    path,fd=create(component,".txt")
    with os.fdopen(fd,"w") as f: f.write(report)
    return {"ok":True,"path":str(path),"message":"Saved "+str(path)}

if __name__=="__main__":
    try: result=run(sys.argv[1:]);code=0
    except (ValueError,IndexError,OSError,subprocess.SubprocessError,json.JSONDecodeError) as error:
        result={"ok":False,"message":str(error)};code=1
    print(json.dumps(result));sys.exit(code)
