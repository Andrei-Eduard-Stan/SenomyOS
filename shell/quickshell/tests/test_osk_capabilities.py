import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch
spec = importlib.util.spec_from_file_location("osk_capabilities",Path(__file__).parents[1]/"scripts/osk-capabilities.py")
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)

class OskCapabilitiesTests(unittest.TestCase):
    def tools(self, name):
        return "/fixture/"+name if name in ["wayland-info","wvkbd-mobintl"] else None
    def output(self, omit=None):
        return "\n".join("interface: '%s', version: %d, name: 1" % (name,version) for name,version in module.REQUIRED.items() if name != omit)
    def test_no_session_never_probes(self):
        with patch.dict(os.environ,{},clear=True),patch.object(module.shutil,"which",side_effect=self.tools),patch.object(module.subprocess,"run") as run:
            result=module.detect();self.assertEqual(result["protocolState"],"unknown");self.assertFalse(result["manualCandidate"]);run.assert_not_called()
    def test_missing_probe_is_unknown(self):
        with patch.dict(os.environ,{"WAYLAND_DISPLAY":"fixture"}),patch.object(module.shutil,"which",return_value=None):
            result=module.detect();self.assertFalse(result["providerInstalled"]);self.assertEqual(result["protocolState"],"unknown")
    def test_base_protocols_do_not_require_automatic_input_method(self):
        completed=subprocess.CompletedProcess([],0,self.output(),"")
        with patch.dict(os.environ,{"WAYLAND_DISPLAY":"fixture"}),patch.object(module.shutil,"which",side_effect=self.tools),patch.object(module.subprocess,"run",return_value=completed) as run:
            result=module.detect();self.assertTrue(result["manualCandidate"]);self.assertFalse(result["integrated"]);self.assertFalse(result["autoInputMethodAdvertised"])
            run.assert_called_once_with(["/fixture/wayland-info"],capture_output=True,text=True,timeout=5,check=True)
    def test_missing_protocol_is_incompatible(self):
        completed=subprocess.CompletedProcess([],0,self.output("zwp_virtual_keyboard_manager_v1"),"")
        with patch.dict(os.environ,{"WAYLAND_DISPLAY":"fixture"}),patch.object(module.shutil,"which",side_effect=self.tools),patch.object(module.subprocess,"run",return_value=completed):
            result=module.detect();self.assertEqual(result["protocolState"],"incompatible");self.assertFalse(result["manualCandidate"]);self.assertIn("zwp_virtual_keyboard_manager_v1",result["missingProtocols"])
    def test_old_compositor_version_is_incompatible(self):
        completed=subprocess.CompletedProcess([],0,self.output().replace("'wl_compositor', version: 6","'wl_compositor', version: 4"),"")
        with patch.dict(os.environ,{"WAYLAND_DISPLAY":"fixture"}),patch.object(module.shutil,"which",side_effect=self.tools),patch.object(module.subprocess,"run",return_value=completed):
            self.assertIn("wl_compositor",module.detect()["missingProtocols"])
    def test_probe_failures_never_claim_compatibility(self):
        for error in [FileNotFoundError(),subprocess.TimeoutExpired("fixture",5),subprocess.CalledProcessError(1,"fixture")]:
            with patch.dict(os.environ,{"WAYLAND_DISPLAY":"fixture"}),patch.object(module.shutil,"which",side_effect=self.tools),patch.object(module.subprocess,"run",side_effect=error):
                result=module.detect();self.assertEqual(result["protocolState"],"unknown");self.assertFalse(result["manualCandidate"])
    def test_malformed_oversized_and_exact_interfaces(self):
        for output in ["garbage", "a"*(module.LIMIT+1)]:
            with self.assertRaises(ValueError):module.parse_protocols(output)
        self.assertNotIn("wl_compositor",module.parse_protocols("interface: 'other_wl_compositor', version: 6"))
        self.assertEqual(module.parse_protocols("interface: 'wl_seat', version: 1\ninterface: 'wl_seat', version: 8")["wl_seat"],8)
    def test_available_protocols_without_provider_not_candidate(self):
        with patch.dict(os.environ,{"WAYLAND_DISPLAY":"fixture"}),patch.object(module.shutil,"which",side_effect=lambda name:"/fixture/wayland-info" if name=="wayland-info" else None),patch.object(module.subprocess,"run",return_value=subprocess.CompletedProcess([],0,self.output(),"")):
            result=module.detect();self.assertEqual(result["protocolState"],"advertised");self.assertFalse(result["manualCandidate"])
    def test_unknown_cli_does_not_probe(self):
        with patch.object(module.subprocess,"run") as run,redirect_stdout(io.StringIO()) as output:
            self.assertEqual(module.main(["launch"]),1);self.assertFalse(json.loads(output.getvalue())["ok"]);run.assert_not_called()
if __name__ == "__main__":unittest.main()
