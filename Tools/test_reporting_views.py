# SPDX-License-Identifier: Apache-2.0

import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOL = ROOT / "Tools/conformance.py"
# This deliberately simple renderer proves byte comparison and reporting, not Markdown behavior.
RENDERER = [sys.executable, "-c", "import sys; sys.stdout.buffer.write(sys.stdin.buffer.read())"]

class ReportingViewsTests(unittest.TestCase):
    def execute(self, *options):
        with tempfile.TemporaryDirectory() as directory:
            report = pathlib.Path(directory) / "report.json"
            command = [sys.executable, str(TOOL), "gfm", *options, "--report", str(report), "--", *RENDERER]
            process = subprocess.run(command, capture_output=True, text=True)
            return process, json.loads(report.read_text())

    def test_published_example_keeps_disabled_case_and_provenance(self):
        proc, report = self.execute("--view", "published", "--example", "279")
        self.assertEqual(proc.returncode, 1)
        self.assertEqual((report["total"], report["failed"], report["skipped"]), (1, 1, 0))
        self.assertEqual(report["scope_status"], "incomplete")
        row = report["results"][0]
        self.assertEqual(row["id"], 279)
        self.assertEqual(row["extensions"], ["tasklist"])
        self.assertIn("disabled", row["historical_mapping_note"])
        self.assertIn("--example 279", row["reproduce"])
        self.assertFalse(report["qualification_eligible"])

    def test_fixed_interaction_has_project_provenance_and_fixed_command(self):
        proc, report = self.execute("--view", "fixed", "--example", "interaction-table-strikethrough-1")
        self.assertEqual(proc.returncode, 1)
        self.assertEqual(report["view"], "fixed")
        self.assertEqual(report["total"], 1)
        self.assertIn("project-authored", report["results"][0]["provenance"])
        self.assertEqual(report["results"][0]["command"], RENDERER)
        self.assertIn("not the complete published corpus", report["limitations"][1])
        self.assertTrue(report["fixed_corpus_sha256"])

    def test_original_map_reports_explicit_skip(self):
        proc, report = self.execute("--gfm-historical-extension-map", "--example", "279")
        self.assertEqual(proc.returncode, 1)
        self.assertEqual(report["skipped"], 1)
        self.assertIn("disabled", report["results"][0]["reason"])

if __name__ == "__main__":
    unittest.main()
