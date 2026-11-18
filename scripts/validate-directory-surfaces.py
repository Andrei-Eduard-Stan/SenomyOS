#!/usr/bin/env python3
"""Native layout, input and exports; substitute only the compositor window host."""
import os,re,shutil,subprocess,sys,tempfile
from qa_directory_host import directory_host, insights_workspace_host, performance_workspace_host
from qa_performance_fixture import performance_environment
from pathlib import Path
repo=Path(__file__).resolve().parents[1]
shell=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else repo/"shell/quickshell"
source=shell.parents[1]
out=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else None
with tempfile.TemporaryDirectory(prefix="senomy-directory-qa-") as directory:
    root=Path(directory);copy=root/"shell/quickshell";shutil.copytree(shell,copy)
    for name in ["appearance","assets"]:(root/name).symlink_to(source/name,target_is_directory=True)
    runtime=root/"runtime";runtime.mkdir(mode=0o700)
    captures=out or root/"captures";captures.mkdir(parents=True,exist_ok=True)
    env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),XDG_STATE_HOME=str(root/"state"),QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software",SENOMY_QA_OUT=str(captures))
    env.pop("WAYLAND_DISPLAY",None)
    def run(command,name,marker,limit=40):
        phase_env=performance_environment(shell,root,env) if name=="performance" else env
        result=subprocess.run(command,env=phase_env,capture_output=True,text=True,timeout=limit)
        output=result.stdout+result.stderr
        if out:(out/(name+".log")).write_text(output)
        if result.returncode or re.search("FAIL:|ERROR|Binding loop|ReferenceError|TypeError",output) or marker not in output:
            print(output);raise SystemExit(1)
        print(next(line for line in output.splitlines() if marker in line))
    run(["/usr/lib/qt6/bin/qmltestrunner","-input",str(shell/"tests/tst_DirectoryData.qml")],"data","Totals:")
    run(["python3",str(shell/"tests/test_component_report.py")],"exports-backend","PASS:")
    actual=(copy/"components/DirectorySurfaceWindow.qml").read_text()
    inner=actual[actual.index("    FocusScope {\n        id: surface"):]
    # Every layout, control and route remains the real source. Only Wayland
    # placement/focus-grab is replaced with a normal Qt FocusScope.
    (copy/"components/DirectorySurfaceWindow.qml").write_text(directory_host(shell))
    (copy/"components/PerformanceWorkspaceWindow.qml").write_text(performance_workspace_host(shell))
    (copy/"components/InsightsWorkspaceWindow.qml").write_text(insights_workspace_host(shell))
    for name in ["directory-performance","directory-insights","component-export"]:
        fixture="insights-workspace-quality" if name=="directory-insights" else "performance-workspace-quality" if name=="directory-performance" else name
        shutil.copy2(shell/("tests/fixtures/"+fixture+".qml"),copy/(name+"-test.qml"))
    run(["qs","--path",str(copy/"directory-performance-test.qml"),"--no-color"],"performance","PASS:")
    run(["qs","--path",str(copy/"directory-insights-test.qml"),"--no-color"],"insights","PASS:")
    commands=root/"bin";commands.mkdir()
    (commands/"wl-copy").write_text("#!/usr/bin/env bash\ncat > \"$SENOMY_CLIPBOARD_FIXTURE\"\n")
    (commands/"wl-copy").chmod(0o755)
    env["PATH"]=str(commands)+os.pathsep+os.environ["PATH"]
    env["SENOMY_CLIPBOARD_FIXTURE"]=str(root/"clipboard.txt")
    run(["qs","--path",str(copy/"component-export-test.qml"),"--no-color"],"exports-ui","PASS:",15)
    assert "17%" in (root/"clipboard.txt").read_text()
    png=list((root/"state/senomyos/component-reports").glob("*.png"));assert len(png)==1 and png[0].stat().st_mode & 0o777==0o600
    if out:shutil.copy2(png[0],out/"exported-component.png")
print("PASS: isolated directory surfaces and exports; compositor/physical-input acceptance remains separate")
