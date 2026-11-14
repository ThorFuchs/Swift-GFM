import pathlib
import unittest
from compare_bundled_gfm import ROOT, SOURCES, extract

class BundledGFMSuiteTests(unittest.TestCase):
    def test_source_counts_and_disabled_cases_preserved(self):
        for suite, total in (("historical", 673), ("current", 672)):
            filename, _, _ = SOURCES[suite]
            cases = extract((ROOT / "Fixtures/gfm" / filename).read_bytes())
            self.assertEqual(len(cases), total)
            self.assertEqual([c["example"] for c in cases], list(range(1, total + 1)))
            disabled = [case for case in cases if "disabled" in case["flags"]]
            self.assertEqual(len(disabled), 2)
            self.assertTrue(all("[x]" in case["markdown"] for case in disabled))

    def test_input_preserves_non_linefeed_unicode_and_tabs(self):
        fence = "`" * 32
        raw = (f"# Section\n{fence} example autolink\n"
               "one\u0085two→x\n.\n<p>one\u0085two→x</p>\n"
               f"{fence}\n").encode()
        case = extract(raw)[0]
        self.assertEqual(case["markdown"], "one\u0085two\tx\n")
        self.assertEqual(case["html"], "<p>one\u0085two\tx</p>\n")
        self.assertEqual(case["flags"], ["autolink"])

if __name__ == "__main__":
    unittest.main()
