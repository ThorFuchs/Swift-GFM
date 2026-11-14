# SPDX-License-Identifier: Apache-2.0

import hashlib
import json
import unittest

from bundled_cmark_fixtures import DIRECTORY, ROOT, SOURCES
from compare_bundled_gfm import extract


class PinnedFixtureTests(unittest.TestCase):
    def test_source_bytes_and_inventory(self):
        for name, (digest, total) in SOURCES.items():
            with self.subTest(suite=name):
                raw = (DIRECTORY / f"{name}.txt").read_bytes()
                self.assertEqual(hashlib.sha256(raw).hexdigest(), digest)
                self.assertEqual(len(extract(raw)), total)

    def test_spec_copy_and_special_cases(self):
        raw = (DIRECTORY / "spec.txt").read_bytes()
        self.assertEqual(raw, (ROOT / "Fixtures/gfm/cmark-gfm-0.29.0.gfm.13-spec.txt").read_bytes())
        self.assertEqual([x["example"] for x in extract(raw) if "disabled" in x["flags"]], [279, 280])
        extensions = extract((DIRECTORY / "extensions.txt").read_bytes())
        self.assertEqual([x["example"] for x in extensions if x["html"].strip() == "<IGNORE>"], [20])
        regression = extract((DIRECTORY / "regression.txt").read_bytes())
        self.assertIn("\r\r\n", regression[0]["markdown"])

    def test_derived_entity_fixture_provenance(self):
        raw = (DIRECTORY / "entities-reference.json").read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), "c78fc9b632768373163b22b1268107d238b136ea3fa48f3122fab610358c0996")
        payload = json.loads(raw)
        source = (ROOT / "Vendor/GitHubCMark/src/entities.inc").read_bytes()
        self.assertEqual(payload["revision"], "27d942c8b0a62d192f616e5bf3578f4b6a89e180")
        self.assertEqual(payload["entities_source_sha256"], hashlib.sha256(source).hexdigest())
        self.assertEqual(len(payload["examples"]), 2125)


if __name__ == "__main__":
    unittest.main()
