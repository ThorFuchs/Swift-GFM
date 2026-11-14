# SPDX-License-Identifier: Apache-2.0

import unittest
import xml.etree.ElementTree as ET

from check_ast_projection import preserve_xml_attribute_whitespace, xml_tree


class ASTProjectionToolTests(unittest.TestCase):
    def test_link_title_newlines_survive_xml_parsing(self):
        raw = '<document><link destination="/a" title="\nline1\nline2\n"><text>x</text></link></document>'
        self.assertEqual(ET.fromstring(raw)[0].attrib["title"], " line1 line2 ")
        tree = xml_tree(ET.fromstring(preserve_xml_attribute_whitespace(raw)))
        self.assertEqual(tree["children"][0]["attributes"]["title"], "\nline1\nline2\n")
        self.assertEqual(tree["children"][0]["children"][0]["literal"], "x")


if __name__ == "__main__":
    unittest.main()
