#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / "scripts" / "session-policy.py"


class SessionPolicyTests(unittest.TestCase):
    def run_helper(self, root, *arguments):
        environment = dict(os.environ)
        environment["XDG_CONFIG_HOME"] = str(root)
        return subprocess.run(
            [sys.executable, str(HELPER), *arguments],
            env=environment, capture_output=True, text=True, check=False,
        )

    def test_defaults_are_read_only(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = self.run_helper(root)
            payload = json.loads(result.stdout)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(payload["lockSeconds"], 300)
            self.assertEqual(payload["displayOffSeconds"], 600)
            self.assertFalse(payload["suspendEnabled"])
            self.assertFalse(payload["saved"])
            self.assertFalse((root / "senomyos/session-policy.json").exists())

    def test_apply_persists_and_renders_fixed_policy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proposed = {"lockSeconds": 420, "displayOffSeconds": 900}
            result = self.run_helper(root, "apply", json.dumps(proposed))
            payload = json.loads(result.stdout)
            self.assertEqual(result.returncode, 0)
            self.assertTrue(payload["saved"])
            self.assertTrue(payload["activationRequired"])
            self.assertEqual(json.loads((root / "senomyos/session-policy.json").read_text()), proposed)
            rendered = (root / "hypr/hypridle.conf").read_text()
            self.assertIn("timeout = 420", rendered)
            self.assertIn("timeout = 900", rendered)
            self.assertNotIn("suspend", rendered)
            self.assertEqual((root / "senomyos/session-policy.json").stat().st_mode & 0o777, 0o600)
            self.assertEqual((root / "hypr/hypridle.conf").stat().st_mode & 0o777, 0o600)

    def test_invalid_ranges_and_unknown_operations_are_rejected(self):
        invalid = [
            {"lockSeconds": 0, "displayOffSeconds": 600},
            {"lockSeconds": 301, "displayOffSeconds": 600},
            {"lockSeconds": 600, "displayOffSeconds": 600},
            {"lockSeconds": 300, "displayOffSeconds": 7260},
        ]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for value in invalid:
                result = self.run_helper(root, "apply", json.dumps(value))
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(json.loads(result.stdout)["ok"])
            result = self.run_helper(root, "remove-everything")
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((root / "senomyos/session-policy.json").exists())

    def test_corrupt_saved_state_is_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / "senomyos/session-policy.json"
            state.parent.mkdir(parents=True)
            state.write_text("not json")
            result = self.run_helper(root)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(json.loads(result.stdout)["ok"])


if __name__ == "__main__":
    unittest.main()
