# SPDX-License-Identifier: Apache-2.0

import unittest

from bundled_cmark_fixtures import REVISION, ROOT, VERSION
from check_backend_revision import problems, tracked_files


class BackendRevisionTests(unittest.TestCase):
    def test_repository_is_consistent(self):
        self.assertEqual(problems(ROOT, list(tracked_files(ROOT)), REVISION, VERSION), [])

    def test_detects_a_stale_revision_and_version(self):
        stale = "0" * 40
        found = problems(ROOT, list(tracked_files(ROOT)), stale, "0.29.0.gfm.99")
        self.assertTrue(any("does not mention the pinned revision" in item for item in found))
        self.assertTrue(any("backendRevision" in item for item in found))
        self.assertTrue(any("version 0.29.0.gfm.13 is not 0.29.0.gfm.99" in item for item in found))


if __name__ == "__main__":
    unittest.main()
