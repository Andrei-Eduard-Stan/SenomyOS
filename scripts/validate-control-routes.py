#!/usr/bin/env python3
"""Actual route-content keyboard fixture with fake providers and window host.

Does not connect a live panel, restart services, apply preferences or invoke
devices. Compositor focus/grab behavior is deliberately outside this test.
"""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parent.parent
HOST = '''import QtQuick
FocusScope {
 id: root
 property var targetScreen
 property bool requestedOpen: false
 property bool replacementOpening: false
 property string title: ""
 property string eyebrow: ""
 property string activeSection: ""
 property int preferredWidth: 960
 property int preferredHeight: 720
 property string motif: ""
 property string frameKey: ""
 property var sections: []
 property alias navigation: nav
 property alias contentArea: body
 default property alias bodyData: body.data
 signal closeRequested()
 signal sectionRequested(string section)
 DashboardNavigation {
  id: nav; x: 0; y: 0; width: 200; height: parent.height
  sections: root.sections; activeSection: root.activeSection; restoreFocus: root.requestedOpen
  onSectionRequested: section => root.sectionRequested(section)
 }
 Item { id: body; x: 220; width: parent.width-220; height: parent.height }
}
'''


def main():
    shell = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else REPO / "shell/quickshell"
    with tempfile.TemporaryDirectory(prefix="senomy-control-routes-") as directory:
        root = Path(directory)
        copied = root / "shell/quickshell"
        shutil.copytree(shell, copied, symlinks=True)
        for name in ("appearance", "assets"):
            (root / name).symlink_to(REPO / name, target_is_directory=True)
        # Only the compositor/window host is substituted. Actual route content,
        # shared controls, navigation and scrolling come from the current source.
        (copied / "components/DashboardWindow.qml").write_text(HOST)
        shutil.copy2(REPO / "shell/quickshell/tests/fixtures/control-routes.qml",
                     copied / "control-routes-test.qml")
        runtime = root / "runtime"
        runtime.mkdir(mode=0o700)
        env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime),
                   QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
        env.pop("WAYLAND_DISPLAY", None)
        result = subprocess.run(
            ["qs", "--path", str(copied / "control-routes-test.qml"), "--no-color"],
            env=env, capture_output=True, text=True, timeout=45,
        )
        output = result.stdout + result.stderr
        if result.returncode or re.search(r"FAIL:|ERROR|Binding loop|ReferenceError|TypeError", output):
            print(output, file=sys.stderr)
            return 1
        if "PASS: actual Control Centre routes" not in output:
            print("FAIL: no completion marker", file=sys.stderr)
            return 1
        for line in output.splitlines():
            if "PASS:" in line:
                print(line)
        return 0


if __name__ == "__main__":
    sys.exit(main())
