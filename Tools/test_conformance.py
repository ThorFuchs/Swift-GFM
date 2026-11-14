# SPDX-License-Identifier: Apache-2.0

import sys
import unittest
from conformance import run

class HarnessTests(unittest.TestCase):
    def test_exact_output_and_failure(self):
        cases = [{"example": 1, "section": "x", "markdown": "a\n", "html": "a\n"},
                 {"example": 2, "section": "x", "markdown": "b\n", "html": "b"}]
        result = run(cases, [sys.executable, "-c", "import sys; sys.stdout.buffer.write(sys.stdin.buffer.read())"], 2)
        self.assertEqual([r["status"] for r in result], ["pass", "fail"])
        self.assertEqual(result[1]["actual"], "b\n")

    def test_missing_process_is_failure(self):
        case = {"example": 1, "section": "x", "markdown": "", "html": ""}
        self.assertEqual(run([case], ["/not/a/renderer"], 2)[0]["status"], "fail")

class SecondaryDiagnosticsTests(unittest.TestCase):
    def test_checkbox_serialization_is_distinct_from_raw_comparison(self):
        from html_diagnostics import compare
        expected = '<li><input checked="" disabled="" type="checkbox"> foo</li>'
        same = '<li><input type="checkbox" disabled="" checked="" /> foo</li>'
        wrong = '<li><input type="checkbox" disabled="" /> foo</li>'
        self.assertEqual(compare(expected, same), "equivalent_tokens")
        self.assertEqual(compare(expected, wrong), "different_tokens")
        self.assertNotEqual(expected, same)

if __name__ == "__main__":
    unittest.main()
