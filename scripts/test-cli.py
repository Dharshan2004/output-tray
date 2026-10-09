#!/usr/bin/env python3
"""Run isolated integration checks for the real registration CLI."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
CLI = ROOT / "outputs" / "register-output.py"


class RegistrationTests(unittest.TestCase):
    def setUp(self):
        (ROOT / "work").mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="cli-test-", dir=ROOT / "work")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.folder = self.root / "watched"
        self.folder.mkdir()
        self.file = self.folder / "résumé.md"
        self.file.write_text("# Actual file\n", encoding="utf-8")
        self.manifest = self.folder / ".output-tray.json"

    def run_cli(self, *args):
        env = dict(os.environ)
        env["PYTHONPYCACHEPREFIX"] = str(self.root / "pycache")
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        return subprocess.run(
            [sys.executable, str(CLI), *map(str, args)],
            capture_output=True, text=True, env=env,
        )

    def entries(self):
        return json.loads(self.manifest.read_text(encoding="utf-8"))["artifacts"]

    def test_roundtrip_and_update_preserve_labels_and_timestamp(self):
        result = self.run_cli(self.file, "--title", "Résumé brief", "--project", "Output Tray", "--task", "Demo")
        self.assertEqual(result.returncode, 0, result.stderr)
        entry = self.entries()[0]
        self.assertEqual(entry["path"], "résumé.md")
        self.assertEqual(entry["title"], "Résumé brief")
        self.assertEqual(entry["project"], "Output Tray")
        self.assertEqual(entry["task"], "Demo")
        self.assertTrue(entry["createdAt"].endswith("Z"))
        timestamp = entry["createdAt"]
        result = self.run_cli(self.file, "--task", "Rehearsal")
        self.assertEqual(result.returncode, 0, result.stderr)
        entries = self.entries()
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["createdAt"], timestamp)
        self.assertEqual(entries[0]["title"], "Résumé brief")
        self.assertEqual(entries[0]["project"], "Output Tray")
        self.assertEqual(entries[0]["task"], "Rehearsal")
        self.assertEqual(list(self.folder.glob(".output-tray-*.tmp")), [])

    def test_explicit_folder_and_multiple_files(self):
        self.assertEqual(self.run_cli(self.file, "--folder", self.folder).returncode, 0)
        second = self.folder / "image.svg"
        second.write_text("<svg/>\n")
        self.assertEqual(self.run_cli(second).returncode, 0)
        self.assertEqual({e["path"] for e in self.entries()}, {"résumé.md", "image.svg"})

    def test_reject_missing_hidden_temporary_nested_and_directories(self):
        nested = self.folder / "nested"
        nested.mkdir()
        child = nested / "child.md"
        child.write_text("nested")
        hidden = self.folder / ".secret.md"
        hidden.write_text("hidden")
        temporary = self.folder / "partial.tmp"
        temporary.write_text("partial")
        for args in ((self.folder / "missing.md",), (hidden,), (temporary,), (child, "--folder", self.folder), (nested,)):
            with self.subTest(args=args):
                result = self.run_cli(*args)
                self.assertEqual(result.returncode, 1)
                self.assertIn("Registration failed:", result.stderr)
        self.assertFalse(self.manifest.exists())

    def test_reject_symlink_escaping_watched_folder(self):
        outside = self.root / "outside.md"
        outside.write_text("outside")
        link = self.folder / "escape.md"
        link.symlink_to(outside)
        result = self.run_cli(link)
        self.assertEqual(result.returncode, 1)
        self.assertIn("escape", result.stderr)
        self.assertFalse(self.manifest.exists())
        self.assertEqual(outside.read_text(), "outside")

    def test_malformed_manifest_is_preserved(self):
        for raw in ("{broken", '{"artifacts": "invalid"}', '{"artifacts": [1]}'):
            with self.subTest(raw=raw):
                self.manifest.write_text(raw)
                result = self.run_cli(self.file)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(self.manifest.read_text(), raw)
                self.assertEqual(list(self.folder.glob(".output-tray-*.tmp")), [])

    def test_manifest_symlink_does_not_overwrite_target(self):
        outside = self.root / "outside.json"
        outside.write_text("keep this")
        self.manifest.symlink_to(outside)
        result = self.run_cli(self.file)
        self.assertEqual(result.returncode, 1)
        self.assertIn("symlink", result.stderr)
        self.assertEqual(outside.read_text(), "keep this")


if __name__ == "__main__":
    unittest.main(verbosity=2)
