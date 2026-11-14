import hashlib
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
VENDORS = [ROOT / 'Experiments/GitHubCMarkProbe/Vendor', ROOT / 'Vendor/GitHubCMark']

class GitHubCMarkVendorTests(unittest.TestCase):
    def test_upstream_source_and_license_match_recorded_manifest(self):
        for vendor in VENDORS:
            self.check_vendor(vendor)

    def check_vendor(self, vendor):
        manifest = json.loads((vendor / 'UPSTREAM_SHA256.json').read_bytes())
        self.assertEqual(manifest['revision'], '27d942c8b0a62d192f616e5bf3578f4b6a89e180')
        source_files = {p.relative_to(vendor).as_posix() for folder in ('src', 'extensions') for p in (vendor / folder).rglob('*') if p.is_file()}
        source_files.add('COPYING')
        self.assertEqual(source_files, set(manifest['files']))
        for name, expected in manifest['files'].items():
            with self.subTest(name=name):
                self.assertEqual(hashlib.sha256((vendor / name).read_bytes()).hexdigest(), expected)

if __name__ == '__main__':
    unittest.main()
