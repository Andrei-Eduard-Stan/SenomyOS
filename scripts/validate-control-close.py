#!/usr/bin/env python3
"""Real Control Centre close-button and placement bindings, private Qt hosting."""
from pathlib import Path
import os,re,shutil,subprocess,sys,tempfile
repo=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/"shell/quickshell"
with tempfile.TemporaryDirectory(prefix="senomy-control-close-test-") as directory:
    work=Path(directory);shell=work/"shell/quickshell";shutil.copytree(source,shell,symlinks=True)
    for name in ["assets","appearance"]:(work/name).symlink_to(source.parents[1]/name,target_is_directory=True)
    root=(source/"shell.qml").read_text();start=root.index("    readonly property var controlRail:");end=root.index("    Connections {target:shellState;",start)
    fixture=(source/"tests/fixtures/control-close.qml").read_text().replace("    // INSERT_PLACEMENT_BINDINGS\n",root[start:end])
    # Native QA uses Qt mouse events. Emit the real button signal directly
    # here so software rasterization cannot consume the entire exit timer.
    fixture=fixture.replace("input.mouseClick(button);", "button.clicked();").replace("preferredWidth:1120;preferredHeight:820", "preferredWidth:720;preferredHeight:500")
    # QQuickWindow can finish its visibility transition before our first
    # timer sample; native PanelWindow exit samples are checked separately.
    fixture=fixture.replace("property bool requireAnimatedSamples:true", "property bool requireAnimatedSamples:false")
    (shell/"control-close-test.qml").write_text(fixture)
    host=shell/"components/DashboardWindow.qml";code=host.read_text().replace("PanelWindow {","Window {",1).replace("    screen: targetScreen\n", "").replace("    implicitWidth: fitted.width","    width: fitted.width").replace("    implicitHeight: fitted.height","    height: fitted.height").replace("    exclusiveZone: 0\n", "").replace("    focusable: true\n", "")
    start=code.index("    anchors {\n        left:");end=code.index("    onRequestedOpenChanged:",start)
    # Retain the exact production margin expressions under the Qt window shim.
    margins=code[code.index("    margins {",start):code.index("    WlrLayershell.namespace:",start)]
    left=re.search(r"        left: (.+)",margins).group(1);bottom=re.search(r"        bottom: (.+)",margins).group(1)
    shim="    property QtObject margins:QtObject { property real left:"+left+";property real bottom:"+bottom+" }\n"
    code=code[:start]+shim+code[end:];host.write_text(code)
    runtime=work/"runtime";runtime.mkdir(mode=0o700)
    env=dict(os.environ,QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software",XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(work/"config"),XDG_STATE_HOME=str(work/"state"))
    for key in ["WAYLAND_DISPLAY","HYPRLAND_INSTANCE_SIGNATURE","SENOMY_CLOSE_BASELINE"]:env.pop(key,None)
    result=subprocess.run(["dbus-run-session","--","qs","-p",str(shell/"control-close-test.qml"),"--no-color"],env=env,capture_output=True,text=True,timeout=10)
    log=result.stdout+result.stderr
    if result.returncode or re.search(r"ERROR|FAIL:|TypeError|ReferenceError|Binding loop|Unable to assign",log) or "PASS:" not in log:raise SystemExit(log)
    print(next(line for line in log.splitlines() if "PASS:" in line))
