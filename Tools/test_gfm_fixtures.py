import hashlib
import pathlib
import unittest
from gfm_fixtures import extract

class PublishedGFMTests(unittest.TestCase):
    def test_published_examples_and_tab_conversion(self):
        path = pathlib.Path(__file__).resolve().parents[1] / "Fixtures/gfm/spec.html"
        data = path.read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), "b153d814fdfc8624bb6da7449162c1cd707a637f7d1c1b636eb44b9cf63fa220")
        cases = extract(data)
        self.assertEqual(len(cases), 677)
        self.assertEqual(cases[0]["markdown"], "\tfoo\tbaz\t\tbim\n")
        self.assertEqual(cases[0]["html"], "<pre><code>foo\tbaz\t\tbim\n</code></pre>\n")

class HistoricalMappingTests(unittest.TestCase):
    def test_published_examples_are_matched_by_both_fields(self):
        from gfm_source_map import map_examples, map_evidence
        root = pathlib.Path(__file__).resolve().parents[1]
        published = extract((root / "Fixtures/gfm/spec.html").read_bytes())
        source = (root / "Fixtures/gfm/cmark-gfm-0.29.0.gfm.0-spec.txt").read_bytes()
        mapping = map_examples(published, source)
        self.assertEqual(len(mapping), 677)
        self.assertEqual(sum(x is None for x in mapping), 15)
        self.assertEqual(mapping[0], ())
        evidence = map_evidence(published, source)
        self.assertEqual(evidence[278][1], "matching historical source example is explicitly disabled")
        self.assertEqual(evidence[82][1], "no exact input-and-output match in historical source")
        altered = dict(published[0], html="different")
        self.assertEqual(map_examples([altered], source), [None])

if __name__ == "__main__":
    unittest.main()
