import unittest
import xml.etree.ElementTree as ET
from compare_cmark_xml import structure, positions

class CMarkXMLTests(unittest.TestCase):
    def test_structure_and_positions_are_reported_independently(self):
        reference = ET.fromstring('<document sourcepos="1:1-1:8"><strong sourcepos="1:1-1:8"><text>foo</text></strong></document>')
        candidate = ET.fromstring('<document sourcepos="1:1-1:8"><strong sourcepos="1:2-1:7"><text>foo</text></strong></document>')
        changed = ET.fromstring('<document sourcepos="1:1-1:8"><emph sourcepos="1:1-1:8"><text>foo</text></emph></document>')
        self.assertEqual(structure(reference), structure(candidate))
        self.assertNotEqual(positions(reference), positions(candidate))
        self.assertNotEqual(structure(reference), structure(changed))

if __name__ == "__main__":
    unittest.main()
