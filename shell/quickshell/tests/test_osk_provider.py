import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch
spec=importlib.util.spec_from_file_location("osk_provider",Path(__file__).parents[1]/"scripts/osk-provider.py")
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class OskProviderTests(unittest.TestCase):
    def test_unsupported_provider_never_probes_or_executes(self):
        with patch.object(module.capabilities,"detect") as detect,patch.object(module.os,"execv") as execute:
            self.assertFalse(module.launch("arbitrary-command")["ok"]);detect.assert_not_called();execute.assert_not_called()
    def test_missing_capability_or_removed_executable_never_executes(self):
        for candidate,binary in [(False,"/fixture/wvkbd"),(True,None)]:
            with patch.object(module.capabilities,"detect",return_value={"manualCandidate":candidate}),patch.object(module.shutil,"which",return_value=binary),patch.object(module.os,"execv") as execute:
                self.assertFalse(module.launch("wvkbd-mobintl")["ok"]);execute.assert_not_called()
    def test_fixed_exec_without_shell_flags_or_printed_keys(self):
        with patch.object(module.capabilities,"detect",return_value={"manualCandidate":True}),patch.object(module.shutil,"which",return_value="/fixture/wvkbd"),patch.object(module.os,"execv") as execute,patch.object(module,"arm_parent_death_signal"),patch.object(module.os,"stat",return_value=type("Mode",(),{"st_mode":0o755})()),patch.object(module.os,"getxattr",side_effect=OSError(module.errno.ENODATA,"fixture no attributes")):
            module.launch("wvkbd-mobintl");execute.assert_called_once_with("/fixture/wvkbd",["/fixture/wvkbd"])
    def test_resize_build_uses_fixed_flag_without_executing_feature_probe(self):
        from unittest.mock import mock_open
        with patch.object(module.capabilities,"detect",return_value={"manualCandidate":True}),patch.object(module.shutil,"which",return_value="/fixture/wvkbd"),patch.object(module.os,"execv") as execute,patch.object(module,"arm_parent_death_signal"),patch.object(module.os,"stat",return_value=type("Mode",(),{"st_mode":0o755})()),patch.object(module.os,"getxattr",side_effect=OSError(module.errno.ENODATA,"fixture")),patch("builtins.open",mock_open(read_data=b"--senomy-resize geometry-only telemetry")) as opened:
            module.launch("wvkbd-mobintl")
            execute.assert_called_once_with("/fixture/wvkbd",["/fixture/wvkbd","--senomy-resize","--no-popup"])
            opened.return_value.read.assert_called_once_with(4*1024*1024)
    def test_exec_failure_is_truthful(self):
        with patch.object(module.capabilities,"detect",return_value={"manualCandidate":True}),patch.object(module.shutil,"which",return_value="/fixture/wvkbd"),patch.object(module.os,"execv",side_effect=OSError("fixture")),patch.object(module,"arm_parent_death_signal"),patch.object(module.os,"stat",return_value=type("Mode",(),{"st_mode":0o755})()),patch.object(module.os,"getxattr",side_effect=OSError(module.errno.ENODATA,"fixture no attributes")):
            self.assertFalse(module.launch("wvkbd-mobintl")["ok"])
    def test_invalid_pid_and_provider_never_read_proc(self):
        for pid,name in [("0","wvkbd-mobintl"),("-1","wvkbd-mobintl"),("anything","wvkbd-mobintl"),("1","unsupported")]:
            with patch.object(module,"Path") as path:
                self.assertFalse(module.observe(pid,name)["ok"]);path.assert_not_called()
    def test_signal_readiness_requires_provider_identity_and_both_signals(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);binary=root/"wvkbd-mobintl";binary.touch();proc=root/"42";proc.mkdir();(proc/"exe").symlink_to(binary)
            def paths(value):return root if str(value)=="/proc" else Path(value)
            masks=[(0,0,False),(0x200,0,False),(0xA00,0,True),(0,0xA00,True),(0x200,0x800,True)]
            with patch.object(module,"Path",side_effect=paths),patch.object(module.shutil,"which",return_value=str(binary)):
                for blocked,caught,ready in masks:
                    (proc/"status").write_text("SigBlk:\t%016x\nSigCgt:\t%016x\n"%(blocked,caught))
                    self.assertEqual(module.observe("42","wvkbd-mobintl")["ready"],ready)
                (proc/"exe").unlink();(proc/"exe").symlink_to(root/"not-the-provider")
                self.assertFalse(module.observe("42","wvkbd-mobintl")["ready"])
    def test_missing_process_or_binary_is_not_ready(self):
        with patch.object(module.shutil,"which",return_value=None):self.assertFalse(module.observe("42","wvkbd-mobintl")["ready"])
        with patch.object(module.shutil,"which",return_value="/not-installed/fixture"):
            self.assertFalse(module.observe("999999999","wvkbd-mobintl")["ready"])
    def test_parent_death_signal_is_graceful_and_race_checked(self):
        with patch.object(module.os,"getppid",side_effect=[42,42]),patch.object(module.ctypes,"CDLL") as library:
            library.return_value.prctl.return_value=0
            module.arm_parent_death_signal()
            library.return_value.prctl.assert_called_once_with(1,module.signal.SIGTERM,0,0,0)
        with patch.object(module.os,"getppid",side_effect=[42,43]),patch.object(module.ctypes,"CDLL") as library:
            library.return_value.prctl.return_value=0
            with self.assertRaises(OSError):module.arm_parent_death_signal()
    def test_missing_parent_or_failed_kernel_guard_prevents_start(self):
        with patch.object(module.os,"getppid",return_value=1),patch.object(module.ctypes,"CDLL") as library:
            with self.assertRaises(OSError):module.arm_parent_death_signal()
            library.assert_not_called()
        with patch.object(module.os,"getppid",return_value=42),patch.object(module.ctypes,"CDLL") as library:
            library.return_value.prctl.return_value=-1
            with self.assertRaises(OSError):module.arm_parent_death_signal()
    def test_privileged_provider_never_executes(self):
        with patch.object(module.capabilities,"detect",return_value={"manualCandidate":True}),patch.object(module.shutil,"which",return_value="/fixture/wvkbd"),patch.object(module.os,"stat",return_value=type("Mode",(),{"st_mode":0o4755})()),patch.object(module.os,"execv") as execute:
            self.assertFalse(module.launch("wvkbd-mobintl")["ok"]);execute.assert_not_called()
    def test_file_capabilities_and_unreadable_attributes_prevent_exec(self):
        for value in [b"fixture capabilities",PermissionError(module.errno.EACCES,"fixture")]:
            options={"side_effect":value} if isinstance(value,Exception) else {"return_value":value}
            with patch.object(module.capabilities,"detect",return_value={"manualCandidate":True}),patch.object(module.shutil,"which",return_value="/fixture/wvkbd"),patch.object(module.os,"stat",return_value=type("Mode",(),{"st_mode":0o755})()),patch.object(module.os,"getxattr",**options),patch.object(module.os,"execv") as execute:
                self.assertFalse(module.launch("wvkbd-mobintl")["ok"]);execute.assert_not_called()
    def test_unknown_cli_cannot_launch_or_observe(self):
        for args in [[],["launch","wvkbd-mobintl"],["launch-confirmed","wvkbd-mobintl","--extra"],["stop","42"]]:
            with patch.object(module,"launch") as launch,patch.object(module,"observe") as observe,redirect_stdout(io.StringIO()) as output:
                self.assertEqual(module.main(args),1);self.assertFalse(json.loads(output.getvalue())["ok"]);launch.assert_not_called();observe.assert_not_called()
if __name__ == "__main__":unittest.main()
