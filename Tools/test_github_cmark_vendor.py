# SPDX-License-Identifier: Apache-2.0

import hashlib
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
VENDORS = [ROOT / 'Vendor/GitHubCMark']

class GitHubCMarkVendorTests(unittest.TestCase):
    def test_upstream_source_and_license_match_recorded_manifest(self):
        for vendor in VENDORS:
            self.check_vendor(vendor)

    def check_vendor(self, vendor):
        manifest = json.loads((vendor / 'UPSTREAM_SHA256.json').read_bytes())
        self.assertRegex(manifest['revision'], r'^[0-9a-f]{40}$')
        source_files = {p.relative_to(vendor).as_posix() for folder in ('src', 'extensions') for p in (vendor / folder).rglob('*') if p.is_file()}
        source_files.add('COPYING')
        self.assertEqual(source_files, set(manifest['files']))
        for name, expected in manifest['files'].items():
            with self.subTest(name=name):
                self.assertEqual(hashlib.sha256((vendor / name).read_bytes()).hexdigest(), expected)

if __name__ == '__main__':
    unittest.main()
