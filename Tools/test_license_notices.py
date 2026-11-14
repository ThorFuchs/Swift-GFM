# SPDX-License-Identifier: Apache-2.0

import hashlib
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
IDENTIFIER = "SPDX-License-Identifier: Apache-2.0"


def project_sources():
    files = [ROOT / "Package.swift"]
    for directory in ("Sources", "Tests"):
        files.extend((ROOT / directory).rglob("*.swift"))
    files.extend((ROOT / "Tools").glob("*.py"))
    files.extend((ROOT / "Tools").glob("*.sh"))
    files.extend((ROOT / "Tools").rglob("*.swift"))
    files.extend((ROOT / name) for name in (
        "Vendor/GitHubCMark/api/SwiftGFMCMark.h", "Vendor/GitHubCMark/bridge/SwiftGFMBridge.c"))
    return sorted(path for path in set(files) if not {".build", ".swiftpm"}.intersection(path.parts))


class LicenseNoticeTests(unittest.TestCase):
    def test_apache_license_text(self):
        digest = hashlib.sha256((ROOT / "LICENSE").read_bytes()).hexdigest()
        self.assertEqual(digest, "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4")

    def test_project_sources_have_spdx_identifiers(self):
        for path in project_sources():
            with self.subTest(path=path.relative_to(ROOT)):
                self.assertIn(IDENTIFIER, "\n".join(path.read_text(encoding="utf-8").splitlines()[:4]))

    def test_notices_identify_retained_third_party_licenses(self):
        notice = (ROOT / "NOTICE").read_text(encoding="utf-8")
        for relative in ("Vendor/GitHubCMark/COPYING", "Tests/SwiftGFMTests/Fixtures/cmark-gfm/LICENSE"):
            with self.subTest(path=relative):
                self.assertIn(relative, notice)
                self.assertTrue((ROOT / relative).is_file())


if __name__ == "__main__":
    unittest.main()
