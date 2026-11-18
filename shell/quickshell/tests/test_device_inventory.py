import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("inventory", Path(__file__).parents[1] / "scripts/device-inventory.py")
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)

class InventoryTests(unittest.TestCase):
    def test_display_whitelist_and_unknown(self):
        result = inventory.displays([{"name": "fixture", "serial": "private", "width": 2560}])[0]
        self.assertNotIn("serial", result)
        self.assertIsNone(result["scale"])
        self.assertEqual(result["width"], 2560)

    def test_input_groups_and_no_key_state(self):
        rows = inventory.inputs({"keyboards": [{"name": "keyboard", "active_keymap": "English", "address": "private", "capsLock": True}], "touch": [{"name": "touch"}]})
        self.assertEqual([x["kind"] for x in rows], ["Keyboard", "Touch"])
        self.assertEqual(set(rows[0]), {"kind", "name", "layout"})

    def test_failures_clear_data(self):
        for error in [FileNotFoundError(), subprocess.TimeoutExpired("hyprctl", 3), subprocess.CalledProcessError(1, "hyprctl")]:
            with self.subTest(error=type(error).__name__), patch.object(inventory.subprocess, "run", side_effect=error):
                result = inventory.collect(["hyprctl"], inventory.displays)
                self.assertFalse(result["available"])
                self.assertEqual(result["items"], [])
                self.assertTrue(result["error"])

    def test_malformed_and_empty_distinct(self):
        for raw in ['not json', '{}', '[5]']:
            with patch.object(inventory.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, raw)):
                self.assertFalse(inventory.collect([], inventory.displays)["available"])
        with patch.object(inventory.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, '[]')):
            self.assertTrue(inventory.collect([], inventory.displays)["available"])

if __name__ == "__main__":
    unittest.main()
