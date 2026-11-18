# SPDX-License-Identifier: Apache-2.0

import hashlib
import json
import unittest

from bundled_cmark_fixtures import DIRECTORY, REVISION, ROOT, SOURCES, extract


class PinnedFixtureTests(unittest.TestCase):
    def test_source_bytes_and_inventory(self):
        for name, (digest, total) in SOURCES.items():
            with self.subTest(suite=name):
                raw = (DIRECTORY / f"{name}.txt").read_bytes()
                self.assertEqual(hashlib.sha256(raw).hexdigest(), digest)
                self.assertEqual(len(extract(raw)), total)

    def test_spec_copy_and_special_cases(self):
        raw = (DIRECTORY / "spec.txt").read_bytes()
        self.assertEqual([x["example"] for x in extract(raw) if "disabled" in x["flags"]], [279, 280])
        extensions = extract((DIRECTORY / "extensions.txt").read_bytes())
        self.assertEqual([x["example"] for x in extensions if x["html"].strip() == "<IGNORE>"], [20])

    def test_extraction_preserves_consecutive_carriage_returns(self):
        fence = "`" * 32
        raw = (f"{fence} example\n"
               "Harbor\r\r\nDock\n.\n<p>Harbor</p>\n<p>Dock</p>\n"
               f"{fence}\n").encode()
        self.assertEqual(extract(raw)[0]["markdown"], "Harbor\r\r\nDock\n")

    def test_extraction_preserves_non_linefeed_unicode_and_tabs(self):
        fence = "`" * 32
        raw = (f"# Section\n{fence} example autolink\n"
               "one\u0085two\u2192x\n.\n<p>one\u0085two\u2192x</p>\n"
               f"{fence}\n").encode()
        case = extract(raw)[0]
        self.assertEqual(case["markdown"], "one\u0085two\tx\n")
        self.assertEqual(case["html"], "<p>one\u0085two\tx</p>\n")
        self.assertEqual(case["flags"], ["autolink"])

    def test_derived_entity_fixture_provenance(self):
        raw = (DIRECTORY / "entities-reference.json").read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), "c78fc9b632768373163b22b1268107d238b136ea3fa48f3122fab610358c0996")
        payload = json.loads(raw)
        source = (ROOT / "Vendor/GitHubCMark/src/entities.inc").read_bytes()
        self.assertEqual(payload["revision"], REVISION)
        self.assertEqual(payload["entities_source_sha256"], hashlib.sha256(source).hexdigest())
        self.assertEqual(len(payload["examples"]), 2125)


if __name__ == "__main__":
    unittest.main()
