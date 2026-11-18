#!/usr/bin/env python3
"""Native lens logic and launcher routing; fake activations, no live IPC."""
from pathlib import Path
import os, subprocess, tempfile, json, re, sys
root=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="senomy-native-lens-") as directory:
    work=Path(directory);runtime=work/"runtime";runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software",XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/"config"),XDG_STATE_HOME=str(work/"state"))
    for name in ["WAYLAND_DISPLAY","HYPRLAND_INSTANCE_SIGNATURE"]:env.pop(name,None)
    providers=work/"source/components/launcher/rofi/scripts";providers.mkdir(parents=True)
    fake_provider="""#!/usr/bin/env python3
import os,json,time
from pathlib import Path
scope=Path(__file__).name
if scope.endswith('actions') and os.environ.get('SENOMY_LENS_TEST_FAILURE')=='1':raise SystemExit(7)
if os.environ.get('ROFI_RETV','0')=='0':
 print('Fixture row\\0info\\x1f/tmp/a file with spaces'.encode().decode('unicode_escape'))
else:
 time.sleep(0.12)
 Path(os.environ['SENOMY_PROVIDER_RECORD']+'.'+scope).write_text(json.dumps({'info':os.environ['ROFI_INFO'],'retv':os.environ['ROFI_RETV']}))
 if scope.endswith('actions'):print('\\0message\\x1fFixture selection failed'.encode().decode('unicode_escape'))
"""
    for name in ['senomy-rofi-files','senomy-rofi-actions']:
        helper=providers/name;helper.write_text(fake_provider);helper.chmod(0o755)
    env.update(SENOMY_SOURCE_ROOT=str(work/"source"),SENOMY_PROVIDER_RECORD=str(work/"selection"))
    p=subprocess.run(["dbus-run-session","--","qs","--path",str(root/"shell/quickshell/command-lens-test.qml"),"--no-color"],env=env,capture_output=True,text=True,timeout=10)
    log=p.stdout+p.stderr
    assert p.returncode==0 and "latest-input/opening guards" in log and not re.search(r"ERROR|FAIL:|TypeError|ReferenceError|Binding loop",log),log
    print(next(line for line in log.splitlines() if "PASS:" in line))
    selected=json.loads((work/"selection.senomy-rofi-files").read_text())
    assert selected=={"info":"/tmp/a file with spaces","retv":"10"},selected
    print("PASS: provider selection preserved exact identity and reveal operation")
    failure=subprocess.run(["dbus-run-session","--","qs","--path",str(root/"shell/quickshell/command-lens-test.qml"),"--no-color"],env=dict(env,SENOMY_LENS_TEST_FAILURE="1"),capture_output=True,text=True,timeout=10)
    failurelog=failure.stdout+failure.stderr
    assert failure.returncode==0 and "working providers still search" in failurelog and not re.search(r"ERROR|FAIL:|TypeError|ReferenceError|Binding loop",failurelog),failurelog
    print("PASS: partial provider failure does not block unified search")
    commands=work/"bin";commands.mkdir();record=work/"args.json"
    fake=commands/"qs"
    fake.write_text("#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\nPath(os.environ['SENOMY_LENS_RECORD']).write_text(json.dumps(sys.argv[1:]))\nprint(os.environ['SENOMY_LENS_REPLY'])\n")
    fake.chmod(0o755)
    fake_manager=commands/"systemctl"
    fake_manager.write_text("#!/usr/bin/env bash\nprintf '4242\\n'\n");fake_manager.chmod(0o755)
    env.update(SENOMY_QS_BIN=str(fake),SENOMY_SYSTEMCTL_BIN=str(fake_manager),PATH=str(commands)+os.pathsep+os.environ["PATH"],SENOMY_LENS_RECORD=str(record),SENOMY_LENS_NATIVE="1",SENOMY_SOURCE_ROOT=str(root))
    for reply in ["accepted","blocked"]:
        env["SENOMY_LENS_REPLY"]=reply
        p=subprocess.run([str(root/"components/launcher/rofi/scripts/senomy-command-lens"),"--mode","files"],env=env,capture_output=True,text=True,timeout=5)
        assert p.returncode==(3 if reply=="blocked" else 0),(p.stdout,p.stderr)
        assert json.loads(record.read_text())==["ipc","--pid","4242","call","shell","commandLens","files"]
    env["SENOMY_LENS_REPLY"]="accepted"
    subprocess.run([str(root/"components/launcher/rofi/scripts/senomy-command-lens")],env=env,check=True,timeout=5)
    assert json.loads(record.read_text())[-1]=="apps"
    print("PASS: native launcher routing and blocked-modal refusal; fake IPC only")
