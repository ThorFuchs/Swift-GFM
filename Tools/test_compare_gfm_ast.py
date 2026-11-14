# SPDX-License-Identifier: Apache-2.0

import unittest
import xml.etree.ElementTree as ET
from compare_gfm_ast import preserve_xml_attribute_whitespace, reference_tree, swift_tree, strip_empty_fields, merge_text_children

class ASTProjectionTests(unittest.TestCase):
    def test_link_title_newlines_survive_xml_projection(self):
        raw = '<document><link destination="/a" title="\nline1\nline2\n"><text>x</text></link></document>'
        self.assertEqual(ET.fromstring(raw)[0].attrib['title'], ' line1 line2 ')
        root = ET.fromstring(preserve_xml_attribute_whitespace(raw))
        self.assertEqual(root[0].attrib['title'], '\nline1\nline2\n')
        tree = reference_tree(root, set(), set())
        self.assertEqual(tree['children'][0]['attributes']['title'], '\nline1\nline2\n')

    def test_list_tightness_not_silently_treated_as_preserved(self):
        root = ET.fromstring('<document><list type="bullet" tight="true"><item/></list></document>')
        lost = set()
        tree = reference_tree(root, set(), lost)
        self.assertEqual(tree['children'][0]['attributes']['type'], 'bullet')
        self.assertIn('list tightness is not stored by the Swift Markdown list model', lost)

    def test_preserve_link_and_image_data_and_normalize_empty(self):
        ref = ET.fromstring('<link destination="/uri" title=""><image destination="moon.jpg" title=""><text>moon</text></image></link>')
        swift = {'kind':'link','attributes':{'destination':'/uri'},'children':[{'kind':'image','attributes':{'destination':'moon.jpg'},'children':[{'kind':'text','attributes':{'literal':'moon'},'children':[]}]}]}
        expected = reference_tree(ref, set(), set())
        actual = swift_tree(swift, set())
        strip_empty_fields(actual)
        merge_text_children(actual)
        self.assertEqual(expected, actual)

    def test_unknown_node_is_inconclusive(self):
        unknown = set()
        reference_tree(ET.fromstring('<mystery/>'), unknown, set())
        self.assertEqual(unknown, {'cmark:mystery'})

if __name__ == '__main__':
    unittest.main()
