#!/usr/bin/env python3
import importlib.util,json,os,stat,tempfile
from pathlib import Path
helper=Path(__file__).resolve().parents[1]/"scripts/component-report.py"
spec=importlib.util.spec_from_file_location("reports",helper);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
with tempfile.TemporaryDirectory() as directory:
    os.environ["XDG_STATE_HOME"]=directory
    result=m.run(["text","cpu-utilisation",json.dumps({"percent":17,"source":"fixture"})])
    path=Path(result["path"]);assert path.stat().st_mode & 0o777==0o600
    assert "17" in path.read_text() and path.parent.stat().st_mode & 0o777==0o700
    snap=m.run(["snapshot","cpu-utilisation"]);image=Path(snap["path"]);image.write_bytes(b"\x89PNG\r\n\x1a\n")
    assert m.run(["finish","cpu-utilisation",str(image)])["ok"]
    for args in [["text","../escape","{}"],["unknown","cpu","{}"],["text","cpu","x"],["text","cpu",json.dumps({"x":"a"*65536})],["finish","cpu-utilisation",str(Path(directory)/"outside.png")]]:
        try:m.run(args)
        except (ValueError,json.JSONDecodeError):pass
        else:raise AssertionError("invalid input accepted")
    image.unlink();image.symlink_to(path)
    try:m.run(["finish","cpu-utilisation",str(image)])
    except ValueError:pass
    else:raise AssertionError("symlink accepted")
print("PASS: component text/PNG destinations, private modes, size/path/action and symlink boundaries")
