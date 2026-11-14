# SPDX-License-Identifier: Apache-2.0

import importlib.util
import unittest

@unittest.skipUnless(importlib.util.find_spec("html5lib"), "install Tools/requirements-analysis.txt")
class HTMLClusterTests(unittest.TestCase):
    def test_entity_spelling_is_same_tree_but_different_bytes(self):
        from cluster_gfm_failures import cluster
        expected, actual = '<p>&quot;hi&quot;</p>\n', '<p>"hi"</p>\n'
        result = cluster(expected, actual)
        self.assertNotEqual(expected.encode(), actual.encode())
        self.assertEqual(result["primary"], "same_html5_fragment_tree")

    def test_block_layout_whitespace_is_not_an_exact_dom_match(self):
        from cluster_gfm_failures import cluster
        expected = '<ul>\n<li>\n<p>x</p>\n</li>\n</ul>\n'
        actual = '<ul>\n<li><p>x</p>\n</li>\n</ul>\n'
        result = cluster(expected, actual)
        self.assertEqual(result["primary"], "structural_layout_whitespace_only")
        self.assertFalse(result["same_html5_fragment_tree"])

    def test_inline_and_code_whitespace_is_preserved(self):
        from cluster_gfm_failures import cluster
        result = cluster('<p><code>a b</code></p>', '<p><code>ab</code></p>')
        self.assertFalse(result["same_after_structural_whitespace_rule"])
        self.assertEqual(result["primary"], "dom_text_changed")

    def test_non_breaking_space_is_not_layout_only(self):
        from cluster_gfm_failures import cluster
        result = cluster('<ul>\n\u00a0<li>x</li></ul>', '<ul>\n<li>x</li></ul>')
        self.assertFalse(result["same_after_structural_whitespace_rule"])

    def test_link_and_image_changes_are_not_cosmetic(self):
        from cluster_gfm_failures import cluster
        link = cluster('<p><a href="/a">x</a></p>', '<p>x</p>')
        image = cluster('<p><img src="a" alt="moon"></p>', '<p><img src="a"></p>')
        self.assertEqual(link["primary"], "link_or_link_attribute_changed")
        self.assertEqual(image["primary"], "image_or_image_attribute_changed")
        self.assertIn("image_alt_or_counts_differ", image["labels"])

if __name__ == "__main__":
    unittest.main()
