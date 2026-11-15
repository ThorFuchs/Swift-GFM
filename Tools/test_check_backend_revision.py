# SPDX-License-Identifier: Apache-2.0

import unittest

from bundled_cmark_fixtures import REVISION, ROOT, VERSION
from check_backend_revision import problems, tracked_files


class BackendRevisionTests(unittest.TestCase):
    def test_repository_is_consistent(self):
        self.assertEqual(problems(ROOT, list(tracked_files(ROOT)), REVISION, VERSION), [])

    def test_detects_a_stale_revision_and_version(self):
        # Build the stale values at run time so this file never contains a literal
        # version or revision that the repository check would report.
        stale_revision = "0" * 40
        stale_version = VERSION.rsplit(".", 1)[0] + ".9999"
        found = problems(ROOT, list(tracked_files(ROOT)), stale_revision, stale_version)
        self.assertTrue(any("does not mention the pinned revision" in item for item in found))
        self.assertTrue(any("backendRevision" in item for item in found))
        self.assertTrue(any(f"version {VERSION} is not {stale_version}" in item for item in found))


if __name__ == "__main__":
    unittest.main()
