import importlib.util
import io
import json
from pathlib import Path
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("native_input_tools", Path(__file__).parents[1] / "scripts/native-input-tools.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class NativeInputToolsTests(unittest.TestCase):
    def test_absent_tools_do_not_claim_support_or_launch(self):
        with patch.object(module.shutil, "which", return_value=None), patch.object(module.subprocess, "Popen") as launch:
            self.assertEqual(module.detect(), {"ok": True, "editorAvailable": False, "engineInstalled": False, "oskIntegrated": False, "oskMessage": "On-screen keyboard integration is not configured or validated."})
            self.assertEqual(module.launch_editor()["state"], "unavailable")
            launch.assert_not_called()

    def test_editor_and_engine_are_independent(self):
        with patch.object(module.shutil, "which", side_effect=lambda name: "/fixture/editor" if name == "fcitx5-configtool" else None):
            result = module.detect()
            self.assertTrue(result["editorAvailable"])
            self.assertFalse(result["engineInstalled"])
            self.assertFalse(result["oskIntegrated"])

    def test_fixed_argv_without_shell_or_user_arguments(self):
        with patch.object(module.shutil, "which", return_value="/fixture/editor"), patch.object(module.subprocess, "Popen") as launch:
            result = module.launch_editor()
            self.assertEqual(result["state"], "started")
            self.assertIn("unverified", result["message"])
            launch.assert_called_once_with(["/fixture/editor"], stdin=module.subprocess.DEVNULL, stdout=module.subprocess.DEVNULL, stderr=module.subprocess.DEVNULL, close_fds=True, start_new_session=True)

    def test_exec_failure_is_not_started(self):
        with patch.object(module.shutil, "which", return_value="/fixture/editor"), patch.object(module.subprocess, "Popen", side_effect=OSError("fixture failure")):
            self.assertEqual(module.launch_editor()["state"], "failed")

    def test_removal_is_rechecked_on_launch(self):
        with patch.object(module.shutil, "which", side_effect=["/fixture/editor", "/fixture/engine", None]), patch.object(module.subprocess, "Popen") as launch:
            self.assertTrue(module.detect()["editorAvailable"])
            self.assertEqual(module.launch_editor()["state"], "unavailable")
            launch.assert_not_called()

    def test_unknown_action_or_arguments_never_launch(self):
        for args in [[], ["open-ime", "--anything"], ["run", "echo"], ["detect", "extra"]]:
            with patch.object(module.subprocess, "Popen") as launch, redirect_stdout(io.StringIO()) as output:
                self.assertEqual(module.main(args), 1)
                self.assertFalse(json.loads(output.getvalue())["ok"])
                launch.assert_not_called()

if __name__ == "__main__":
    unittest.main()
